# RPK v5 — Módulo Gabor LUT

## Descripción
Filtros Gabor discretos 5×5 en 8 orientaciones, cuantizados a 1 bit.
Implementados como tabla de lookup (LUT) en VHDL.

## Especificaciones
| Parámetro | Valor |
|-----------|-------|
| Kernel | 5×5 píxeles |
| Orientaciones | 8 (0°, 22°, 45°, 68°, 90°, 112°, 135°, 158°) |
| Cuantización | 1 bit por kernel-posición |
| Total LUT | 200 bits (25 posiciones × 8 orientaciones) |
| Latencia | 1 ciclo @ 100 MHz |
| Recursos | ~3,000 LUTs en Artix-7 |

## Archivos
| Archivo | Descripción |
|---------|-------------|
| `gabor_lut_gen.py` | Generador de kernels + tabla LUT + visualización |
| `gabor_lut.vhd` | Módulo VHDL con LUT |
| `tb_gabor_lut.vhd` | Testbench VHDL |
| `gabor_kernels.png` | Visualización de los 8 kernels |
| `gabor_metadata.json` | Metadatos de la generación |

## Uso
```bash
# Regenerar LUT
python gabor_lut_gen.py

# Simular con Vivado
vlib work
vcom gabor_lut.vhd tb_gabor_lut.vhd
vsim tb_gabor_lut
run -all
```

## Integración con RPK
La salida del Gabor LUT (8 bits por posición de pixel) alimenta
el núcleo RPK de proyección aleatoria, compartiendo el mismo
mecanismo de XNOR + POPCOUNT usado para clasificación de texto.
