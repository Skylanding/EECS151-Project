module DecodeRead (
    input [31:0] instr,

    output [3:0] alu_op,
    output is_jump, is_branch,
    output [2:0] funct3,
    output a_sel_reg, b_sel_reg,
    /// Register WE, Memory WE (for stores), Memory Read Request (for loads)
    output reg_we, mem_we, mem_rr,
    /// The immediate shift around amount and rs2 are combined in the same bus.
    output [4:0] rd,
    output [4:0] rs1, rs2,
    output [31:0] imm,
    output bubble, csr_write
);

    wire [6:0] opcode, funct7;
    wire add_rshift_type;

    Decoder decoder(
        instr,
        opcode,
        funct3,
        rd, rs1, rs2,
        funct7,
        imm
    );

    wire s2_bubble, s3_bubble;

    ALUdec alu_dec(opcode, funct3, add_rshift_type, alu_op);

    assign add_rshift_type = funct7[5];

    assign is_jump = (opcode == `OPC_JAL) | (opcode == `OPC_JALR) | (opcode == `OPC_BRANCH);
    assign is_branch = opcode == `OPC_BRANCH;
    assign a_sel_reg = (opcode == `OPC_JAL || opcode == `OPC_AUIPC || opcode ==`OPC_BRANCH) ? 1'b0 
        : (opcode == `OPC_STORE || opcode == `OPC_LOAD || opcode == `OPC_ARI_RTYPE 
            || opcode == `OPC_ARI_ITYPE || opcode == `OPC_CSR || opcode == `OPC_JALR) ? 1'b1
        : 1'bx;
    assign b_sel_reg = (opcode == `OPC_ARI_RTYPE) ? 1'b1 
        : (opcode == `OPC_LUI || opcode == `OPC_AUIPC || opcode == `OPC_JAL || opcode == `OPC_CSR
            || opcode == `OPC_BRANCH || opcode == `OPC_LOAD || opcode == `OPC_JALR
            || opcode == `OPC_STORE || opcode == `OPC_ARI_ITYPE) ? 1'b0
        : 1'bx;
    assign reg_we = (opcode == `OPC_LUI) | (opcode == `OPC_AUIPC) | (opcode == `OPC_JAL) | (opcode == `OPC_JALR) | (opcode == `OPC_LOAD) | (opcode == `OPC_ARI_ITYPE)
        | (opcode == `OPC_ARI_RTYPE);
    assign mem_we = opcode == `OPC_STORE;
    assign mem_rr = opcode == `OPC_LOAD;
    assign csr_write = opcode == `OPC_CSR;
    
endmodule