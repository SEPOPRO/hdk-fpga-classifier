# HDK v4.8 - Reporte de Sintesis FPGA

**Fecha:** 2026-06-17 21:49
**Herramienta:** Yosys 0.47+149 + ABC technology mapping
**Target:** Xilinx Artix-7 (LUT6)
**WIDTH sintetizado:** 1,000 bits (escalado a 20,000)

## Resultados de Sintesis (WIDTH=1,000)

| Componente | Cantidad |
|------------|:--------:|
| XOR cells | 4,975 |
| XNOR cells | 19,773 |
| MUX cells | 23,749 |
| ANDNOT cells | 9,903 |
| NOR cells | 2,977 |
| ORNOT cells | 5,962 |
| OR cells | 2,974 |
| NOT cells | 26 |
| AND cells | 8 |
| NAND cells | 9 |
| Flip-flops | 16 |
| **Total cells** | **70,372** |

## Estimacion para WIDTH=20,000

| Componente | Estimado |
|------------|:--------:|
| LUT6 para POPCOUNT tree | ~20,000 LUTs |
| Flip-flops pipeline | ~16 FFs |

## Archivos VHDL

| Archivo | Lineas | Descripcion |
|---------|:------:|-------------|
| hd_classifier.vhd | 442 | Top-level, protocolo UART, FSM |
| popcount_tree.vhd | 130 | POPCOUNT pipeline 15 niveles |
| argmin.vhd | 91 | Buscador secuencial de minimo |
| uart_rx.vhd | 137 | Receptor UART 10 Mbaud |
| uart_tx.vhd | 92 | Transmisor UART 10 Mbaud |
| tb_hd_classifier.vhd | 144 | Testbench |
| **Total** | **1,036** | |

## Validacion (10-fold CV)

| Metrica | Valor |
|---------|-------|
| HDK L-BFGS (C=10, 40 seeds) | 71.09% +/- 0.54% |
| sklearn LogReg | 71.05% +/- 0.61% |
| Gap promedio | -0.03% |
| Folds significativos (McNemar) | 0/10 |
| Conclusion | Equivalentes |

---
*Generado desde datos de validacion y sintesis Yosys*