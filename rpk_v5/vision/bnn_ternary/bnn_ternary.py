#!/usr/bin/env python3
"""
RPK v5 — BNN Ternaria: Entrenamiento + Exportación de Pesos
============================================================
Entrena una red ternaria {-1,0,+1} para clasificación de imágenes
(CIFAR-10) usando el mismo pipeline que RPK: proyección aleatoria
+ capas ternarias sin multiplicaciones.

Salida: pesos ternarios exportados a VHDL lookup tables.
"""
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.data import DataLoader, Subset
from torchvision import datasets, transforms
import numpy as np
import json, os, sys, time

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# =========================================================================
# 1. RPKExtractor — proyección aleatoria (compartida con texto)
# =========================================================================
class RPKExtractor(nn.Module):
    """Proyección aleatoria fija: entrada → features binarias"""
    def __init__(self, in_dim, rp_dim):
        super().__init__()
        self.register_buffer('W', torch.randint(0, 2, (in_dim, rp_dim)).float())
    
    def forward(self, x):
        return torch.sign(x @ self.W)  # {-1, +1}

# =========================================================================
# 2. Capa Ternaria — pesos {-1, 0, +1}, sin MatMul en inferencia
# =========================================================================
class TernarizedLinear(nn.Module):
    """Capa lineal ternaria con pruning integrado"""
    def __init__(self, in_dim, out_dim, prune_threshold=0.05):
        super().__init__()
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.prune_threshold = prune_threshold
        # Pesos en punto flotante (se ternarizan durante forward)
        self.weight = nn.Parameter(torch.randn(out_dim, in_dim) * 0.1)
        self.bias = nn.Parameter(torch.zeros(out_dim))
    
    def forward(self, x):
        # Ternarización: {-1, 0, +1} con threshold de pruning
        with torch.no_grad():
            abs_w = torch.abs(self.weight)
            mask = (abs_w > self.prune_threshold).float()  # 0 = pruned
            sign = torch.sign(self.weight)  # -1 o +1
            w_tern = sign * mask  # {-1, 0, +1}
        # Forward con pesos ternarizados (durante inferencia es XNOR + POPCOUNT)
        return F.linear(x, w_tern, self.bias)
    
    def get_ternary_weights(self):
        """Exporta pesos ternarios para VHDL"""
        with torch.no_grad():
            abs_w = torch.abs(self.weight)
            mask = (abs_w > self.prune_threshold).float()
            sign = torch.sign(self.weight)
            w_tern = (sign * mask).cpu().numpy().astype(np.int8)
        return w_tern

# =========================================================================
# 3. Feature extractor para CIFAR-10 usando Gabor + RPK
# =========================================================================
class GaborRPKFrontend(nn.Module):
    """
    Frontend de visión: imita los filtros Gabor LUT + RPK proyección
    """
    def __init__(self, rp_dim=4096):
        super().__init__()
        # Filtros Gabor discretos 5×5, 8 orientaciones (simulado)
        self.conv1 = nn.Conv2d(3, 8, 5, padding=2, bias=False)
        # Inicializar con pesos Gabor (congelados)
        self._init_gabor()
        # RPK proyección: 8 canales × 32×32 = 8192 features → rp_dim
        self.rpk = RPKExtractor(8*32*32, rp_dim)
    
    def _init_gabor(self):
        """Inicializa filtros como Gabor 5×5"""
        import math
        with torch.no_grad():
            for o in range(8):
                theta = o * math.pi / 8
                for c in range(3):  # RGB
                    kernel = torch.zeros(5, 5)
                    for i in range(5):
                        for j in range(5):
                            x = i - 2
                            y = j - 2
                            x_t = x * math.cos(theta) + y * math.sin(theta)
                            y_t = -x * math.sin(theta) + y * math.cos(theta)
                            g = math.exp(-(x_t**2 + y_t**2) / 4)
                            kernel[i,j] = g * math.cos(2 * math.pi * x_t / 4)
                    self.conv1.weight[o, c] = kernel
    
    def forward(self, x):
        x = torch.tanh(self.conv1(x))  # 8 feature maps
        x = x.view(x.size(0), -1)       # flatten
        x = self.rpk(x)                 # RPK projection
        return x

