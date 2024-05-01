module StallHandler (
    input clk, stall, reset,
    input [31:0] in,
    output [31:0] out
);

    reg [31:0] prev_in;
    reg prev_stall, occupied;

    assign out = occupied && prev_stall ? prev_in : in;

    always @(posedge clk) begin
        if (reset) begin
            occupied <= 1'b0;
            prev_stall <= 1'b0;
        end else if (stall && !prev_stall) begin
            prev_in <= in;
            occupied <= 1'b1;
        end
        prev_stall <= stall;
    end
    
endmodule