`timescale 1ns/1ns
`default_nettype none

module lsu_tb;

    reg clk;
    reg reset;
    reg enable;
	//inp
    reg [2:0] core_state;
    reg decoded_mem_read_enable;
    reg decoded_mem_write_enable;

    reg [7:0] rs;
    reg [7:0] rt;

    reg        mem_read_ready;
    reg [7:0]  mem_read_data;
    reg        mem_write_ready;
	//out
    wire       mem_read_valid;
    wire [7:0] mem_read_address;
    wire       mem_write_valid;
    wire [7:0] mem_write_address;
    wire [7:0] mem_write_data;

    wire [1:0] lsu_state;
    wire [7:0] lsu_out;

    lsu dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .core_state(core_state),
        .decoded_mem_read_enable(decoded_mem_read_enable),
        .decoded_mem_write_enable(decoded_mem_write_enable),
        .rs(rs),
        .rt(rt),
        .mem_read_valid(mem_read_valid),
        .mem_read_address(mem_read_address),
        .mem_read_ready(mem_read_ready),
        .mem_read_data(mem_read_data),
        .mem_write_valid(mem_write_valid),
        .mem_write_address(mem_write_address),
        .mem_write_data(mem_write_data),
        .mem_write_ready(mem_write_ready),
        .lsu_state(lsu_state),
        .lsu_out(lsu_out)
    );


    //clk
    initial clk = 0;
    always #5 clk = ~clk; 
 
    task apply_reset;
    begin
        reset = 1;
        enable = 0;
        core_state = 0;
        decoded_mem_read_enable = 0;
        decoded_mem_write_enable = 0;

        mem_read_ready = 0;
        mem_write_ready = 0;
        mem_read_data = 0;

        rs = 0;
        rt = 0;

        repeat (2) @(posedge clk);
        reset = 0;
        enable = 1;
    end
    endtask

       //load_op
    task do_load(input [7:0] address, input [7:0] return_value, input integer delay_cycles);
    begin
        // Configure LSU
        rs = address;
        decoded_mem_read_enable = 1;
        decoded_mem_write_enable = 0;

        core_state = 3'b011;   // REQUEST

        @(posedge clk);
        // WAITING  (memory not ready)
        core_state = 3'b011;
        mem_read_ready = 0;

        repeat (delay_cycles) @(posedge clk);
        // Memory responds
        mem_read_data = return_value;
        mem_read_ready = 1;

        @(posedge clk);
        // End
        mem_read_ready = 0;
        // Tell LSU to finish
        core_state = 3'b110;   // UPDATE

        @(posedge clk);
        decoded_mem_read_enable = 0;
    end
    endtask

     //store_op
    task do_store(input [7:0] address, input [7:0] data, input integer delay_cycles);
    begin
        rs = address;
        rt = data;

        decoded_mem_write_enable = 1;
        decoded_mem_read_enable = 0;

        // REQUEST
        core_state = 3'b011;

        @(posedge clk);
        // WAITING
        mem_write_ready = 0;

        repeat (delay_cycles) @(posedge clk);
        // Memory acknowledges
        mem_write_ready = 1;

        @(posedge clk);
        mem_write_ready = 0;
        core_state = 3'b110; //update

        @(posedge clk);
        decoded_mem_write_enable = 0;

    end
    endtask


  //test sequences 
    initial begin
        apply_reset;  //expect all 00

        // TEST 1: Simple LOAD with 2-cycle delay
        do_load(8'h10, 8'hAA, 2);// expect , mem_read_v=1 after 1 cycle, mem_read_r=1 after 2 cycles,
				//  data=AAh, mem_writ_V=0, write_add=0, data_write=0,
				// lsu_out=AAh
        // TEST 2: Simple STORE with 1-cycle delay
        do_store(8'h20, 8'h55, 1); // expect: mem_write_v=1 after 1 cycle, mem_write_r=1 after 1 cycle,
				 // write_add=20h, data_write=55h, mem_read_V=0, // lsu_out=00h (or previous value)

        // TEST 3: LOAD with long memory stall
        do_load(8'h30, 8'hF3, 5); // expect: mem_read_v=1 after 1 cycle, mem_read_r=1 after 5 cycles,
				 // read_add=30h, data=F3h, mem_writ_V=0, // lsu_out=F3h after stall clears

        // TEST 4: STORE with long stall
        do_store(8'h40, 8'h77, 4); // expect: mem_write_v=1 after 1 cycle, mem_write_r=1 after 4 cycles,
				 // write_add=40h, data_write=77h, mem_read_V=0, // lsu_out stays unchanged

        // TEST 5: Back-to-back LOAD ? STORE
        do_load(8'h50, 8'h12, 0);
        do_store(8'h60, 8'h34, 0); // expect: mem_read_v and mem_read_r high simultaneously (0-cycle delay), 
				// followed immediately by mem_write_v and mem_write_r high. // lsu_out=12h, then transitions for store.

        // TEST 6: Reset during WAITING
        decoded_mem_read_enable = 1;
        rs = 8'h70;
        core_state = 3'b011;

        @(posedge clk);
        mem_read_ready = 0;

        @(posedge clk);
        //reset mid-operation
        reset = 1;
        @(posedge clk);
        reset = 0;
        enable = 1;
        decoded_mem_read_enable = 0; // expect: core_state=3'b011 and mem_read_v=1. Upon reset=1, 
				// lsu_state should return to IDLE (00), mem_read_v=0, // and all output registers/lsu_out should clear to 00h
        repeat (10) @(posedge clk);
    end

endmodule

