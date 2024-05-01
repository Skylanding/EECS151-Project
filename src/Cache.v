`include "util.vh"
`include "const.vh"

module cache #
(
  parameter LINES = 64,
  //  32
  parameter CPU_WIDTH = `CPU_INST_BITS,
  //  Number of bits required to address a word: 30
  parameter WORD_ADDR_BITS = `CPU_ADDR_BITS-`ceilLog2(`CPU_INST_BITS/8)
)
(
  input clk,
  input reset,

  input                       cpu_req_valid,
  output                      cpu_req_ready,
  input [WORD_ADDR_BITS-1:0]  cpu_req_addr,
  input [CPU_WIDTH-1:0]       cpu_req_data,
  input [3:0]                 cpu_req_write,

  output                      cpu_resp_valid,
  output [CPU_WIDTH-1:0]      cpu_resp_data,

  output                      mem_req_valid,
  input                       mem_req_ready,
  //  [29:2]
  output [WORD_ADDR_BITS-1:`ceilLog2(`MEM_DATA_BITS/CPU_WIDTH)] mem_req_addr,
  output                           mem_req_rw,
  output                           mem_req_data_valid,
  input                            mem_req_data_ready,
  output [`MEM_DATA_BITS-1:0]      mem_req_data_bits,
  // byte level masking
  output [(`MEM_DATA_BITS/8)-1:0]  mem_req_data_mask,

  input                       mem_resp_valid,
  input [`MEM_DATA_BITS-1:0]  mem_resp_data
);

  localparam CACHE_LINE_SIZE = 512;
  localparam INDEX_WIDTH = `ceilLog2(LINES);
  //  The number of bits required to get a word from a cache line
  localparam CACHE_ADDR_BITS = 4;
  localparam TAG_WIDTH = WORD_ADDR_BITS - INDEX_WIDTH - CACHE_ADDR_BITS; 

  reg [31:0] prev_resp;

  wire cpu_req_is_write;
  wire in_hit, in_miss, next_state_is_miss, in_write;
  wire line_is_dirty, saving_line;
  wire [1:0] current_dirty_block;

  reg line_present, previously_in_miss;
  reg [3:0] line_dirty_blocks;
  reg [TAG_WIDTH-1:0] line_tag;

  reg [63:0] meta_present;

  wire [WORD_ADDR_BITS-1:CACHE_ADDR_BITS+INDEX_WIDTH] tag, prev_tag;
  wire [WORD_ADDR_BITS-TAG_WIDTH-1:CACHE_ADDR_BITS] index, prev_index;
  wire [CACHE_ADDR_BITS-1:0] word, prev_word;
  wire [1:0] sram_lower, wordselect;


  //valid bits 
  reg meta_dout_present;
  //dirty bits
  wire [3:0] meta_dout_dirty, meta_din_dirty;
  wire [TAG_WIDTH-1:0] meta_dout_tag, meta_din_tag;

  reg [2:0] state, next_state;
  //  The cache is not doing anything at the moment, and is open to requests
  localparam IDLE = 3'b000;
  //  The cache is checking the metadata.  If there is a cache hit, 4+TAG_WIDTH then 
  localparam READ_QUERY = 3'b001;
  localparam WRITE_QUERY = 3'b011;
  localparam CACHE_READ_MISS = 3'b100;
  localparam CACHE_WRITE_MISS = 3'b110;

  wire meta_we; 
  wire [3:0] meta_wmask;
  wire data_we [4];
  reg [7:0] data_addr;
  wire [5:0] meta_addr;
  wire [CPU_WIDTH-1:0] meta_din;
  wire [CPU_WIDTH-1:0] data_din [4];
  wire [CPU_WIDTH-1:0] meta_dout;
  wire [CPU_WIDTH-1:0] data_dout [4];

  reg [1:0] current_cache_block;

  /// Since the SRAM is synchronous, if we want to be able to output the result the cycle that we
  /// are done getting a cache line, we need to save it outside of the SRAM so it can be accessed
  /// immediately.
  reg [CPU_WIDTH-1:0] async_cache;
  /// The CPU may change the requested address each cycle, so if there is a miss, we need to store the previous address.
  reg [WORD_ADDR_BITS-1:0] previous_address;
  reg [31:0] prev_req_data;
  reg [3:0] prev_req_write;

  assign cpu_req_is_write = |cpu_req_write;
  
  assign {sram_lower, wordselect} = word;
  assign {tag, index, word} = cpu_req_addr;
  assign {prev_tag, prev_index, prev_word} = previous_address;

  assign {meta_dout_dirty, meta_dout_tag} = meta_dout[0+:4+TAG_WIDTH];
  assign meta_din = {{(32-(4+TAG_WIDTH)){1'b0}}, meta_din_dirty, meta_din_tag};

  assign data_addr = {
    in_miss || state == WRITE_QUERY ? prev_index : index,
    saving_line ? current_dirty_block : in_miss ? current_cache_block : state == WRITE_QUERY ? prev_word[3:2] : sram_lower
  };
  assign meta_addr = in_miss || state == WRITE_QUERY ? prev_index : index;

  assign in_hit = (previously_in_miss && !in_miss) 
    || (meta_dout_present && meta_dout_tag == prev_tag && (state == READ_QUERY || state == WRITE_QUERY));
  assign in_miss = state == CACHE_WRITE_MISS || state == CACHE_READ_MISS;
  assign next_state_is_miss = next_state == CACHE_WRITE_MISS || next_state == CACHE_READ_MISS;
  assign line_is_dirty = |line_dirty_blocks;
  assign in_write = state == WRITE_QUERY || state == CACHE_WRITE_MISS;
  assign current_dirty_block = line_dirty_blocks[0] ? 2'd0 : line_dirty_blocks[1] ? 2'd1 : line_dirty_blocks[2] ? 2'd2 : 2'd3;
  assign saving_line = line_is_dirty && in_miss;

  assign cpu_resp_valid = (state == READ_QUERY || state == IDLE) && in_hit;

  assign cpu_req_ready = state == IDLE || (state == READ_QUERY && in_hit);

  assign cpu_resp_data = previously_in_miss ? async_cache : state == IDLE ? prev_resp : data_dout[prev_word[1:0]];

  assign mem_req_rw = saving_line;
  assign mem_req_data_valid = mem_req_valid;
  assign mem_req_valid = saving_line || (in_miss && current_cache_block == 2'd0);
  assign mem_req_addr = saving_line ? {line_tag, prev_index, current_dirty_block} : {prev_tag, prev_index, 2'b00};
  assign mem_req_data_bits = {data_dout[3], data_dout[2], data_dout[1], data_dout[0]};
  assign mem_req_data_mask = 16'hFFFF;

  assign meta_wmask = 4'hF;
  assign meta_we = (state == WRITE_QUERY && in_hit)
    || (in_miss && !next_state_is_miss);
  assign meta_din_tag = prev_tag;
  
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin
      assign data_we[i] = (state == CACHE_READ_MISS && mem_resp_valid)
        || (state == WRITE_QUERY && in_hit && prev_word[1:0] == i[1:0])
        || (state == CACHE_WRITE_MISS && (!line_present || !saving_line) && mem_resp_valid);
      assign data_din[i] = (state == WRITE_QUERY && in_hit) ? prev_req_data : mem_resp_data[CPU_WIDTH*i+:CPU_WIDTH];
      assign meta_din_dirty[i] = (state == WRITE_QUERY && in_hit && prev_word[3:2] == i[1:0]) 
        || (state == WRITE_QUERY && in_hit && !previously_in_miss ? meta_dout_dirty[i] : line_dirty_blocks[i]);
    end
  endgenerate

  sram22_256x32m4w8 sramData0 (
    .clk(clk),
    .we(data_we[0]),
    .wmask(state == WRITE_QUERY ? prev_req_write : 4'hF),
    .addr(data_addr),
    .din(data_din[0]),
    .dout(data_dout[0])
  );    

  sram22_256x32m4w8 sramData1 (
    .clk(clk),
    .we(data_we[1]),
    .wmask(state == WRITE_QUERY ? prev_req_write : 4'hF),
    .addr(data_addr),
    .din(data_din[1]),
    .dout(data_dout[1])
  );    
  sram22_256x32m4w8 sramData2 (
    .clk(clk),
    .we(data_we[2]),
    .wmask(state == WRITE_QUERY ? prev_req_write : 4'hF),
    .addr(data_addr),
    .din(data_din[2]),
    .dout(data_dout[2])
  );    
  sram22_256x32m4w8 sramData3 (
    .clk(clk),
    .we(data_we[3]),
    .wmask(state == WRITE_QUERY ? prev_req_write : 4'hF),
    .addr(data_addr),
    .din(data_din[3]),
    .dout(data_dout[3])
  );        


  // {valid, tag}
  sram22_64x32m4w8 sramMeta (
    .clk(clk),
    .we(meta_we),
    .wmask(meta_wmask),
    .addr(meta_addr),
    .din(meta_din),
    .dout(meta_dout)
  );

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (cpu_req_valid && cpu_req_ready) begin
          if (cpu_req_is_write) begin
            next_state = WRITE_QUERY;
          end else begin
            next_state = READ_QUERY;
          end
        end
      end
      READ_QUERY: begin
        if (in_hit) begin
          if (!cpu_req_valid) next_state = IDLE;
        end else begin
          next_state = CACHE_READ_MISS;
        end
      end
      WRITE_QUERY: begin
        if (in_hit) begin
          next_state = IDLE;
        end else begin
          next_state = CACHE_WRITE_MISS;
        end
      end
      CACHE_READ_MISS: begin
        if (mem_resp_valid && current_cache_block == 2'b11) begin
          next_state = IDLE;
        end
      end
      CACHE_WRITE_MISS: begin
        if (mem_resp_valid && current_cache_block == 2'b11) begin
          next_state = WRITE_QUERY;
        end
      end 
    endcase
  end

  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      current_cache_block <= 2'd0;
      line_dirty_blocks <= 4'd0;
      previously_in_miss <= 1'b0;
      meta_present <= 64'd0;
    end else begin
      state <= next_state;
      previously_in_miss <= in_miss;
      if (in_miss && next_state == WRITE_QUERY) meta_dout_present <= 1'b1;
      else meta_dout_present <= meta_present[meta_addr];
      if (!in_miss && (next_state == READ_QUERY || next_state == WRITE_QUERY)) previous_address <= cpu_req_addr;
      if (next_state == WRITE_QUERY && !in_miss) begin
        prev_req_data <= cpu_req_data;
        prev_req_write <= cpu_req_write;
      end
      if ((state == READ_QUERY || state == WRITE_QUERY) && next_state_is_miss) begin
        current_cache_block <= 2'd0;
        line_present <= meta_dout_present;
        line_dirty_blocks <= meta_dout_dirty;
        line_tag <= meta_dout_tag;
      end
      if (state == READ_QUERY) begin
        prev_resp <= cpu_resp_data;
      end
      if (saving_line && mem_req_data_ready) begin
        line_dirty_blocks[current_dirty_block] <= 1'b0;
      end
      if (in_miss) begin
        if (mem_resp_valid && !line_is_dirty) begin
          current_cache_block <= current_cache_block + 2'd1;
          if (state == CACHE_READ_MISS && current_cache_block == prev_word[3:2]) begin
            async_cache <= data_din[prev_word[1:0]];
          end
        end
        if (!next_state_is_miss) begin
          meta_present[prev_index] <= 1'b1;
        end
      end
    end
  end

endmodule
