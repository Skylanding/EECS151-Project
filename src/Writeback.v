module Writeback (
  input [31:0] pc,
  input [31:0] alu_result,
  input [31:0] dcache_dout,
  input [2:0] funct3,
  input reg_we, mem_rr, do_jump,

  output [31:0] writeback, internal_wb
);
  
  
  wire jalr;
  wire [31:0] masked_load;

  ld mask (
    .mem_address(alu_result),
    .mem_output(dcache_dout),
    .funct3(funct3),
    .load_out(masked_load)
  );

  assign jalr = reg_we & do_jump;
  assign writeback = jalr ? pc + 32'd4
    : mem_rr ? masked_load
    : alu_result;
  assign internal_wb = jalr ? pc + 32'd4 : alu_result;
  
endmodule