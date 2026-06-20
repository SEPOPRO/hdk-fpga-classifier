#!/usr/bin/env python3
"""
RPK v5 — MFCC LUT Generator for Audio Classification
======================================================
Genera coeficientes MFCC discretizados para implementación en LUT.
Pipeline: audio 16kHz → ventana 25ms → MFCC 13 coeffs → RPK → BNN

Uso: python mfcc_lut_gen.py
"""
import numpy as np
import json, os, math

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# Parámetros
SAMPLE_RATE = 16000
FFT_SIZE = 512
N_MELS = 26
N_MFCC = 13
N_FILTERS = 26
LOWER_FREQ = 80
UPPER_FREQ = 7600

def hz_to_mel(hz):
    return 2595 * np.log10(1 + hz / 700)

def mel_to_hz(mel):
    return 700 * (10**(mel / 2595) - 1)

def melfb(n_filt, fft_size, sr, low_freq, high_freq):
    """Genera filtros Mel (banco de 26 filtros)"""
    low_mel = hz_to_mel(low_freq)
    high_mel = hz_to_mel(high_freq)
    mel_points = np.linspace(low_mel, high_mel, n_filt + 2)
    hz_points = mel_to_hz(mel_points)
    bin = np.floor((fft_size + 1) * hz_points / sr).astype(int)
    
    fbank = np.zeros((n_filt, fft_size // 2 + 1))
    for i in range(1, n_filt + 1):
        left = bin[i - 1]
        center = bin[i]
        right = bin[i + 1]
        for j in range(left, center):
            fbank[i - 1, j] = (j - left) / (center - left) if center > left else 0
        for j in range(center, right):
            fbank[i - 1, j] = (right - j) / (right - center) if right > center else 0
    
    return fbank  # [26, 257]

def quantize_to_int8(fbank):
    """Cuantiza filtros a INT8 para implementación LUT"""
    max_val = np.max(np.abs(fbank))
    scale = 127 / max_val if max_val > 0 else 1
    return np.clip(np.round(fbank * scale), -128, 127).astype(np.int8), scale

def generate_vhdl(fbank_int8, outfile):
    """Genera VHDL LUT del banco de filtros Mel"""
    n_filt = fbank_int8.shape[0]
    fft_half = fbank_int8.shape[1]
    
    with open(outfile, 'w') as f:
        f.write("-- mfcc_lut.vhd\n")
        f.write("-- Banco de filtros Mel cuantizado INT8\n")
        f.write(f"-- {n_filt} filtros, {fft_half} bins FFT\n")
        f.write("library IEEE; use IEEE.STD_LOGIC_1164.ALL; use IEEE.NUMERIC_STD.ALL;\n\n")
        f.write("package mfcc_lut_pkg is\n")
        f.write(f"  constant N_MELS  : integer := {n_filt};\n")
        f.write(f"  constant FFT_HALF: integer := {fft_half};\n")
        f.write(f"  type mel_bank_t is array (0 to {n_filt-1}, 0 to {fft_half-1}) of STD_LOGIC_VECTOR(7 downto 0);\n")
        f.write(f"  constant mel_bank : mel_bank_t := (\n")
        
        for i in range(n_filt):
            row_vals = []
            for j in range(0, fft_half, 8):  # muestrear cada 8 para no explotar
                val = int(fbank_int8[i, j])
                row_vals.append(f"\"{val & 0xFF:08b}\"")
            comma = "," if i < n_filt - 1 else ""
            # Solo primeras 32 columnas (truncado por espacio)
            f.write(f"    ({','.join(row_vals[:32])}){comma}\n")
        
        f.write("  );\n")
        f.write("end mfcc_lut_pkg;\n")
    
    print(f"  ✅ VHDL: {outfile}")

def generate_dct_matrix(n_mfcc, n_mels):
    """Matriz DCT tipo II para MFCC"""
    dct = np.zeros((n_mfcc, n_mels))
    for i in range(n_mfcc):
        for j in range(n_mels):
            dct[i, j] = np.sqrt(2 / n_mels) * np.cos(np.pi * i * (j + 0.5) / n_mels)
    # Cuantizar a INT8
    max_val = np.max(np.abs(dct))
    scale = 63 / max_val if max_val > 0 else 1
    dct_int8 = np.clip(np.round(dct * scale), -63, 63).astype(np.int8)
    return dct_int8, scale

def generate_dct_vhdl(dct_int8, outfile):
    """Genera VHDL para matriz DCT"""
    n_mfcc, n_mels = dct_int8.shape
    with open(outfile, 'w') as f:
        f.write("-- mfcc_dct.vhd\n")
        f.write("-- Matriz DCT-II para MFCC, cuantizada INT6\n\n")
        f.write("library IEEE; use IEEE.STD_LOGIC_1164.ALL; use IEEE.NUMERIC_STD.ALL;\n\n")
        f.write("package mfcc_dct_pkg is\n")
        f.write(f"  constant N_MFCC : integer := {n_mfcc};\n")
        f.write(f"  constant N_MELS : integer := {n_mels};\n")
        f.write(f"  type dct_mat_t is array (0 to {n_mfcc-1}, 0 to {n_mels-1}) of STD_LOGIC_VECTOR(6 downto 0);\n")
        f.write(f"  constant dct_mat : dct_mat_t := (\n")
        
        for i in range(n_mfcc):
            row_vals = []
            for j in range(n_mels):
                val = int(dct_int8[i, j])
                row_vals.append(f"\"{val & 0x7F:07b}\"")
            comma = "," if i < n_mfcc - 1 else ""
            f.write(f"    ({','.join(row_vals)}){comma}\n")
        
        f.write("  );\n")
        f.write("end mfcc_dct_pkg;\n")
    
    print(f"  ✅ VHDL DCT: {outfile}")

def main():
    print("="*60)
    print("RPK v5 — MFCC LUT Generator")
    print("="*60)
    
    print(f"\nParámetros:")
    print(f"  Sample rate: {SAMPLE_RATE} Hz")
    print(f"  FFT size: {FFT_SIZE}")
    print(f"  Mel filters: {N_MELS}")
    print(f"  MFCC coefficients: {N_MFCC}")
    print(f"  Freq range: {LOWER_FREQ}-{UPPER_FREQ} Hz")
    
    # Generar banco de filtros Mel
    print("\nGenerando banco de filtros Mel...")
    fbank = melfb(N_FILTERS, FFT_SIZE, SAMPLE_RATE, LOWER_FREQ, UPPER_FREQ)
    print(f"  Shape: {fbank.shape}")
    print(f"  Sparsity: {np.sum(fbank == 0) / fbank.size * 100:.1f}%")
    
    # Cuantizar a INT8
    fbank_int8, scale = quantize_to_int8(fbank)
    print(f"  Escala de cuantización: {scale:.2f}")
    
    # Generar VHDL del banco Mel
    vhdl_path = os.path.join(OUT_DIR, "mfcc_lut_pkg.vhd")
    generate_vhdl(fbank_int8, vhdl_path)
    
    # Generar matriz DCT
    print("\nGenerando matriz DCT-II...")
    dct_int8, dct_scale = generate_dct_matrix(N_MFCC, N_MELS)
    print(f"  Shape: {dct_int8.shape}")
    print(f"  Escala DCT: {dct_scale:.2f}")
    
    dct_vhdl_path = os.path.join(OUT_DIR, "mfcc_dct_pkg.vhd")
    generate_dct_vhdl(dct_int8, dct_vhdl_path)
    
    # Estadísticas
    total_lut_bits = (N_FILTERS * (FFT_SIZE // 2 + 1)) * 8  # INT8
    total_lut_bits += (N_MFCC * N_MELS) * 7  # INT6 para DCT
    print(f"\n📊 Estadísticas LUT:")
    print(f"  Banco Mel: {N_FILTERS}×{FFT_SIZE//2 + 1} × 8 bits = {(N_FILTERS*(FFT_SIZE//2+1)*8):,} bits")
    print(f"  Matriz DCT: {N_MFCC}×{N_MELS} × 7 bits = {(N_MFCC*N_MELS*7):,} bits")
    print(f"  Total LUT: ~{total_lut_bits:,} bits (~{total_lut_bits//64} LUT6)")
    
    print(f"\n✅ Archivos generados:")
    print(f"  {vhdl_path}")
    print(f"  {dct_vhdl_path}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