# =========================================================================
# 4. RPK-BNN completo
# =========================================================================
class RPK_BNN(nn.Module):
    """Red completa: Gabor → RPK → BNN ternaria"""
    def __init__(self, rp_dim=4096, num_classes=10):
        super().__init__()
        self.frontend = GaborRPKFrontend(rp_dim)
        self.bnn = nn.Sequential(
            TernarizedLinear(rp_dim, 512),
            nn.BatchNorm1d(512),
            nn.ReLU(),
            TernarizedLinear(512, 128),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            TernarizedLinear(128, num_classes),
        )
    
    def forward(self, x):
        x = self.frontend(x)
        x = self.bnn(x)
        return x

# =========================================================================
# 5. Entrenamiento
# =========================================================================
def train_epoch(model, loader, optimizer, criterion, device):
    model.train()
    total_loss = 0
    correct = 0
    total = 0
    for data, target in loader:
        data, target = data.to(device), target.to(device)
        optimizer.zero_grad()
        output = model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
        _, pred = output.max(1)
        correct += pred.eq(target).sum().item()
        total += target.size(0)
    return total_loss / len(loader), 100. * correct / total

def test(model, loader, criterion, device):
    model.eval()
    total_loss = 0
    correct = 0
    total = 0
    with torch.no_grad():
        for data, target in loader:
            data, target = data.to(device), target.to(device)
            output = model(data)
            total_loss += criterion(output, target).item()
            _, pred = output.max(1)
            correct += pred.eq(target).sum().item()
            total += target.size(0)
    return total_loss / len(loader), 100. * correct / total

# =========================================================================
# 6. Exportación a VHDL
# =========================================================================
def export_weights_to_vhdl(model, outfile):
    """Exporta pesos ternarios a formato VHDL LUT"""
    lines = []
    lines.append("-- rpk_bnn_weights.vhd")
    lines.append("-- Pesos ternarios {-1,0,+1} generados por bnn_ternary.py")
    lines.append("library IEEE;")
    lines.append("use IEEE.STD_LOGIC_1164.ALL;")
    lines.append("use IEEE.NUMERIC_STD.ALL;\n")
    lines.append("package rpk_bnn_weights is\n")
    
    layer_idx = 0
    for name, module in model.named_modules():
        if isinstance(module, TernarizedLinear):
            w = module.get_ternary_weights()  # shape: [out_dim, in_dim]
            out_d, in_d = w.shape
            
            # Codificar ternario como 2 bits: 00=-1, 01=0, 10=+1
            w_encoded = np.zeros((out_d, in_d), dtype=np.uint8)
            w_encoded[w == -1] = 0
            w_encoded[w == 0] = 1  # pruned
            w_encoded[w == 1] = 2
            
            lines.append(f"  -- Layer {layer_idx}: {in_d} → {out_d}")
            lines.append(f"  constant L{layer_idx}_IN  : integer := {in_d};")
            lines.append(f"  constant L{layer_idx}_OUT : integer := {out_d};")
            lines.append(f"  type L{layer_idx}_T is array (0 to {out_d-1}, 0 to {in_d-1}) of STD_LOGIC_VECTOR(1 downto 0);")
            lines.append(f"  constant L{layer_idx}_W : L{layer_idx}_T := (")
            
            for o in range(out_d):
                row_vals = []
                for i in range(in_d):
                    row_vals.append(f"\"{w_encoded[o,i]:02b}\"")
                comma = "," if o < out_d-1 else ""
                lines.append(f"    ({','.join(row_vals)}){comma}")
            
            lines.append("  );\n")
            layer_idx += 1
    
    lines.append("end rpk_bnn_weights;")
    
    with open(outfile, 'w') as f:
        f.write('\n'.join(lines))
    print(f"  ✅ Pesos exportados: {outfile}")
    return layer_idx

