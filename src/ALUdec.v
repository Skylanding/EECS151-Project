// Module: ALUdecoder
// Desc:   Sets the ALU operation
// Inputs: opcode: the top 6 bits of the instruction
//         funct: the funct, in the case of r-type instructions
//         add_rshift_type: selects whether an ADD vs SUB, or an SRA vs SRL
// Outputs: ALUop: Selects the ALU's operation
//

`include "Opcode.vh"
`include "ALUop.vh"

module ALUdec(
  input [6:0]       opcode,
  input [2:0]       funct,
  input             add_rshift_type,
  output reg [3:0]  ALUop
);

  // Implement your ALU decoder here, then delete this comment
always @(*) begin
  case(opcode)
    `OPC_LUI: ALUop = `ALU_COPY_B;
    `OPC_AUIPC: ALUop = `ALU_ADD;
    `OPC_BRANCH: ALUop = `ALU_ADD;
    `OPC_LOAD: ALUop = `ALU_ADD;
    `OPC_STORE: ALUop = `ALU_ADD;
    `OPC_JALR: ALUop = `ALU_ADD;
    `OPC_JAL: ALUop = `ALU_ADD;
    // `OPC_CSR: begin
    // end
    `OPC_ARI_RTYPE, `OPC_ARI_ITYPE: begin
      case(funct)
        `FNC_ADD_SUB: begin
          if (add_rshift_type == `FNC2_ADD || opcode == `OPC_ARI_ITYPE) begin
            ALUop = `ALU_ADD;
          end else if (add_rshift_type == `FNC2_SUB) begin
            ALUop = `ALU_SUB;
          end
        end
        `FNC_SLL: ALUop = `ALU_SLL;
        `FNC_SLT: ALUop = `ALU_SLT;
        `FNC_SLTU: ALUop = `ALU_SLTU;
        `FNC_SRL_SRA: begin
          if (add_rshift_type == `FNC2_SRA) begin
            ALUop = `ALU_SRA;
          end else if (add_rshift_type == `FNC2_SRL) begin
            ALUop = `ALU_SRL;
          end
        end
        `FNC_XOR: ALUop = `ALU_XOR;
        `FNC_OR: ALUop = `ALU_OR;
        `FNC_AND: ALUop = `ALU_AND;
      endcase
    end
    `OPC_CSR: case (funct)
      `FNC_RW: ALUop = `ALU_COPY_A;
      `FNC_RWI: ALUop = `ALU_COPY_B;
      default: ALUop = `ALU_XXX;
    endcase
    default: ALUop = `ALU_XXX;
  endcase
end
endmodule
