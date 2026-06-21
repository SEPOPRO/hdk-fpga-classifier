#!/usr/bin/env python3
"""
bnn_export_fixed.py — Exporta pesos BNN ternarios a VHDL ROM
Usa STD_LOGIC_VECTOR plano en vez de array 2D para evitar el bug de Vivado
"""
import torch, torch.nn as nn
import numpy as np, json, os, sys

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

class RPKExtractor(nn.Module):
    def __init__(self, in_dim, rp_dim):
        super().__init__()
        self.register_buffer('W', torch.randint(0, 2, (in_dim, rp_dim)).float())

    def forward(self, x):
        return 2 * (x @ self.W > 0).float() - 1

class TernarizedLinear(nn.Module):
    def __init__(self, in_dim, out_dim, threshold=0.05):
        super().__init__()
        self.weight = nn.Parameter(torch.randn(out_dim, in_dim) * 0.1)
        self.threshold = threshold

    def forward(self, x):
        with torch.no_grad():
            w_tern = torch.sign(self.weight) * (torch.abs(self.weight) > self.threshold).float()
        return nn.functional.linear(x, w_tern)

    def get_ternary(self):
        w = self.weight.detach().cpu().numpy()
        mask = np.abs(w) > self.threshold
        return np.sign(w) * mask

class RPK_BNN(nn.Module):
    def __init__(self, rp_dim=2048):
        super().__init__()
        self.rpk = RPKExtractor(3*32*32, rp_dim)
        self.bnn = nn.Sequential(
            TernarizedLinear(rp_dim, 512),
            nn.BatchNorm1d(512),
            TernarizedLinear(512, 128),
            nn.BatchNorm1d(128),
            TernarizedLinear(128, 10),
        )

    def forward(self, x):
        x = x.view(x.size(0), -1)
        x = self.rpk(x)
        return self.bnn(x)

def export_weights_flat(model, outfile):
    """Exporta pesos como vectors planos concatenados (evita array 2D)"""
    layers = []
    for name, mod in model.named_modules():
        if isinstance(mod, TernarizedLinear):
            w = mod.get_ternary()  # shape: [out_dim, in_dim]
            encoded = np.zeros_like(w, dtype=np.uint8)
            encoded[w == -1] = 0
            encoded[w == 0] = 1   # pruned
            encoded[w == 1] = 2
            layers.append(encoded)

    lines = ["-- bnn_weights_flat.vhd"]
    lines.append(f"-- Generado: {len(layers)} capas ternarias")
    lines.append("library IEEE; use IEEE.STD_LOGIC_1164.ALL; use IEEE.NUMERIC_STD.ALL;")
    lines.append("package bnn_weights_pkg is")
    
    for idx, W in enumerate(layers):
        out_d, in_d = W.shape
        total_bits = out_d * in_d * 2  # 2 bits por peso
        total_bytes_w = (total_bits + 7) // 8
        
        lines.append(f"  -- Layer {idx}: {out_d}×{in_d} = {out_d*in_d} pesos")
        lines.append(f"  constant L{idx}_W_BITS  : integer := {total_bits};")
        lines.append(f"  constant L{idx}_W_BYTES : integer := {total_bytes_w};")
        
        # Aplanar: convertir toda la matriz 2D a un solo vector de STD_LOGIC_VECTOR
        # Codificar cada 4 pesos (8 bits) como un hex byte
        flat = W.flatten()
        hex_bytes = []
        for i in range(0, len(flat), 4):
            nibble = 0
            for j in range(4):
                if i + j < len(flat):
                    nibble |= int(flat[i + j]) << (j * 2)
            hex_bytes.append(nibble)
        
        lines.append(f"  type L{idx}_ROM_T is array (0 to {len(hex_bytes)-1}) of STD_LOGIC_VECTOR(7 downto 0);")
        lines.append(f"  constant L{idx}_ROM : L{idx}_ROM_T := (")
        
        # Escribir en filas de 16 bytes
        hex_str = ''.join(f'{b:02x}' for b in hex_bytes)
        row_len = 32  # chars per row
        rows = [hex_str[i:i+row_len] for i in range(0, len(hex_str), row_len)]
        for i, row in enumerate(rows):
            comma = ',' if i < len(rows) - 1 else ''
            # Convert hex string back to bytes
            byte_vals = [int(row[j:j+2], 16) for j in range(0, len(row), 2)]
            line = '      ' + ','.join(f'x"{b:02x}"' for b in byte_vals) + comma
            lines.append(line)
        
        lines.append(f"  );")
        
        # Información de decodificación
        nz = np.sum(W != 1)  # non-zero (ternary code 1 = pruned)
        lines.append(f"  -- {nz}/{out_d*in_d} no-zero ({100*nz/(out_d*in_d):.1f}% density)")
        lines.append("")
    
    lines.append("end bnn_weights_pkg;")
    
    with open(outfile, 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"  ✅ Exportado: {outfile}")
    for idx, W in enumerate(layers):
        print(f"  Capa {idx}: {W.shape[0]}×{W.shape[1]} = {W.size} pesos en {W.size//4} bytes")
    
    return layers

def main():
    print("="*60)
    print("BNN Weight Export — Fixed VHDL Generator")
    print("="*60)
    
    model = RPK_BNN(rp_dim=2048)
    n_params = sum(p.numel() for p in model.parameters())
    print(f"\nModelo: {n_params:,} parámetros")
    
    vhdl_path = os.path.join(OUT_DIR, "bnn_weights_flat.vhd")
    layers = export_weights_flat(model, vhdl_path)
    
    total_bytes = sum(l.size // 4 for l in layers)
    print(f"\n📊 Total: {total_bytes:,} bytes en ROM ({total_bytes//1024} KB)")
    print(f"  LUTs estimados: ~{total_bytes//64:,} para almacenamiento")
    print(f"  + ~{15_000:,} LUTs para lógica BNN")
    print(f"  = ~{total_bytes//64 + 15000:,} LUTs totales")
    
    print(f"\n{'='*60}")

if __name__ == "__main__":
    main()
