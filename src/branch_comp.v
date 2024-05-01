module branch_comp (
  input unsigned_comparison,
  input [31:0] A,
  input [31:0] B,
  output less_than,
  output equal
);
  assign equal = A == B;
  assign less_than = unsigned_comparison ? A < B : $signed(A) < $signed(B);
endmodule