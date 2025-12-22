`timescale 1ns / 1ps

module hazard_unit (
    input  logic        ex_memRead,   // EX stage instruction is a load
    input  logic [4:0]  ex_rd,          // destination register in EX
    input  logic [4:0]  id_rs1,          // source register 1 in ID
    input  logic [4:0]  id_rs2,          // source register 2 in ID

    output logic        stall            // stall signal
);

    always_comb begin
        if (ex_memRead &&
            (ex_rd != 5'd0) &&
            ((ex_rd == id_rs1) || (ex_rd == id_rs2)))
            stall = 1'b1;
        else
            stall = 1'b0;
    end

endmodule

