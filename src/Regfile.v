module Regfile (
    input clk,
    input stall,
    input we,  //write enable
    input [4:0] ra1, ra2, wa, // address A, address B, and write address
    input [4:0] prev_ra1, prev_ra2,
    input [31:0] wd, //write data
    output [31:0] rd1, rd2 // A, B
);
    reg saved_stall, saved_did_write, forward_A, forward_B;

    reg [31:0] A, B, A_stall, B_stall, prev_wd;

    reg [31:0] registers [31:1];

    assign rd1 = saved_did_write && forward_A ? prev_wd : saved_stall ? A_stall : A;
    assign rd2 = saved_did_write && forward_B ? prev_wd : saved_stall ? B_stall : B;

    always @(posedge clk) begin
        A <= ra1 == 5'd0 ? 32'd0 : registers[ra1];
        B <= ra2 == 5'd0 ? 32'd0 :  registers[ra2];
        A_stall <= prev_ra1 == 5'd0 ? 32'd0 : registers[prev_ra1];
        B_stall <= prev_ra2 == 5'd0 ? 32'd0 : registers[prev_ra2];
        forward_A <= (stall ? wa == prev_ra1 : wa == ra1);
        forward_B <= (stall ? wa == prev_ra2 : wa == ra2);
        saved_stall <= stall;
        saved_did_write <= we && wa != 5'd0;
        if (we && wa != 5'd0) begin
            registers[wa] <= wd;
            prev_wd <= wd;
        end
    end
endmodule
