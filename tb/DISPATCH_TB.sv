`timescale 1ns/1ns

module TB_DISPATCH;

    localparam NUM_CORES = 2;
    localparam THREADS_PER_BLOCK = 4;

    logic clk;
    logic reset;
    logic start;

    // INPUTS
   
    logic [7:0] thread_count;
    logic [NUM_CORES-1:0] core_done;

    // OUTPUTS
    
    logic [NUM_CORES-1:0] core_start;
    logic [NUM_CORES-1:0] core_reset;
    logic [7:0] core_block_id [NUM_CORES-1:0];
    logic [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0];
    logic done;

    // DUT INSTANTIATION
    
    dispatch #(.NUM_CORES(NUM_CORES),.THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dut (
        .clk,
        .reset,
        .start,
        .thread_count,
        .core_done,
        .core_start,
        .core_reset,
        .core_block_id,
        .core_thread_count,
        .done
    );

    // CLOCK GENERATION (10ns period)
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // TASKS

    // Reset
    task do_reset;
        begin
            reset = 1;
            start = 0;
            core_done = 0;
            thread_count = 0;
            @(posedge clk);
            @(posedge clk);
            reset = 0;
        end
    endtask

    // Start a kernel
    task start_kernel(input [7:0] threads);
        begin
            thread_count = threads;
            start = 1;
            @(posedge clk);
        end
    endtask

    // Simulate a core finishing execution
    task finish_core(input integer core_id);
        begin
            if (core_id == 0)
             core_done = 2'b01;

            else if (core_id == 1)
             core_done = 2'b10;
    
             @(posedge clk);
             core_done = 2'b00;
        end
    endtask

    
    // TEST SEQUENCE
    
    initial begin

        // TEST 0 : RESET
       
        do_reset();

        // EXPECT:
        // done = 0
        // core_start = 0
        // core_reset = 1 (then cleared)
        // blocks_dispatched = 0 internally

        // TEST : START KERNEL
        
        // Choosen 6 threads:
        // THREADS_PER_BLOCK = 4
        // total_blocks = 2
        start_kernel(8'd6);

        // EXPECT:
        // core 0:
        //   block_id = 0
        //   thread_count = 4
        // core 1:
        //   block_id = 1
        //   thread_count = 2

        // Let dispatcher assign blocks
        repeat (3) @(posedge clk);

        // TEST 2 CORE 0 FINISHES
        
        finish_core(0);

        // EXPECT:
        // blocks_done increments
        // core 0 reset
        // no new blocks (only 2 total)

        repeat (2) @(posedge clk);

        // TEST 3  CORE  FINISHES
        
        finish_core(1);

        // EXPECT:
        // blocks_done == total_blocks
        // done = 1

        repeat (3) @(posedge clk);

        
        $finish;
    end
endmodule
 