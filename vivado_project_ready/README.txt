HDK Vivado Project — Hyperdimensional Kernel Classifier v4.8
============================================================

Target: Xilinx Artix-7 XC7A200T (Nexys Video board)
Clock: 100 MHz
Interface: UART 10 Mbaud (8N1)

How to use:
-----------
1. Open Vivado 2024.2+ (WebPack is free)
2. File -> Project -> Open -> Select this folder
   OR: Tools -> Run Tcl Script -> build_hdk.tcl

3. To build:
   - Click "Generate Bitstream" (or run build_hdk.tcl)
   - Wait ~10-30 min for synthesis + implementation

4. Reports generated:
   - hdk_impl_utilization.rpt (LUTs/FFs/BRAMs/DSPs)
   - hdk_impl_timing.rpt (clock frequency, slack)
   - hdk_power.rpt (power estimation)

5. To program FPGA:
   - Open Hardware Manager
   - Connect Nexys Video via USB-JTAG
   - Program with the .bit file

Files:
------
  hdl/hd_classifier.vhd      Top-level module (442 lines)
  hdl/popcount_tree.vhd      20,000-bit POPCOUNT (130 lines)
  hdl/argmin.vhd             Sequential minimum finder (91 lines)
  hdl/uart_rx.vhd            UART receiver 10 Mbaud (137 lines)
  hdl/uart_tx.vhd            UART transmitter 10 Mbaud (92 lines)
  sim/tb_hd_classifier.vhd   Testbench (144 lines)
  constrs/hdk_constraints.xdc Timing constraints (100 MHz)
  build_hdk.tcl              Build script

Expected results (Artix-7 XC7A200T):
------------------------------------
  LUTs:   ~30,000  (22% of 134,600)
  FFs:    ~750     (0.3% of 269,200)
  BRAMs:  16       (4.4% of 365)
  DSPs:   0        (0% of 740)
  Fmax:   >100 MHz
  Power:  ~150 mW

Reference:
----------
Full project: C:\Users\raem9\Desktop\HDK_Prototype\HDK_v4.8_Final
Manual: HDK_Manual_Tecnico_Profesional.md (65 KB)
Results: 71.09% accuracy, 10-fold validated, 0 MatMul in inference
