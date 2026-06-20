#!/usr/bin/env python3
"""
RPK v5 — Generador de Filtros Gabor Discretos para LUT
========================================================
Genera kernels Gabor 5×5 en 8 orientaciones, cuantizados a 1 bit.
Salida: tabla de lookup para VHDL (LUTs) + verificación en Python.

Uso: python gabor_lut_gen.py
"""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import json, os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# Parámetros
KERNEL_SIZE = 5
N_ORIENTATIONS = 8
SIGMA = 2.0
LAMBDA = 4.0
GAMMA = 0.5

def gabor_kernel(size, theta, sigma, lam, gamma):
    """Genera kernel Gabor 2D"""
    half = size // 2
    x, y = np.meshgrid(np.arange(-half, half+1), np.arange(-half, half+1))
    x_theta = x * np.cos(theta) + y * np.sin(theta)
    y_theta = -x * np.sin(theta) + y * np.cos(theta)
    envelope = np.exp(-0.5 * (x_theta**2 / sigma**2 + y_theta**2 / (gamma*sigma)**2))
    sinusoidal = np.cos(2 * np.pi * x_theta / lam)
    return envelope * sinusoidal

def quantize_to_bit(kernel):
    """Cuantiza kernel a 1 bit: 1 si > 0, 0 si <= 0"""
    return (kernel > 0).astype(np.uint8)

def generate_lut_table(kernels_bin):
    size = kernels_bin[0].shape[-1]
    n_orient = len(kernels_bin)
    lut = np.zeros((size * size, n_orient), dtype=np.uint8)
    for i in range(size):
        for j in range(size):
            for o in range(n_orient):
                lut[i * size + j, o] = int(kernels_bin[o][i, j])
    return lut

def generate_vhdl_lut(lut, outfile):
    """Genera archivo VHDL con la LUT de filtros Gabor"""
    size = int(np.sqrt(lut.shape[0]))
    n_orient = lut.shape[1]
    
    with open(outfile, 'w') as f:
        f.write("-- gabor_lut.vhd\n")
        f.write("-- Filtros Gabor 5×5, 8 orientaciones, cuantizados a 1 bit\n")
        f.write(f"-- Generado por gabor_lut_gen.py\n")
        f.write(f"-- Kernel: {KERNEL_SIZE}×{KERNEL_SIZE}, {N_ORIENTATIONS} orientaciones\n")
        f.write("-- Sigma={SIGMA}, Lambda={LAMBDA}, Gamma={GAMMA}\n\n")
        f.write("library IEEE;\n")
        f.write("use IEEE.STD_LOGIC_1164.ALL;\n")
        f.write("use IEEE.NUMERIC_STD.ALL;\n\n")
        f.write("entity gabor_lut is\n")
        f.write("    Port (\n")
        f.write("        clk        : in  STD_LOGIC;\n")
        f.write("        pixel_row  : in  STD_LOGIC_VECTOR(4 downto 0);  -- 0-24\n")
        f.write("        pixel_col  : in  STD_LOGIC_VECTOR(4 downto 0);  -- 0-24\n")
        f.write("        orient     : in  STD_LOGIC_VECTOR(2 downto 0);  -- 0-7\n")
        f.write("        gabor_out  : out STD_LOGIC  -- 1 bit\n")
        f.write("    );\n")
        f.write("end gabor_lut;\n\n")
        f.write("architecture Behavioral of gabor_lut is\n")
        f.write("    type lut_array is array (0 to 24, 0 to 7) of STD_LOGIC;\n")
        f.write("    signal lut : lut_array := (\n")
        
        for i in range(25):
            f.write("        ")
            for o in range(n_orient):
                val = lut[i, o]
                f.write(f"\"{val}\"" if o == 0 else f",\"{val}\"")
            if i < 24:
                f.write(f",  -- pixel {i}\n")
            else:
                f.write(f"   -- pixel {i}\n")
        
        f.write("    );\n")
        f.write("begin\n")
        f.write("    process(clk)\n")
        f.write("        variable row_idx : integer range 0 to 24;\n")
        f.write("        variable col_idx : integer range 0 to 24;\n")
        f.write("        variable addr    : integer range 0 to 24;\n")
        f.write("    begin\n")
        f.write("        if rising_edge(clk) then\n")
        f.write("            row_idx := to_integer(unsigned(pixel_row));\n")
        f.write("            col_idx := to_integer(unsigned(pixel_col));\n")
        f.write("            addr := row_idx * 5 + col_idx;\n")
        f.write("            gabor_out <= lut(addr, to_integer(unsigned(orient)));\n")
        f.write("        end if;\n")
        f.write("    end process;\n")
        f.write("end Behavioral;\n")
    
    print(f"  ✅ VHDL generado: {outfile}")

