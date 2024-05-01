`include "Opcode.vh"

module ld (
  input [31:0] mem_address,
  input [31:0] mem_output,
  input [2:0] funct3,
  output [31:0] load_out
);
  reg [31:0] out_internal;
  
  //Spec: https://inst.eecs.berkeley.edu/~eecs151/fa23/static/asic/project/docs/pg3-ckpt2/#misaligned-addresses
  wire [1:0] offset;
  assign offset = mem_address[1:0];

  always @(*) begin
    case (funct3)
      `FNC_LH: begin
        case (offset)
          2'b00: out_internal = { {16{ mem_output[15] }}, mem_output[15:0] };
          2'b01: out_internal = { {16{ mem_output[23] }}, mem_output[23:8] };
          2'b10, 2'b11: out_internal = { {16{ mem_output[31] }}, mem_output[31:16] };
        endcase
        
        // word_load_upper_bits_correct:
        // assert (&out_internal[31:16] || !|out_internal[31:16]) 
        // else   $error("Word read has non-uniform upper bits: %b", out_internal[31:16]);
      end
      `FNC_LB: begin
        case (offset)
          2'b00: out_internal = { {24{ mem_output[7]  }}, mem_output[7:0] };
          2'b01: out_internal = { {24{ mem_output[15] }}, mem_output[15:8] };
          2'b10: out_internal = { {24{ mem_output[23] }}, mem_output[23:16] };
          2'b11: out_internal = { {24{ mem_output[31] }}, mem_output[31:24] };
        endcase
        
        // byte_load_upper_bits_correct:
        // assert (&out_internal[31:8] || !|out_internal[31:8]) 
        // else   $error("Byte read has non-uniform upper bits: %b", out_internal[31:8]);
      end
      `FNC_LHU: begin
        case (offset)
          2'b00: out_internal = { 16'b0, mem_output[15:0] };
          2'b01: out_internal = { 16'b0, mem_output[23:8] };
          2'b10, 2'b11: out_internal = { 16'b0, mem_output[31:16] };
        endcase
        
        // unsigned_word_load_upper_bits_correct:
        // assert (!|out_internal[31:16]) 
        // else   $error("Unsigned word read has non-zero upper bits: %b", out_internal[31:16]);
      end
      `FNC_LBU: begin
        case (offset)
          2'b00: out_internal = { 24'b0, mem_output[7:0] };
          2'b01: out_internal = { 24'b0, mem_output[15:8] };
          2'b10: out_internal = { 24'b0, mem_output[23:16] };
          2'b11: out_internal = { 24'b0, mem_output[31:24] };
        endcase
        
        // unsigned_byte_load_upper_bits_correct:
        // assert (!|out_internal[31:8]) 
        // else   $error("Byte read has non-zero upper bits: bd", out_internal[31:8]);
      end
      `FNC_LW: out_internal = mem_output;
      default: out_internal = mem_output;
    endcase
  end

  assign load_out = out_internal;
endmodule