module s1 #(
    parameter DATA_WIDTH = 2,
    parameter ARRAY_SIZE = 2 ** DATA_WIDTH  // to avoid hash collisions
) (
    input clk,
    input rst,
    input wire signed [DATA_WIDTH-1:0] number,
    input wire number_valid,
    input wire number_last,
    input wire signed [DATA_WIDTH-1:0] target,
    output wire [$clog2(ARRAY_SIZE)-1:0] index1,
    output wire [$clog2(ARRAY_SIZE)-1:0] index2,
    output wire index_valid
);
  reg [$clog2(ARRAY_SIZE)-1:0] number_index;
  wire signed [DATA_WIDTH-1:0] complement;
  wire [$clog2(ARRAY_SIZE)-1:0] complement_index;
  wire complement_valid;
  wire clear_cache;
  reg [$clog2(ARRAY_SIZE)-1:0] index1_int;
  reg [$clog2(ARRAY_SIZE)-1:0] index2_int;
  reg index_valid_int;
  initial begin
    number_index <= 0;
    index_valid_int <= 0;
  end
  always @(posedge clk)
    if (rst) number_index <= 0;
    else if (number_valid)
      if (number_last) number_index <= 0;
      else number_index <= number_index + 1;
  always @(posedge clk)
    if (rst) index_valid_int <= 0;
    else if (index_valid) begin
      if (clear_cache) index_valid_int <= 0;
    end else if (complement_valid) begin
      index1_int <= number_index;
      index2_int <= complement_index;
      index_valid_int <= 1;
    end
  hashmap #(
      .KEY_WIDTH  (DATA_WIDTH),
      .VALUE_WIDTH($clog2(ARRAY_SIZE)),
      .CACHE_SIZE (ARRAY_SIZE)
  ) hashmap_i (
      .clk(clk),
      .rst(rst),
      .write_key(number),
      .write_value(number_index),
      .write_request(number_valid),
      .read_key(complement),
      .read_value(complement_index),
      .read_response(complement_valid),
      .clear_cache(clear_cache)
  );
  assign complement = target - number;
  assign clear_cache = number_valid && number_last;
  assign index1 = index1_int;
  assign index2 = index2_int;
  assign index_valid = index_valid_int;
`ifdef FORMAL
  reg _past_valid;
  (* anyconst *) reg signed [DATA_WIDTH-1:0] _target1;
  (* anyconst *) reg signed [DATA_WIDTH-1:0] _number1;
  reg signed [DATA_WIDTH-1:0] _number2;
  reg [$clog2(ARRAY_SIZE)-1:0] _index1;
  reg [$clog2(ARRAY_SIZE)-1:0] _index2;
  initial begin
    _past_valid <= 0;
    _number2 <= _target1 - _number1;
  end
  always @(posedge clk) _past_valid <= 1;
  always @* assume (target == _target1);
  always @* if (number_index == ARRAY_SIZE - 1) assume (number_last);
  always @(posedge clk) if (number_valid && number == _number1) _index1 <= number_index;
  always @(posedge clk) if (number_valid && number == _number2) _index2 <= number_index;
  // verify that the indices are correct (ignore the order)
  always @(posedge clk)
    if (index_valid)
      assert ((index1 == _index1 && index2 == _index2) || (index1 == _index2 && index2 == _index1));
  // cover the case where a solution has been found
  always @* cover (index_valid);
`endif
endmodule
