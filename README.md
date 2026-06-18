# HDK FPGA Classifier v4.8

Hyperdimensional Kernel Engine — Zero MatMul text classifier for Artix-7.

## Quick start

1. Fork/clone this repo
2. Go to Actions tab → "HDK FPGA Build" → Run workflow
3. Wait ~20 min for synthesis + implementation
4. Download reports and bitstream from workflow artifacts

## Alternative: Local Vivado

```bash
cd vivado_project_ready
vivado -mode batch -source build_hdk.tcl
```

## Repository structure

```
.github/workflows/build.yml   GitHub Actions workflow
vivado_project_ready/          Vivado project (open with Tools → Run Tcl Script)
vhdl/                          Source code (VHDL + Verilog)
datos/                         Validation data (10-fold McNemar)
graficas/                      Performance graphs
reportes_sintesis/             Synthesis reports + backups
```

## Results

- 71.09% accuracy, 10-fold validated against sklearn LogReg
- 0/10 folds statistically significant (McNemar test)
- ~30,000 LUTs on Artix-7 (22% of XC7A200T)
- 0 DSPs used
- ~10,000 inferences/second @100 MHz (estimated)
