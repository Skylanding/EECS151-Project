`include "const.vh"

module Riscv151(
    input clk,
    input reset,

    // Memory system ports
    output [31:0] dcache_addr,
    output [31:0] icache_addr,
    output [3:0] dcache_we,
    output dcache_re,
    output icache_re,
    output [31:0] dcache_din,
    input [31:0] dcache_dout,
    input [31:0] icache_dout,
    input icache_req_ready, icache_resp_valid,
    input dcache_req_ready, dcache_resp_valid,
    output [31:0] csr

);

  /// Adds a delay after reset to let everything propagate first
  /// This is the value of reset from the previous cycle.
  reg prev_reset;

  wire [2:0] funct3_1, funct3_2, funct3_3, funct3_4;

  /// Fed into IMEM.
  wire [31:0] next_pc;
  /// The value of PC in the fetch stage.
  wire [31:0] pc_0;
  /// The value of PC in the decode-read stage.
  wire [31:0] pc_1;
  /// The value of PC in the execute stage.
  wire [31:0] pc_2;
  /// The value of PC in the memjump stage.
  wire [31:0] pc_3;
  /// The value of PC in the writeback stage.
  wire [31:0] pc_4;

  /// The instruction that stage 1 can see.  Outputted by the stall handler.
  wire [31:0] instruction_0, instruction_1;
  /// We need to deal with potential stalls immediately after loads, so we need to save the dcache_dout in that case.
  wire [31:0] mem_out;

  /// Signals indicating if this instruction should cause a jump.
  /// jump_3 is also the flush signal.
  wire do_jump_2, do_jump_3, do_jump_4;

  /// So that the ALU is not a critical path for jumps.
  wire [31:0] jump_target;
  
  /// The register file write enables for each stage of the pipeline.
  wire reg_we_1, reg_we_2, reg_we_3, reg_we_4;
  /// The memory write enables for each stage of the pipeline.
  wire mem_we_1, mem_we_2, mem_we_3;
  /// The memory read request for each stage of the pipeline.
  wire mem_rr_1, mem_rr_2, mem_rr_3, mem_rr_4;
  
  /// The rd index for each stage of the pipeline.
  wire [4:0] rd_1, rd_2, rd_3, rd_4;
  /// The rs1 index for each stage of the pipeline.
  wire [4:0] rs1_1, rs1_2;
  /// The rs2 index for each stage of the pipeline.
  wire [4:0] rs2_1, rs2_2, rs2_3;

  /// The A and B values from the registers for each stage of the pipeline.
  wire [31:0] reg_A_2, reg_B_2;

  /// The generated immediates across the first two stages of the pipeline.
  wire [31:0] imm_1, imm_2;

  /// The value that is written to the register file
  /// Internal writeback is the writeback, but disconnected from memory to reduce the critical
  /// path.  Instructions that depend directly on an immediately preceding load have to wait two
  /// cycles.
  wire [31:0] writeback, internal_wb;

  wire [3:0] alu_op_1, alu_op_2;
  wire a_sel_reg_1, a_sel_reg_2;
  wire b_sel_reg_1, b_sel_reg_2;
  wire is_jump_1, is_jump_2;
  wire is_branch_1, is_branch_2;

  /// Indicates that we should write to the CSR register in writeback.
  wire csr_write_1, csr_write_2, csr_write_3, csr_write_4;

  wire [31:0] alu_result_2, alu_result_3, alu_result_4;
  wire [31:0] store_data_2, store_data_3;

  /// Indicates if we should turn the following instructions into nops.
  /// Signalled on taken jumps.
  wire bubble;
  /// On reads, we don't know the result for a cycle, so we have to stall all
  /// the instructions in front of it for a cycle.
  /// We need to allow the PC to propagate through, so it needs to start one cycle ahead of everything else.
  wire pc_stall, icache_stall, dcache_stall;

  reg waiting_for_dcache, waiting_for_icache;
  /// TODO: fine grained stalls (what about simultaneous dcache and icache stalls), and/or adding fetch stage to act as buffer for bubble
  assign icache_re = !pc_stall && !do_jump_2;
  assign icache_stall = !icache_resp_valid & waiting_for_icache || !icache_req_ready;
  assign dcache_stall = !dcache_req_ready & (mem_rr_3 | mem_we_3) || !dcache_resp_valid & waiting_for_dcache;
  assign pc_stall = bubble || icache_stall || dcache_stall;

  assign icache_addr = next_pc;

  assign dcache_re = mem_rr_3 && !dcache_stall;

  /// Duplicated register files
  Regfile regfile(
    .clk(clk),
    .stall(pc_stall),
    .we(reg_we_4),
    .ra1(rs1_1), .ra2(rs2_1), .wa(rd_4),
    .prev_ra1(rs1_2), .prev_ra2(rs2_2),
    .wd(writeback),
    .rd1(reg_A_2), .rd2(reg_B_2)
  );

  /// The special CSR register used to communicate with the testbench.
  REGISTER_R_CE#(.N(32)) tohost(
    .clk(clk), .rst(reset),
    .ce(csr_write_4),
    .q(csr),
    .d(internal_wb)
  );
  
  /// This holds the PC value used for getting the next instruction.  
  /// It has to be delayed due to memory being synchronous.
  ProgramCounter pc(
    clk, reset, pc_stall,
    do_jump_2,
    jump_target,
    next_pc
  );
  
  /// The outut of this is the vale of PC in the execute stage.
  REGISTER_R_CE#(.N(32), .INIT(32'h13)) instruction_0_1_buffer(
    .clk(clk), .rst(reset || (do_jump_2 | do_jump_3) & !pc_stall),
    .ce(!pc_stall),
    .q(instruction_1),
    .d(instruction_0)
  );
  
  /// The outut of this is the vale of PC in the execute stage.
  REGISTER_R_CE#(.N(32)) pc_next_0_buffer(
    .clk(clk), .rst(reset),
    .ce(!pc_stall),
    .q(pc_0),
    .d(next_pc)
  );
  /// The outut of this is the vale of PC in the execute stage.
  REGISTER_R_CE#(.N(32)) pc_0_1_buffer(
    .clk(clk), .rst(reset),
    .ce(!pc_stall),
    .q(pc_1),
    .d(pc_0)
  );
  /// The outut of this is the vale of PC in the execute stage.
  REGISTER_R_CE#(.N(32)) pc_1_2_buffer(
    .clk(clk), .rst(reset),
    .ce(!pc_stall),
    .q(pc_2),
    .d(pc_1)
  );
  /// The output of this is the value of PC in the memjump stage.
  REGISTER_R_CE#(.N(32)) pc_2_3_buffer(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q(pc_3),
    .d(pc_2)
  );
  /// The output of this is the value of PC in the writeback stage.
  REGISTER_R_CE#(.N(32)) pc_3_4_buffer(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q(pc_4),
    .d(pc_3)
  );

  REGISTER_R_CE#(.N(5)) rs1_buffer_1_2(
    .clk(clk), .rst(reset),
    .ce(!pc_stall),
    .q(rs1_2),
    .d(rs1_1)
  );

  REGISTER_R_CE#(.N(5)) rs2_buffer_1_2(
    .clk(clk), .rst(reset),
    .ce(!pc_stall),
    .q(rs2_2),
    .d(rs2_1)
  );

  REGISTER_R_CE#(.N(5)) rs2_buffer_2_3(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q(rs2_3),
    .d(rs2_2)
 );

  REGISTER_R_CE#(.N(32)) result_2_3_buffer(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q(alu_result_3),
    .d(alu_result_2)
  );

  REGISTER_R_CE#(.N(32)) result_3_4_buffer(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q(alu_result_4),
    .d(alu_result_3)
  );

  REGISTER_R_CE#(.N(32)) store_data_buffer(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q(store_data_3),
    .d(store_data_2)
  );

  REGISTER_R_CE#(.N(6)) flags_buffer_1_2(
    .clk(clk), .rst(reset || (do_jump_2 | do_jump_3 | do_jump_4) & !pc_stall),
    .ce(!pc_stall),
    .q({reg_we_2, csr_write_2, mem_we_2, mem_rr_2, is_jump_2, is_branch_2}),
    .d({reg_we_1, csr_write_1, mem_we_1, mem_rr_1, is_jump_1, is_branch_1})
  );

  REGISTER_R_CE#(.N(5)) flags_buffer_2_3(
    .clk(clk), .rst(reset || (pc_stall | do_jump_3) & !dcache_stall),
    .ce(!dcache_stall & !icache_stall),
    .q({reg_we_3, csr_write_3, mem_rr_3, mem_we_3, do_jump_3}),
    .d({reg_we_2, csr_write_2, mem_rr_2, mem_we_2, do_jump_2})
  );

  REGISTER_R_CE#(.N(2)) reg_we_flags_buffer_3_4(
    .clk(clk), .rst(reset || dcache_stall & mem_rr_4 & !waiting_for_dcache || dcache_stall & !mem_rr_4),
    .ce(!dcache_stall),
    .q({reg_we_4, csr_write_4}),
    .d({reg_we_3, csr_write_3})
  );
  REGISTER_R_CE#(.N(2)) meta_flags_buffer_3_4(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q({do_jump_4, mem_rr_4}),
    .d({do_jump_3, mem_rr_3})
  );
  
  REGISTER_R_CE#(.N(3)) funct3_buffer_1_2(
    .clk(clk), .rst(1'b0),
    .ce(!pc_stall),
    .q(funct3_2),
    .d(funct3_1)
  );

  REGISTER_R_CE#(.N(3)) funct3_buffer_2_3(
    .clk(clk), .rst(1'b0),
    .ce(!dcache_stall),
    .q(funct3_3),
    .d(funct3_2)
  );

  REGISTER_R_CE#(.N(3)) funct3_buffer_3_4(
    .clk(clk), .rst(1'b0),
    .ce(!dcache_stall),
    .q(funct3_4),
    .d(funct3_3)
  );

  REGISTER_R_CE#(.N(4)) alu_op_buffer_1_2(
    .clk(clk), .rst(1'b0),
    .ce(!pc_stall),
    .q(alu_op_2),
    .d(alu_op_1)
  );

  REGISTER_R_CE#(.N(2)) select_buffer_1_2(
    .clk(clk), .rst(1'b0),
    .ce(!pc_stall),
    .q({a_sel_reg_2, b_sel_reg_2}),
    .d({a_sel_reg_1, b_sel_reg_1})
  );

  REGISTER_R_CE#(.N(32)) imm_buffer_1_2(
    .clk(clk), .rst(1'b0),
    .ce(!pc_stall),
    .q(imm_2),
    .d(imm_1)
  );

  REGISTER_R_CE#(.N(5)) rd_buffer_1_2(
    .clk(clk), .rst(reset),
    .ce(!pc_stall),
    .q(rd_2),
    .d(rd_1)
  );

  REGISTER_R_CE#(.N(5)) rd_buffer_2_3(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q(rd_3),
    .d(rd_2)
  );

  REGISTER_R_CE#(.N(5)) rd_buffer_3_4(
    .clk(clk), .rst(reset),
    .ce(!dcache_stall),
    .q(rd_4),
    .d(rd_3)
  );

  // assign instruction = icache_dout;
  
  StallHandler sh (
    clk, bubble, reset,
    icache_dout, instruction_0
  );
  
  // StallHandler stall_handler(clk, internal_stall, reset, dcache_dout, mem_out);
  assign mem_out = dcache_dout;

  DecodeRead stage1(
      .instr(instruction_1),

      .alu_op(alu_op_1),
      .is_jump(is_jump_1),
      .is_branch(is_branch_1),
      .funct3(funct3_1),
      .a_sel_reg(a_sel_reg_1), .b_sel_reg(b_sel_reg_1),
      .reg_we(reg_we_1), .mem_we(mem_we_1), .mem_rr(mem_rr_1),
      .rd(rd_1), .rs1(rs1_1), .rs2(rs2_1),
      .imm(imm_1),
      .csr_write(csr_write_1)
  );

  Execute stage2(
    .pc(pc_2), .reg_A(reg_A_2), .reg_B(reg_B_2),
    .imm(imm_2), .previous(alu_result_3), .writeback(internal_wb),

    .alu_op(alu_op_2),
    .is_jump(is_jump_2), .is_branch(is_branch_2),
    .funct3(funct3_2),

    .rs1(rs1_2), .rs2(rs2_2), .prev_rd(rd_3), .wb_rd(rd_4),
    .mem_we(mem_we_2),
    .prev_mem_rr(mem_rr_3),
    .wb_mem_rr(mem_rr_4),


    .prev_reg_we(reg_we_3),
    .wb_reg_we(reg_we_4),

    .a_sel_reg(a_sel_reg_2), .b_sel_reg(b_sel_reg_2),

    .bubble(bubble),
    .do_jump(do_jump_2),
    .result(alu_result_2), .store_data(store_data_2),
    .jump_target(jump_target)
  );

  MemoryAccess stage3 (
    .mem_we(mem_we_3),
    .funct3(funct3_3),
    .alu_result(alu_result_3),
    .bwe(dcache_we),
    .dcache_addr(dcache_addr),
    .data(store_data_3), .dcache_din(dcache_din)
  );

  Writeback stage4 (
    .pc(pc_4),
    .alu_result(alu_result_4),
    .funct3(funct3_4),
    .reg_we(reg_we_4), .mem_rr(mem_rr_4), .do_jump(do_jump_4),
    .dcache_dout(mem_out),
    .writeback(writeback), .internal_wb(internal_wb)
  );

  always @(posedge clk) begin
    prev_reset <= reset;
    if (reset) begin
      waiting_for_dcache <= 1'b0;
      waiting_for_icache <= 1'b0;
    end else begin
      if (dcache_re && !dcache_stall) begin
        waiting_for_dcache <= 1'b1;
      end else if (dcache_resp_valid) begin
        waiting_for_dcache <= 1'b0;
      end
      if (icache_re && !icache_stall && !dcache_stall) begin
        waiting_for_icache <= 1'b1;
      end else if (icache_resp_valid) begin
        waiting_for_icache <= 1'b0;
      end
    end
  end
endmodule
