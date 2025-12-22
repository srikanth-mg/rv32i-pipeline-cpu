# RV32I 5-Stage Pipelined Processor (SystemVerilog)

This repository contains a fully working RV32I RISC-V processor implemented in SystemVerilog, following the classic 5-stage pipelined architecture.
It supports ALU operations, immediates, loads/stores, branches, jumps, register forwarding, and a standalone test program loaded with $readmemh.

This is a clean and minimal educational core which is perfect for learning, debugging, and extending.
---

## 🔧 Pipeline Architecture

The processor implements the standard **5 pipeline stages**:

1. **IF – Instruction Fetch**  
   - Program Counter (PC)  
   - Instruction Memory (ROM)  
   - PC + 4 logic  
   - IF/ID pipeline register  

2. **ID – Instruction Decode**  
   - Register file read (rs1, rs2)  
   - Immediate generation (I, S, B, J, U formats)  
   - Control Unit (opcode + funct3/funct7 decoding)  
   - ID/EX pipeline register  

3. **EX – Execute**  
   - ALU operations (ADD, SUB, AND, OR, SLT, etc.)  
   - Branch evaluation  
   - Jump and branch target computation  
   - EX/MEM pipeline register  

4. **MEM – Memory Access**  
   - Data Memory (LW, SW)  
   - Pass-through for ALU results  
   - MEM/WB pipeline register  

5. **WB – Write-Back**  
   - Select between ALU result, memory data, or PC+4  
   - Write-back to register file (except x0)

## ✔️ Supported Instructions (RV32I Base ISA)

**Arithmetic / Logic**
- ADD, SUB, AND, OR, SLT  
- ADDI, ANDI, ORI  

**Memory**
- LW  
- SW  

**U-Type**
- LUI
- AUIPC

All instructions follow the RISC-V uncompressed 32-bit format.

## 📁 File Structure

- `rv32_top.sv`     - Main CPU integrating all pipeline stages
- `rv32_pkg.sv`     - Type definitions, structs, ALU op enums
- `instr_mem.sv`    - Instruction ROM using $readmemh
- `data_mem.sv`     - Data memory
- `regfile.sv`      - 32x32(256kB) register file with x0 hardwired to zero
- `control_unit.sv` - Decodes opcode / funct3 / funct7
- `alu.sv`          - ALU implementation
- `hazard_unit.sv`  - Hazard detection unit
- `program.mem`     - Test program (hex)
- `tb_rv32_top.sv`  - Testbench

## 🧪 Simulation Instructions

1. Add all `.sv` files and `program.mem` into Vivado or any SystemVerilog simulator.
2. Make sure `inst_mem.sv` loads the file correctly

## 🚀 Future Improvements

Potential extensions:
- Branch predictor
- Pipeline flush logic for jumps
- Full RV32I instruction support
- Multicycle or pipelined multiplier/divider
- Instruction & data caches
- V32IM, RV32IC compressed extensions

## 👨‍💻 Author
Srikanth Muthuvel Ganthimathi

## 📜 License

This project is for educational and research purposes.
You may modify or extend the design freely.
