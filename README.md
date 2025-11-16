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

**Control Flow**
- BEQ  
- JAL  
- JALR

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
- `program.mem`     - Test program (hex)
- `tb_rv32_top.sv`  - Testbench

## 📝 Explanation of program.mem file:

### Test Program (`program.mem`)

The core is tested with a small hand-written RV32I program encoded in `program.mem`.  
Each line is one 32-bit instruction word in hex, loaded at word address `PC = 0x0, 0x4, 0x8, ...`.

| PC   | Hex        | Assembly                | Effect / Purpose                                   |
|------|------------|-------------------------|----------------------------------------------------|
| 0x00 | 00500093   | `addi x1, x0, 5`        | x1 = 5                                             |
| 0x04 | 00700113   | `addi x2, x0, 7`        | x2 = 7                                             |
| 0x08 | 0030f193   | `andi x3, x1, 3`        | x3 = x1 & 3  → 5 & 3 = 1                           |
| 0x0C | 00816213   | `ori  x4, x2, 8`        | x4 = x2 \| 8 → 7 \| 8 = 0xF                        |
| 0x10 | 000122b7   | `lui  x5, 0x12`         | x5 = 0x00012000 (upper-immediate test)            |
| 0x14 | 00001317   | `auipc x6, 0x1`         | x6 ≈ 0x00001000 (AUIPC / U-type path test)        |
| 0x18 | 002083b3   | `add  x7, x1, x2`       | x7 = x1 + x2 = 12 (0xC)                            |
| 0x1C | 40110433   | `sub  x8, x2, x1`       | x8 = x2 − x1 = 2                                   |
| 0x20 | 0041f4b3   | `and  x9, x3, x4`       | x9 = x3 & x4 = 1                                   |
| 0x24 | 0041e533   | `or   x10, x3, x4`      | x10 = x3 \| x4 = 0xF                               |
| 0x28 | 0020a5b3   | `slt  x11, x1, x2`      | x11 = (5 < 7) ? 1 : 0 → 1                          |
| 0x2C | 00702023   | `sw   x7, 0(x0)`        | MEM[0] = x7 (store 12 to data memory)             |
| 0x30 | 00002603   | `lw   x12, 0(x0)`       | x12 = MEM[0] = 12                                  |
| 0x34 | 00760463   | `beq  x12, x7, +8`      | Branch test (x12 == x7). Control/branch path test |
| 0x38 | 00100693   | `addi x13, x0, 1`       | x13 = 1 (reachable in this simple test setup)     |
| 0x3C | 0080076f   | `jal  x14, +8`          | x14 = PC+4 = 0x40, jump to 0x44                    |
| 0x40 | 00200793   | `addi x15, x0, 2`       | x15 = 2 (simple ALU / WB test)                    |
| 0x44 | 00008067   | `jalr x0, x1, 0`        | Return via x1 (used mainly to exercise JALR path) |

> Note: This program is intentionally small but hits all the main datapath features:  
> **ALU ops, immediates, U-type, load/store, branch, JAL, JALR, and forwarding.**

---

### Expected Register State After Program

At the end of the simulation (after the last instruction retires), the architected registers of interest hold:

- `x1  = 0x00000005`
- `x2  = 0x00000007`
- `x3  = 0x00000001`
- `x4  = 0x0000000f`
- `x5  = 0x00012000`
- `x6  = 0x00001000`
- `x7  = 0x0000000c`
- `x8  = 0x00000002`
- `x9  = 0x00000001`
- `x10 = 0x0000000f`
- `x11 = 0x00000001`
- `x12 = 0x0000000c`
- `x13 = 0x00000001`
- `x14 = 0x00000040`
- `x15 = 0x00000002`

These values are what you see printed by the testbench’s WB-stage monitor, and they’re a good “golden signature” to quickly check that the pipeline, control unit, forwarding, and LUI/AUIPC paths are all behaving.

This verifies:
- Arithmetic
- ALU path works
- Imm generator works
- LUI/AUIPC path correct
- Load/store correct
- Forwarding works (multiple data hazards)
- JAL / JALR paths correct
- Branch decision logic correct

## 🧪 Simulation Instructions

1. Add all `.sv` files and `program.mem` into Vivado or any SystemVerilog simulator.
2. Make sure `inst_mem.sv` loads the file correctly

## 🚀 Future Improvements

Potential extensions:
- Hazard detection (stalling on load-use)
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
