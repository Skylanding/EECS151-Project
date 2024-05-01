`include "Opcode.vh"

module Decoder (
    input [31:0] instr,
    output [6:0] opcode,
    output [2:0] funct3,
    output [4:0] rd, rs1, rs2,
    output [6:0] funct7,
    output [31:0] imm
);

    wire [31:12] immui;
    wire [20:1] immjal;
    wire [12:1] immbr;
    wire [11:0] immi;
    wire [11:0] imms;

    assign {immui, rd, opcode} = instr;
    assign {immjal[20], immjal[10:1], immjal[11], immjal[19:12], rd, opcode} = instr;
    assign {immi, rs1, funct3, rd, opcode} = instr;
    assign {immbr[12], immbr[10:5], rs2, rs1, funct3, immbr[4:1], immbr[11], opcode} = instr;
    assign {imms[11:5], rs2, rs1, funct3, imms[4:0], opcode} = instr;
    assign {funct7, rs2, rs1, funct3, rd, opcode} = instr;

    assign imm = ((opcode == `OPC_LUI) | opcode == `OPC_AUIPC) ? {immui, 12'b0}
        : (opcode == `OPC_JAL) ? {{11{immjal[20]}}, immjal, 1'b0}
        : (opcode == `OPC_BRANCH) ? {{19{immbr[12]}}, immbr, 1'b0}
        : (opcode == `OPC_STORE) ? {{20{imms[11]}}, imms}
        : (
            (opcode == `OPC_JALR) 
            | (opcode == `OPC_LOAD) 
            | (opcode == `OPC_ARI_ITYPE)
        ) ? {{20{immi[11]}}, immi}
        : (opcode == `OPC_CSR) ? {{27{1'b0}}, rs1}
        : 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;

    /*
    always @* begin
        case (opcode)
            `OPC_LUI, `OPC_AUIPC: imm <= {immui, 12'b0};
            `OPC_JAL: imm <= {{11{immjal[20]}}, immjal, 1'b0};
            `OPC_BRANCH: imm <= {{19{immbr[12]}}, immbr, 1'b0};
            `OPC_STORE: imm <= {{20{imms[11]}}, imms};
            `OPC_JALR, `OPC_LOAD, `OPC_ARI_ITYPE: imm <= {{20{immi[11]}}, immi};
        endcase
    end
    */

endmodule