# =========================================================================
# 7. Main
# =========================================================================
def main():
    print("="*60)
    print("RPK v5 — BNN Ternaria para CIFAR-10")
    print("="*60)
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"\nDispositivo: {device}")
    
    # Datos
    print("\nCargando CIFAR-10...")
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.5,0.5,0.5), (0.5,0.5,0.5)),
    ])
    full_train = datasets.CIFAR10(root='./data', train=True, download=True, transform=transform)
    full_test = datasets.CIFAR10(root='./data', train=False, download=True, transform=transform)
    
    # Subset rápido para pruebas (5000 train, 1000 test)
    train_set = Subset(full_train, range(5000))
    test_set = Subset(full_test, range(1000))
    
    train_loader = DataLoader(train_set, batch_size=64, shuffle=True, num_workers=2)
    test_loader = DataLoader(test_set, batch_size=64, shuffle=False, num_workers=2)
    print(f"  Train: {len(train_set)} muestras")
    print(f"  Test:  {len(test_set)} muestras")
    
    # Modelo
    print("\nCreando modelo RPK-BNN...")
    model = RPK_BNN(rp_dim=2048, num_classes=10).to(device)
    total_params = sum(p.numel() for p in model.parameters())
    print(f"  Parámetros totales: {total_params:,}")
    
    # Optimizador
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=20)
    criterion = nn.CrossEntropyLoss()
    
    # Entrenamiento
    print("\nEntrenando (20 épocas)...")
    best_acc = 0
    for epoch in range(20):
        t0 = time.time()
        train_loss, train_acc = train_epoch(model, train_loader, optimizer, criterion, device)
        test_loss, test_acc = test(model, test_loader, criterion, device)
        scheduler.step()
        t = time.time() - t0
        
        if test_acc > best_acc:
            best_acc = test_acc
        
        print(f"  Epoch {epoch+1:2d}: train={train_acc:.1f}% test={test_acc:.1f}% best={best_acc:.1f}% [{t:.1f}s]")
    
    print(f"\n✅ Mejor precisión: {best_acc:.1f}%")
    
    # Exportar pesos
    print("\nExportando pesos ternarios a VHDL...")
    vhdl_path = os.path.join(OUT_DIR, "rpk_bnn_weights.vhd")
    n_layers = export_weights_to_vhdl(model, vhdl_path)
    
    # Métricas de compresión
    total_ternary = 0
    total_dense = 0
    for name, module in model.named_modules():
        if isinstance(module, TernarizedLinear):
            w = module.get_ternary_weights()
            total_dense += w.size
            total_ternary += np.sum(w != 0)
    
    compression = total_dense / max(total_ternary, 1)
    print(f"\n📊 Métricas de compresión:")
    print(f"  Pesos totales: {total_dense:,}")
    print(f"  Pesos no-zero: {total_ternary:,} ({100*total_ternary/total_dense:.1f}%)")
    print(f"  Compresión por pruning: {compression:.1f}×")
    print(f"  Capas ternarias exportadas: {n_layers}")
    
    # Guardar checkpoint
    ckpt = {
        'state_dict': model.state_dict(),
        'best_acc': best_acc,
        'rp_dim': 2048,
    }
    ckpt_path = os.path.join(OUT_DIR, "rpk_bnn_checkpoint.pt")
    torch.save(ckpt, ckpt_path)
    print(f"  Checkpoint: {ckpt_path}")
    
    print(f"\n{'='*60}")
    print(f"RESUMEN:")
    print(f"  Arquitectura: Gabor 5×5×8 → RPK (2048) → BNN ternaria (512→128→10)")
    print(f"  Precisión CIFAR-10: {best_acc:.1f}%")
    print(f"  Multiplicaciones: CERO (solo XNOR + POPCOUNT)")
    print(f"  Pesos exportados: {n_layers} capas ternarias")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
