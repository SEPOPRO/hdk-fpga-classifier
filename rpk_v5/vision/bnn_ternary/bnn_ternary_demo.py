#!/usr/bin/env python3
"""
RPK v5 — BNN Ternaria (demo offline, sin descarga de datos)
============================================================
Demostración del flujo completo: RPK projection → capas ternarias
→ exportación a VHDL. Usa datos sintéticos para validar el pipeline.

Ejecución: python bnn_ternary_demo.py
"""
import torch
import torch.nn as nn
import numpy as np
import json, os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# =========================================================================
# 1. Núcleo RPK (idéntico al usado en texto)
# =========================================================================
class RPKExtractor(nn.Module):
    def __init__(self, in_dim, rp_dim):
        super().__init__()
        self.register_buffer('W', torch.randint(0, 2, (in_dim, rp_dim)).float())
    
    def forward(self, x):
        return 2 * (x @ self.W > 0).float() - 1  # {-1, +1}

# =========================================================================
# 2. Capa ternaria {-1, 0, +1} sin multiplicadores
# =========================================================================
class TernarizedLinear(nn.Module):
    def __init__(self, in_dim, out_dim, threshold=0.05):
        super().__init__()
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.threshold = threshold
        self.weight = nn.Parameter(torch.randn(out_dim, in_dim) * 0.1)
    
    def forward(self, x):
        with torch.no_grad():
            w_tern = torch.sign(self.weight) * (torch.abs(self.weight) > self.threshold).float()
        return nn.functional.linear(x, w_tern)
    
    def get_ternary(self):
        w = self.weight.detach().cpu().numpy()
        mask = np.abs(w) > self.threshold
        return np.sign(w) * mask  # {-1, 0, +1}

# =========================================================================
# 3. Modelo RPK-BNN completo
# =========================================================================
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

# =========================================================================
# 4. Exportación a VHDL
# =========================================================================
def export_vhdl(model, outfile):
    layers = []
    for name, mod in model.named_modules():
        if isinstance(mod, TernarizedLinear):
            w = mod.get_ternary()
            encoded = np.zeros_like(w, dtype=np.uint8)
            encoded[w == -1] = 0
            encoded[w == 0] = 1   # pruned
            encoded[w == 1] = 2
            layers.append(encoded)
    
    lines = ["-- rpk_bnn_weights.vhd"]
    lines.append("-- Pesos ternarios {-1,0,+1} exportados por bnn_ternary_demo.py")
    lines.append("-- Codificacion: 00=-1, 01=0(pruned), 10=+1")
    lines.append("library IEEE; use IEEE.STD_LOGIC_1164.ALL; use IEEE.NUMERIC_STD.ALL;")
    lines.append("package rpk_bnn_pkg is")
    
    for idx, W in enumerate(layers):
        out_d, in_d = W.shape
        lines.append(f"  constant L{idx}_IN  : integer := {in_d};")
        lines.append(f"  constant L{idx}_OUT : integer := {out_d};")
        lines.append(f"  type L{idx}_T is array (0 to {out_d-1}, 0 to {in_d-1}) of STD_LOGIC_VECTOR(1 downto 0);")
        lines.append(f"  constant L{idx}_W : L{idx}_T := (")
        for o in range(min(out_d, 8)):  # muestra primeras 8 filas
            vals = [f'\"{int(W[o,i]):02b}\"' for i in range(min(in_d, 16))]
            lines.append(f"    ({','.join(vals)})" + (',' if o < min(out_d,8)-1 else ' -- ...truncated'))
        lines.append(f"  ); -- {W.size} pesos totales, {np.sum(W!=0)} no-zero")
    
    lines.append("end rpk_bnn_pkg;")
    
    with open(outfile, 'w') as f:
        f.write('\n'.join(lines))
    return layers

# =========================================================================
# 5. Main
# =========================================================================
def main():
    print("="*60)
    print("RPK v5 — BNN Ternaria Demo (sin descarga de datos)")
    print("="*60)
    
    print("\nCreando modelo RPK-BNN...")
    model = RPK_BNN(rp_dim=2048)
    n_params = sum(p.numel() for p in model.parameters())
    print(f"  Parámetros: {n_params:,}")
    
    # Forward con datos sintéticos
    print("\nTest forward con batch sintético...")
    x = torch.randn(4, 3, 32, 32)  # 4 imágenes 32×32 RGB
    y = model(x)
    print(f"  Entrada: {x.shape} → Salida: {y.shape}")
    
    # Exportar pesos
    print("\nExportando pesos ternarios a VHDL...")
    vhdl_path = os.path.join(OUT_DIR, "rpk_bnn_pkg.vhd")
    layers = export_vhdl(model, vhdl_path)
    
    # Estadísticas de pruning
    total = sum(l.size for l in layers)
    nonzero = sum(np.sum(l != 1) for l in layers)
    print(f"\n📊 Estadísticas:")
    print(f"  Capas ternarias: {len(layers)}")
    print(f"  Pesos totales: {total:,}")
    print(f"  Pesos no-zero: {nonzero:,} ({100*nonzero/total:.1f}%)")
    print(f"  Compresión por pruning: {total/max(nonzero,1):.1f}×")
    
    # Arquitectura
    print(f"\n📐 Arquitectura exportada:")
    for idx, W in enumerate(layers):
        print(f"  Capa {idx}: {W.shape[1]} → {W.shape[0]} (ternario {np.sum(W!=1)}/{W.size})")
    
    print(f"\n✅ VHDL: {vhdl_path}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
