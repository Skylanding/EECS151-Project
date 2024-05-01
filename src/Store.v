module Store (
    input [31:0] addr, value,
    input [2:0] funct3,
    input we,
    /// Byte write enables, all 0 indicates no write
    output reg [3:0] bwe,
    output reg [31:0] write_out
);
    always @(*) begin
        case (funct3)
            `FNC_SB: begin
                bwe = {3'b000, we} << addr[1:0];
                write_out = (32'h000000FF & value) << {addr[1:0], 3'b000};
                
                byte_we_mask_bitcount_correct:
                assert (!we || $countones(bwe) == 1)
                else   $error("Byte write mask has %d bits", $countones(bwe));
            end
            `FNC_SH: begin
                bwe = {4{we}} & 4'b0011 << {addr[1], 1'b0};
                write_out = (32'h0000FFFF & value) << {addr[1], 4'b0000};
                
                halfword_we_mask_bitcount_correct:
                assert (!we || $countones(bwe) == 2)
                else   $error("Half-word write mask has %d bits", $countones(bwe));
            end
            `FNC_SW: begin
                bwe = {4{we}} & 4'b1111;
                write_out = value;
                
                word_we_mask_bitcount_correct:
                assert (!we || $countones(bwe) == 4)
                else   $error("Word write mask has %d bits", $countones(bwe));
            end
            default: begin
                bwe = 4'b0000;
                write_out = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
            end
        endcase
    end
endmodule