module hashmap
  #(
    parameter KEY_WIDTH = 4,
    parameter VALUE_WIDTH = 4,
    parameter CACHE_SIZE = 4,
    parameter OVERWRITE = 1)
  (
    input wire clk,
    input wire rst,
    input wire [KEY_WIDTH - 1 : 0] write_key,
    input wire [VALUE_WIDTH - 1 : 0] write_value,
    input wire write_request,
    output wire collision,
    input wire [KEY_WIDTH - 1 : 0] read_key,
    output wire [VALUE_WIDTH - 1 : 0] read_value,
    output wire read_response,
    input wire clear_cache);
  localparam ADDR_WIDTH = $clog2(CACHE_SIZE);
  reg [KEY_WIDTH - 1 : 0] key_mem[0 : CACHE_SIZE - 1];
  reg [VALUE_WIDTH - 1 : 0] value_mem[0 : CACHE_SIZE - 1];
  reg [CACHE_SIZE - 1 : 0] valid_mem;
  wire [ADDR_WIDTH - 1 : 0] write_ptr;
  wire [ADDR_WIDTH - 1 : 0] read_ptr;
  integer i;
  initial
    for (i = 0; i < CACHE_SIZE; i = i + 1)
      valid_mem[i] <= 0;
  assign write_ptr = hash(write_key);
  always @(posedge clk)
    if (rst || clear_cache)
      for (i = 0; i < CACHE_SIZE; i = i + 1)
        valid_mem[i] <= 0;
    else if (write_request)
      valid_mem[write_ptr] <= 1;
  always @(posedge clk)
    if (write_request)
      if (OVERWRITE == 1 || !valid_mem[write_ptr]) begin
        key_mem[write_ptr] <= write_key;
        value_mem[write_ptr] <= write_value;
      end
  assign collision = write_request && valid_mem[write_ptr];
  assign read_ptr = hash(read_key);
  assign read_value = value_mem[read_ptr];
  assign read_response = valid_mem[read_ptr];
  function [ADDR_WIDTH - 1 : 0] hash
    (input [KEY_WIDTH - 1 : 0] key);
    hash = key % CACHE_SIZE;
  endfunction
`ifdef FORMAL
  reg _past_valid;
  reg _collision_occured;
  (* anyconst *) reg [KEY_WIDTH - 1 : 0] _key1;
  (* anyconst *) reg [VALUE_WIDTH - 1 : 0] _val1;
  reg [ADDR_WIDTH - 1 : 0] _hash1;
  initial begin
    _past_valid <= 0;
    _collision_occured <= 0;
    _hash1 <= hash(_key1);
  end
  always @(posedge clk)
    _past_valid <= 1;
  always @(posedge clk)
    if (rst || clear_cache)
      _collision_occured <= 0;
    else if (write_request)
      if (write_key == _key1)
        _collision_occured <= 0;
      else if (hash(write_key) == _hash1)
        _collision_occured <= 1;
  // assumptions
  always @*
    if (!_collision_occured && valid_mem[_hash1])
      assume (key_mem[_hash1] == _key1 && value_mem[_hash1] == _val1);
  always @*
    if (write_key == _key1)
      assume (write_value == _val1);
  // verify that data is available at the output one clock cycle after a successful write
  always @(posedge clk)
    if (_past_valid && $past(!rst && !clear_cache && write_request) && read_key == $past(write_key)) begin
      assert (read_response);
      assert (read_value == $past(write_value));
    end
  // verify that read queries fail when the cache is empty
  always @(posedge clk)
    if (_past_valid && $past(rst || clear_cache))
      assert (!read_response);
  // verify that a query with a known key returns the correct value unless a collision occured
  always @*
    if (!_collision_occured && read_key == _key1 && read_response)
      assert (read_value == _val1);
`ifdef TOP
  // cover the case of a successful query
  always @*
    cover (read_response);
  // cover the case of full cache
  always @*
    cover (&valid_mem);
  // cover the case of a collision
  always @*
    cover (collision);
`endif
`endif
endmodule
