`timescale 1ns/1ns

module TB_FETCHER;
  
  // parameters
  localparam PROGRAM_MEM_ADDR_BITS = 8;
  localparam PROGRAM_MEM_DATA_BITS = 16;
  
  
  reg clk;
  reg reset;
  
  // inputs to DUT
  reg [2:0] core_state;
  reg [7:0] current_pc;
  reg mem_read_ready;
  reg [PROGRAM_MEM_DATA_BITS-1:0] mem_read_data;
  
  // outputs from DUT
  wire mem_read_valid;
  wire [PROGRAM_MEM_ADDR_BITS-1:0] mem_read_address;
  wire [2:0] fetcher_state;
  wire [PROGRAM_MEM_DATA_BITS-1:0] instruction;
  
  // state definitions 
  localparam IDLE = 3'b000;
  localparam FETCHING = 3'b001;
  localparam FETCHED = 3'b010;
  
  // core state definitions
  localparam CORE_IDLE = 3'b000;
  localparam CORE_FETCH = 3'b001;
  localparam CORE_DECODE = 3'b010;
  
  // DUT INSTANTIATION
  fetcher #(
    .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
    .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS)
  ) dut (
    .clk(clk),
    .reset(reset),
    .core_state(core_state),
    .current_pc(current_pc),
    .mem_read_valid(mem_read_valid),
    .mem_read_address(mem_read_address),
    .mem_read_ready(mem_read_ready),
    .mem_read_data(mem_read_data),
    .fetcher_state(fetcher_state),
    .instruction(instruction)
  );
  
  // CLOCK GENERATION (10ns period)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // TASKS
  task do_reset();
    begin
      reset = 1;
      core_state = CORE_IDLE;
      current_pc = 8'h00;
      mem_read_ready = 0;
      mem_read_data = 16'h0000;
      
      repeat(2) @(posedge clk);
      reset = 0;
      @(posedge clk);
    end
  endtask
  
  task memory_respond(input [15:0] data, input int delay_cycles);
    begin
      repeat(delay_cycles) @(posedge clk);
      mem_read_data = data;
      mem_read_ready = 1;
      @(posedge clk);
      mem_read_ready = 0;
      mem_read_data = 16'h0000;
    end
  endtask
  
  task request_fetch(input [7:0] pc_value);
    begin
      current_pc = pc_value;
      core_state = CORE_FETCH;
      @(posedge clk);
    end
  endtask
  
  task move_to_decode();
    begin
      core_state = CORE_DECODE;
      @(posedge clk);
      core_state = CORE_IDLE;
    end
  endtask
  
  // TEST SEQUENCE
  initial begin
    
    // TEST 0: reset 
    do_reset();
    
    // TEST 1: basic fetch
    request_fetch(8'h10);
    memory_respond(16'hABCD, 0);
    move_to_decode();
    
    // TEST 2: betch with memory delay
    request_fetch(8'h20);
    fork
      begin
        repeat(3) @(posedge clk);
      end
      memory_respond(16'h1234, 3);
    join
    move_to_decode();
    
    // TEST 3: many sequential Fetches
    request_fetch(8'h00);
    memory_respond(16'hDEAD, 1);
    move_to_decode();
    
    repeat(1) @(posedge clk);
    
    request_fetch(8'h01);
    memory_respond(16'hBEEF, 1);
    move_to_decode();
    
    repeat(1) @(posedge clk);
    
    request_fetch(8'h02);
    memory_respond(16'hCAFE, 1);
    move_to_decode();
    
    // TEST 4: stay in IDLE when not requested
    core_state = CORE_IDLE;
    repeat(5) @(posedge clk);
    
    // TEST 5: FETCHED State 
    request_fetch(8'h50);
    memory_respond(16'h5678, 1);
    
    core_state = CORE_FETCH;
    repeat(5) @(posedge clk);
    
    move_to_decode();
    
    // TEST 6: different PC values
    request_fetch(8'hFF);
    memory_respond(16'h9999, 0);
    move_to_decode();
    
    repeat(1) @(posedge clk);
    
    request_fetch(8'h7F);
    memory_respond(16'h8888, 0);
    move_to_decode();
    
    repeat(3) @(posedge clk);
    $finish;
  end
  
endmodule 