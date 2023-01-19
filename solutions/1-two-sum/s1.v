module s1 #(
    parameter DATA_WIDTH = 2,
    parameter ARRAY_SIZE = 2 ** DATA_WIDTH
) (
    input clk,
    input rst,
    input wire signed [DATA_WIDTH-1:0] number,
    input wire number_valid,
    input wire number_last,
    input wire signed [DATA_WIDTH-1:0] target,
    output reg [$clog2(ARRAY_SIZE)-1:0] index1,
    output reg [$clog2(ARRAY_SIZE)-1:0] index2,
    output reg index_valid = 0
);
  reg [$clog2(ARRAY_SIZE)-1:0] number_index;
  wire collision;
  wire signed [DATA_WIDTH-1:0] complement;
  wire [$clog2(ARRAY_SIZE)-1:0] complement_index;
  wire complement_valid;
  wire clear_cache;
  reg last_received;
  initial begin
    number_index  <= 0;
    last_received <= 0;
  end
  always @(posedge clk)
    if (rst) number_index <= 0;
    else if (number_valid)
      if (number_last) number_index <= 0;
      else number_index <= number_index + 1;
  always @(posedge clk)
    if (rst) last_received <= 0;
    else last_received <= number_valid & number_last;
  always @(posedge clk)
    if (rst) index_valid <= 0;
    else if (index_valid) begin
      if (last_received) index_valid <= 0;
    end else if (number_valid && complement_valid) begin
      index1 <= number_index;
      index2 <= complement_index;
      index_valid <= 1;
    end
  hashmap #(
      .KEY_WIDTH  (DATA_WIDTH),
      .VALUE_WIDTH($clog2(ARRAY_SIZE)),
      .CACHE_SIZE (ARRAY_SIZE),
      .OVERWRITE  (1)
  ) hashmap_i (
      .clk(clk),
      .rst(rst),
      .write_key(number),
      .write_value(number_index),
      .write_request(number_valid),
      .collision(collision),
      .read_key(complement),
      .read_value(complement_index),
      .read_response(complement_valid),
      .clear_cache(clear_cache)
  );
  assign complement  = target - number;
  assign clear_cache = number_valid && number_last;
`ifdef FORMAL
  localparam _STATE_FIRST = 0;
  localparam _STATE_SECOND = 1;
  localparam _STATE_LAST = 2;
  reg _past_valid;
  (* anyconst *) reg signed [DATA_WIDTH-1:0] _target1;
  (* anyconst *) reg signed [DATA_WIDTH-1:0] _number1;
  reg signed [DATA_WIDTH-1:0] _number2;
  reg [$clog2(ARRAY_SIZE)-1:0] _index1;
  reg [$clog2(ARRAY_SIZE)-1:0] _index2;
  reg [1:0] _state;
  reg [1:0] _state_next;
  initial begin
    _past_valid <= 0;
    _state <= _STATE_FIRST;
    _number2 <= _target1 - _number1;
  end
  always @(posedge clk) _past_valid <= 1;
  always @(posedge clk)
    if (rst) _state <= _STATE_FIRST;
    else if (number_valid)
      if (number_last) _state <= _STATE_FIRST;
      else _state <= _state_next;
  always @*
    case (_state)
      _STATE_FIRST: _state_next = _STATE_SECOND;
      default: _state_next = _STATE_LAST;
    endcase
  always @(posedge clk) if (_state == _STATE_FIRST) _index2 <= number_index;
  always @(posedge clk) if (_state == _STATE_SECOND) _index1 <= number_index;
  // assumptions
  always @* assume (target == _target1);
  always @(posedge clk) if (_past_valid && index_valid && !last_received) assume ($stable(_state));
  always @(posedge clk) if (_past_valid && $stable(number)) assume ($stable(number_last));
  always @(posedge clk) if (!number_valid) assume (!number_last);
  always @* if (number_index == ARRAY_SIZE - 1) assume (number_last);
  always @* if (!index_valid) assume (_state < 2);
  always @*
    case (_state)
      _STATE_FIRST: assume (number == _number2);
      _STATE_SECOND: assume (number == _number1);
      default: assume (number != _number1 && number != _number2);
    endcase
  // verify that the indices are correct if a solution has been found
  always @* if (index_valid) assert (index1 == _index1 && index2 == _index2);
`ifdef TOP
  // cover the case where a solution exists
  always @* cover (index_valid);
`endif
`endif
endmodule
