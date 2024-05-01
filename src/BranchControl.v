module BranchControl (
    input [31:0] A, B,
    input [2:0] funct3,
    output condition_true
);
    wire test_less, unsigned_comparison, inv, is_less_than, is_equal;
    assign {test_less, unsigned_comparison, inv} = funct3;
    assign condition_true = inv ^ (test_less ? is_less_than : is_equal);
    branch_comp bc (
        .unsigned_comparison(unsigned_comparison),
        .A(A),
        .B(B),
        .less_than(is_less_than),
        .equal(is_equal)
    );
endmodule
