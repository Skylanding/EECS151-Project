// Module: ALU.v
// Desc:   32-bit ALU for the RISC-V Processor
// Inputs: 
//    A: 32-bit value
//    B: 32-bit value
//    ALUop: Selects the ALU's operation 
// 						
// Outputs:
//    Out: The chosen function mapped to A and B.

`include "Opcode.vh"
`include "ALUop.vh"

module ALU(
    input [31:0] A,B,
    input [3:0] ALUop,
    output reg [31:0] Out
);

reg [31:0] out_internal;
always @(*) begin
    case (ALUop)
        `ALU_ADD: out_internal = A + B;     
        `ALU_SUB: out_internal = A - B;    
        `ALU_AND: out_internal = A & B;    
        `ALU_OR: out_internal = A | B;     
        `ALU_XOR: out_internal = A ^ B;    
        `ALU_SLT: out_internal = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;    
        `ALU_SLTU: out_internal = (A < B) ? 32'b1 : 32'b0;
        `ALU_SLL: out_internal = A << B[4:0];    
        `ALU_SRA: out_internal = $signed(A) >>> B[4:0];    
        `ALU_SRL: out_internal = A >> B[4:0];   
        `ALU_COPY_B: out_internal = B;
        `ALU_COPY_A: out_internal = A;
        `ALU_XXX: out_internal = 32'b0;
        default: out_internal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;     
    endcase
end
assign Out = out_internal;
endmodule
