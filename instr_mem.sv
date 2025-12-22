`timescale 1ns/1ps

module instr_mem (
    input  logic [31:2] addr,    // word-aligned address
    output logic [31:0] instr
);
    // 256 x 32-bit instruction memory
    logic [31:0] mem [0:255];

    // Default mem file (matches your uploaded file: program1.mem)
    string MEM_FILE = "program2.mem";

    initial begin
        $readmemh(MEM_FILE, mem);
        // Optional debug (safe to keep)
        $display("IMEM loaded from %s", MEM_FILE);
        $display("IMEM[0] = %h", mem[0]);
    end
    
    always_comb begin
        // 256 words -> need only [9:2]
        instr = mem[addr[9:2]];
    end

endmodule
