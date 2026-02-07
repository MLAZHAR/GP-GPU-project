`timescale 1ns/1ns

module TB_CONTROLLER;
  
  // parameters
  localparam ADDR_BITS = 8;
  localparam DATA_BITS = 16;
  localparam NUM_CONSUMERS = 4;
  localparam NUM_CHANNELS = 1;
  localparam WRITE_ENABLE = 1;
  

  reg clk;
  reg reset;
  
  // inputs to controller from consumer
  reg [NUM_CONSUMERS-1:0] consumer_read_valid;
  reg [ADDR_BITS-1:0] consumer_read_address [0:NUM_CONSUMERS-1];
  reg [NUM_CONSUMERS-1:0] consumer_write_valid;
  reg [ADDR_BITS-1:0] consumer_write_address [NUM_CONSUMERS-1:0];
  reg [DATA_BITS-1:0] consumer_write_data [NUM_CONSUMERS-1:0];
  
  // outputs from controller to consumer
  wire [NUM_CONSUMERS-1:0] consumer_read_ready;
  wire [DATA_BITS-1:0] consumer_read_data [NUM_CONSUMERS-1:0];
  wire [NUM_CONSUMERS-1:0] consumer_write_ready;
  
  // outputs from controller to memory
  wire [NUM_CHANNELS-1:0] mem_read_valid;
  wire [ADDR_BITS-1:0] mem_read_address [NUM_CHANNELS-1:0];
  wire [NUM_CHANNELS-1:0] mem_write_valid;
  wire [ADDR_BITS-1:0] mem_write_address [NUM_CHANNELS-1:0];
  wire [DATA_BITS-1:0] mem_write_data [NUM_CHANNELS-1:0];
  
  // inputs to controller
  reg [NUM_CHANNELS-1:0] mem_read_ready;
  reg [DATA_BITS-1:0] mem_read_data [NUM_CHANNELS-1:0];
  reg [NUM_CHANNELS-1:0] mem_write_ready;
  
  // DUT INSTANTIATION
  controller #(
    .ADDR_BITS(ADDR_BITS),
    .DATA_BITS(DATA_BITS),
    .NUM_CONSUMERS(NUM_CONSUMERS),
    .NUM_CHANNELS(NUM_CHANNELS),
    .WRITE_ENABLE(WRITE_ENABLE)
  ) dut (
    .clk(clk),
    .reset(reset),
    .consumer_read_valid(consumer_read_valid),
    .consumer_read_address(consumer_read_address),
    .consumer_read_ready(consumer_read_ready),
    .consumer_read_data(consumer_read_data),
    .consumer_write_valid(consumer_write_valid),
    .consumer_write_address(consumer_write_address),
    .consumer_write_data(consumer_write_data),
    .consumer_write_ready(consumer_write_ready),
    .mem_read_valid(mem_read_valid),
    .mem_read_address(mem_read_address),
    .mem_read_ready(mem_read_ready),
    .mem_read_data(mem_read_data),
    .mem_write_valid(mem_write_valid),
    .mem_write_address(mem_write_address),
    .mem_write_data(mem_write_data),
    .mem_write_ready(mem_write_ready)
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
      consumer_read_valid = 4'b0000;
      consumer_write_valid = 4'b0000;
      for (int i = 0; i < NUM_CONSUMERS; i++) begin
        consumer_read_address[i] = 8'h00;
        consumer_write_address[i] = 8'h00;
        consumer_write_data[i] = 16'h0000;
      end
      mem_read_ready = 1'b0;
      mem_write_ready = 1'b0;
      for (int i = 0; i < NUM_CHANNELS; i++) begin
        mem_read_data[i] = 16'h0000;
      end
      
      repeat(3) @(posedge clk);
      reset = 0;
      @(posedge clk);
    end
  endtask
  
  task consumer_read_request(input int consumer_id, input [ADDR_BITS-1:0] addr);
    begin
      consumer_read_valid[consumer_id] = 1'b1;
      consumer_read_address[consumer_id] = addr;
    end
  endtask
  
  task consumer_write_request(input int consumer_id, input [ADDR_BITS-1:0] addr, input [DATA_BITS-1:0] data);
    begin
      consumer_write_valid[consumer_id] = 1'b1;
      consumer_write_address[consumer_id] = addr;
      consumer_write_data[consumer_id] = data;
    end
  endtask
  
  task consumer_read_release(input int consumer_id);
    begin
      consumer_read_valid[consumer_id] = 1'b0;
    end
  endtask
  
  task consumer_write_release(input int consumer_id);
    begin
      consumer_write_valid[consumer_id] = 1'b0;
    end
  endtask
  
  task memory_read_respond(input int channel_id, input [DATA_BITS-1:0] data, input int delay_cycles);
    begin
      repeat(delay_cycles) @(posedge clk);
      mem_read_data[channel_id] = data;
      mem_read_ready[channel_id] = 1;
      @(posedge clk);
      mem_read_ready[channel_id] = 0;
      mem_read_data[channel_id] = 16'h0000;
    end
  endtask
  
  task memory_write_respond(input int channel_id, input int delay_cycles);
    begin
      repeat(delay_cycles) @(posedge clk);
      mem_write_ready[channel_id] = 1;
      @(posedge clk);
      mem_write_ready[channel_id] = 0;
    end
  endtask
  
  // TEST SEQUENCE
  initial begin
    
    // TEST 0: Reset 
    do_reset();
    repeat(2) @(posedge clk);
    
    // EXPECT:
    // consumer_read_ready = 0
    // consumer_write_ready = 0
    // mem_read_valid = 0
    // mem_write_valid = 0
    // done implicitly idle
    
    
    // TEST 1: Single Consumer Read Request
    consumer_read_request(0, 8'h10);
    @(posedge clk);

    // EXPECT:
    // mem_read_valid[0] = 1
    // mem_read_address[0] = 8'h10
    // consumer_read_ready[0] = 0 (initially)
    // WHY:
    // Channel is IDLE, finds consumer 0 read request, does memory read,
    // and waits for memory response.
    
    fork
      memory_read_respond(0, 16'hABCD, 3);
    join_none
    
    wait(consumer_read_ready[0] == 1);
    @(posedge clk);
    consumer_read_release(0);
    repeat(2) @(posedge clk);

    // EXPECT:
    // consumer_read_data[0] = 16'hABCD
    // consumer_read_ready[0] pulses high then returns to 0
    // mem_read_valid returns to 0
    // WHY:
    // memory responds, controller gives data to consumer,
    // waits for consumer to release valid, then returns to IDLE.
    
    // TEST 2: one consumer write request
    consumer_write_request(1, 8'h20, 16'h5555);
    @(posedge clk);
 
    // EXPECT:
    // mem_write_valid[0] = 1
    // mem_write_address[0] = 8'h20
    // mem_write_data[0] = 16'h5555
    // consumer_write_ready[1] = 0 initially
    // WHY:
    // IDLE channel picks consumer 1 write request and waits for memory response.

   
    fork
      memory_write_respond(0, 3);
    join_none
    
    wait(consumer_write_ready[1] == 1);
    @(posedge clk);
    consumer_write_release(1);
    repeat(2) @(posedge clk);

     // EXPECT:
     // consumer_write_ready[1] pulses high then clears
     // mem_write_valid returns to 0
     // WHY:
     // memory notices write, controller notifies consumer,
     // then resets channel when consumer releases.
    
    // TEST 3: many consumers read request (0 and 2)
    consumer_read_request(0, 8'h30);
    consumer_read_request(2, 8'h40);
    @(posedge clk);

    // EXPECT:
    // mem_read_valid = 1
    // mem_read_address = 8'h30 (consumer 0 first due to lower index)
    // WHY:
    // controller scans consumers in ascending order and picks consumer 0 first.
    
    fork
      begin
        wait(mem_read_valid[0] && mem_read_address[0] == 8'h30);
        memory_read_respond(0, 16'h1111, 3);
      end
    join_none
    
    wait(consumer_read_ready[0] == 1);
    @(posedge clk);
    consumer_read_release(0);
    repeat(1) @(posedge clk);
    
    // EXPECT:
    // consumer_read_data[0] = 16'h1111
    // consumer 2 still waiting
    // WHY:
    // only one channel exists, so requests are in series

    fork
      begin
        wait(mem_read_valid[0] && mem_read_address[0] == 8'h40);
        memory_read_respond(0, 16'h2222, 3);
      end
    join_none
    
    wait(consumer_read_ready[2] == 1);
    @(posedge clk);
    consumer_read_release(2);
    repeat(2) @(posedge clk);

    // EXPECT:
    // consumer_read_data[2] = 16'h2222
    // channel returns to IDLE
    // WHY:
    // after consumer 0 finishes, consumer 2 is served.
    
    // TEST 4: all consumers read request
    consumer_read_request(0, 8'h00);
    consumer_read_request(1, 8'h04);
    consumer_read_request(2, 8'h08);
    consumer_read_request(3, 8'h0C);
    @(posedge clk);
    
    // EXPECT:
    // requests handled sequentially in order 0 , 1 , 2 , 3
    // WHY:
    
    
    for (int i = 0; i < NUM_CONSUMERS; i++) begin
      fork
        automatic int idx = i;
        begin
          wait(mem_read_valid[0]);
          memory_read_respond(0, 16'h3000 + (idx * 16'h100), 2);
        end
      join_none
      
      wait(consumer_read_ready[i] == 1);
      @(posedge clk);
      consumer_read_release(i);
      repeat(1) @(posedge clk);
    end

    // EXPECT:
    // consumer_read_data[i] = 16'h3000 + i*16'h100
    // consumer_read_ready pulses per consumer
    // WHY:
    // Each consumer is serviced individually with returned memory data.

    repeat(2) @(posedge clk);
    
    // TEST 5: Back-to-Back Read Requests (Same Consumer)
    consumer_read_request(1, 8'h50);
    @(posedge clk);
    
    // EXPECT:
    // mem_read_address = 8'h50
    // WHY:
    // Consumer 1 issues first request.    
    
    fork
      memory_read_respond(0, 16'hAAAA, 3);
    join_none
    
    wait(consumer_read_ready[1] == 1);
    @(posedge clk);
    consumer_read_release(1);
    @(posedge clk);

    // EXPECT:
    // consumer_read_data[1] = 16'hAAAA
    // channel resets
    // WHY:
    // controller returns to IDLE.
    
    consumer_read_request(1, 8'h54);
    @(posedge clk);

    // EXPECT:
    // mem_read_address = 8'h54
    // WHY:
    // same consumer gives new request after previous one is completed.
    
    fork
      memory_read_respond(0, 16'hBBBB, 3);
    join_none
    
    wait(consumer_read_ready[1] == 1);
    @(posedge clk);
    consumer_read_release(1);
    repeat(2) @(posedge clk);
    
    // EXPECT:
    // consumer_read_data[1] = 16'hBBBB
    // WHY:
    // controller correctly handles back-to-back requests
    
    // TEST 6: Mixed Read and Write Requests
    consumer_read_request(0, 8'h60);
    consumer_write_request(1, 8'h70, 16'h7777);
    @(posedge clk);

    // EXPECT:
    // read request for consumer 0 is served first
    // WHY:
    // read is checked before write in IDLE scan
    
    fork
      begin
        wait(mem_read_valid[0]);
        memory_read_respond(0, 16'h6666, 2);
      end
    join_none
    
    wait(consumer_read_ready[0] == 1);
    @(posedge clk);
    consumer_read_release(0);
    
    // EXPECT:
    // consumer_read_data[0] = 16'h6666
    // channel returns to IDLE
    // WHY:
    // read completes first.
    
    fork
      begin
        wait(mem_write_valid[0]);
        memory_write_respond(0, 2);
      end
    join_none
    
    wait(consumer_write_ready[1] == 1);
    @(posedge clk);
    consumer_write_release(1);
    repeat(2) @(posedge clk);

    // EXPECT:
    // consumer_write_ready[1] pulses
    // WHY:
    // write is served after read.
    
    // TEST 7: variable Memory delay

    consumer_read_request(0, 8'h80);
    @(posedge clk);

    // EXPECT:
    // consumer_read_ready delayed by 1 cycle
    // WHY:
    // memory responds quickly.
    fork
      memory_read_respond(0, 16'h8888, 1);
    join_none
    
    wait(consumer_read_ready[0] == 1);
    @(posedge clk);
    consumer_read_release(0);
    repeat(2) @(posedge clk);
    
    consumer_read_request(1, 8'h90);
    @(posedge clk);

    // EXPECT:
    // consumer_read_ready delayed by 5 cycles
    // WHY:
    // memory latency directly affects response timing.
    
    fork
      memory_read_respond(0, 16'h9999, 5);
    join_none
    
    wait(consumer_read_ready[1] == 1);
    @(posedge clk);
    consumer_read_release(1);
    repeat(2) @(posedge clk);
    
    consumer_read_request(2, 8'hA0);
    @(posedge clk);
    
    // EXPECT:
    // consumer_read_ready delayed by 10 cycles
    // WHY:
    // controller waits for mem_read_ready.

    
    fork
      memory_read_respond(0, 16'hAAAA, 10);
    join_none
    
    wait(consumer_read_ready[2] == 1);
    @(posedge clk);
    consumer_read_release(2);
    repeat(2) @(posedge clk);

    
    // TEST 8: Idle State remains
    repeat(20) @(posedge clk);
    
    // EXPECT:
    // all outputs remain idle and unchanged
    // WHY:
    // no requests exist, controller stays in IDLE.
    
    // TEST 9: request cancellation
    consumer_read_request(3, 8'hB0);
    @(posedge clk);
    @(posedge clk);
    consumer_read_release(3);
    
    // EXPECT:
    // No consumer_read_ready assertion
    // No mem_read_valid if cancellation happens before pickup
    // WHY:
    // consumer withdraws request before completion, controller releases channel.
    
    repeat(5) @(posedge clk);
    
    $finish;
  end
  
endmodule