def main():
    print("="*60)
    print("RPK v5 — Generador de Filtros Gabor para LUT")
    print("="*60)
    
    # Generar kernels
    print(f"\nGenerando {N_ORIENTATIONS} kernels Gabor {KERNEL_SIZE}×{KERNEL_SIZE}...")
    kernels = []
    kernels_bin = []
    angles = np.linspace(0, np.pi * (1 - 1/N_ORIENTATIONS), N_ORIENTATIONS)
    
    for i, theta in enumerate(angles):
        k = gabor_kernel(KERNEL_SIZE, theta, SIGMA, LAMBDA, GAMMA)
        kernels.append(k)
        kb = quantize_to_bit(k)
        kernels_bin.append(kb)
    
    # Mostrar información
    print(f"  Orientaciones: {[f'{np.degrees(a):.0f}°' for a in angles]}")
    print(f"  Bits por kernel: {KERNEL_SIZE*KERNEL_SIZE}")
    print(f"  Total LUT: {N_ORIENTATIONS * KERNEL_SIZE * KERNEL_SIZE} bits")
    
    # Generar LUT
    lut = generate_lut_table(kernels_bin)
    print(f"  Tabla LUT: {lut.shape[0]} posiciones × {lut.shape[1]} orientaciones")
    
    # Generar VHDL
    vhdl_path = os.path.join(OUT_DIR, "gabor_lut.vhd")
    generate_vhdl_lut(lut, vhdl_path)
    
    # Verificación: test con imagen sintética
    print("\nVerificando con imagen sintética...")
    test_img = np.zeros((32, 32))
    test_img[8:24, 8:24] = 1.0  # Cuadrado blanco
    
    responses = np.zeros((32-4, 32-4, N_ORIENTATIONS))
    for i in range(32-4):
        for j in range(32-4):
            patch = test_img[i:i+5, j:j+5]
            for o in range(N_ORIENTATIONS):
                # Producto punto con kernel binarizado
                responses[i,j,o] = np.sum(patch * kernels_bin[o])
    
    max_response = responses.max()
    dominant_orient = responses.argmax(axis=2)
    print(f"  Respuesta máxima: {max_response:.1f}")
    print(f"  Orientación dominante (esquina): {np.degrees(angles[dominant_orient[0,0]]):.0f}°")
    print(f"  Orientación dominante (centro): {np.degrees(angles[dominant_orient[14,14]]):.0f}°")
    
    # Visualización
    fig, axes = plt.subplots(2, 5, figsize=(15, 6))
    for i in range(8):
        ax = axes[i//5, i%5]
        ax.imshow(kernels_bin[i], cmap='gray', vmin=0, vmax=1)
        ax.set_title(f'{np.degrees(angles[i]):.0f}°')
        ax.axis('off')
    
    axes[1,4].imshow(dominant_orient, cmap='viridis')
    axes[1,4].set_title('Ori. dominante')
    axes[1,4].axis('off')
    
    plt.tight_layout()
    vis_path = os.path.join(OUT_DIR, "gabor_kernels.png")
    plt.savefig(vis_path, dpi=150)
    print(f"  ✅ Visualización: {vis_path}")
    
    # Guardar metadatos
    meta = {
        "kernel_size": KERNEL_SIZE,
        "n_orientations": N_ORIENTATIONS,
        "sigma": SIGMA,
        "lambda": LAMBDA,
        "gamma": GAMMA,
        "angles_deg": [round(np.degrees(a), 1) for a in angles],
        "lut_bits": int(N_ORIENTATIONS * KERNEL_SIZE * KERNEL_SIZE),
        "test_max_response": float(max_response),
    }
    meta_path = os.path.join(OUT_DIR, "gabor_metadata.json")
    with open(meta_path, 'w') as f:
        json.dump(meta, f, indent=2)
    print(f"  ✅ Metadatos: {meta_path}")
    
    print(f"\n{'='*60}")
    print(f"RESUMEN:")
    print(f"  {N_ORIENTATIONS} filtros Gabor 5×5 = {lut.shape[0]} LUT entries")
    print(f"  Salida: 1 bit por pixel-posición/orientación")
    print(f"  Recurso estimado: ~3,000 LUTs en Artix-7")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
