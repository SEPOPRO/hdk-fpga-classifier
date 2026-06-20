# RPK v5 — Plan de Síntesis Vivado (para VM 64GB)

## Script de síntesis (run_rpk_v5.tcl)
```tcl
# RPK v5 Full Synthesis
create_project rpk_v5 ./vivado_rpk -part xc7a200tfbg676-2 -force
set_property target_language VHDL [current_project]
set_property default_lib work [current_project]

# RPK Text Core (existente)
add_files -norecurse {
    ../../vhdl/hd_classifier.vhd
    ../../vhdl/popcount_tree.vhd
    ../../vhdl/argmin.vhd
    ../../vhdl/uart_rx.vhd
    ../../vhdl/uart_tx.vhd
}

# BNN Ternary Vision
add_files -norecurse {
    ../../rpk_v5/fusion/rpk_v5_top.vhd
    ../../rpk_v5/fusion/bnn_vision.vhd
    ../../rpk_v5/fusion/fusion_multimodal.vhd
    ../../rpk_v5/vision/gabor_lut/gabor_lut.vhd
    ../../rpk_v5/vision/bnn_ternary/rpk_bnn_pkg.vhd
}

# Audio MFCC
add_files -norecurse {
    ../../rpk_v5/audio/mfcc_lut/mfcc_lut_pkg.vhd
    ../../rpk_v5/audio/mfcc_lut/mfcc_dct_pkg.vhd
}

set_property top rpk_v5_top [current_fileset]

# Direct synthesis (no launch_runs — evita bug)
synth_design -top rpk_v5_top -part xc7a200tfbg676-2 -directive AreaOptimized_high

# Reports
puts "=== UTILIZATION ==="
report_utilization -file rpk_v5_utilization.rpt
puts "=== TIMING ==="
report_timing -max_paths 5 -file rpk_v5_timing.rpt
puts "=== POWER ==="
report_power -file rpk_v5_power.rpt
puts "=== DONE ==="
exit
```

## Especificaciones estimadas

| Parámetro | RPK v4 (texto) | RPK v5 (multimodal) | Edge TPU |
|-----------|:--------------:|:-------------------:|:--------:|
| LUTs | 35,028 | **~55,000** | — |
| DSPs | **0** | **0** | Muchos |
| BRAMs | **0** | **0** | Muchos |
| Frecuencia | 70 MHz | **~45 MHz** | — |
| Texto | **71.09%** | **71.09%** | ~50% |
| Visión | ❌ | **~67% CIFAR-10** | ~80% |
| Audio | ❌ | **~75%** | ~70% |
| Fusión | ❌ | ✅ Ponderada | ❌ |
| Throughput | ~7,000/s | **~4,500/s** | 500/s |
| Consumo | ~1.5W | **~2W** | 2W |
| Costo HW | $150 | **$150** ✅ | $150 |

## Cómo ejecutar en VM

```bash
git clone https://github.com/SEPOPRO/hdk-fpga-classifier.git C:\hdk
cd C:\hdk\rpk_v5\fusion
C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source run_rpk_v5.tcl
```
