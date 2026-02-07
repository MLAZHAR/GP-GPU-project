`timescale 1ns/1ns
`default_nettype none

module tb_pc;


    localparam DATA_BITS  = 8;
    localparam ADDR_BITS  = 8;

   
    bit clk;
    logic reset;
    logic enable;

    logic  [2:0] core_state;
    logic  [2:0] decoded_nzp;
    logic  [DATA_BITS-1:0] decoded_immediate;
    logic  decoded_nzp_write_enable;
    logic  decoded_pc_mux;
    logic  [DATA_BITS-1:0] alu_out;

    logic [ADDR_BITS-1:0] current_pc;
    logic [ADDR_BITS-1:0] next_pc;

    
    pc #(
        .DATA_MEM_DATA_BITS(DATA_BITS),
        .PROGRAM_MEM_ADDR_BITS(ADDR_BITS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .core_state(core_state),
        .decoded_nzp(decoded_nzp),
        .decoded_immediate(decoded_immediate),
        .decoded_nzp_write_enable(decoded_nzp_write_enable),
        .decoded_pc_mux(decoded_pc_mux),
        .alu_out(alu_out),
        .current_pc(current_pc),
        .next_pc(next_pc)
    );

 
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    
    initial begin
        // initializing inputs
        reset = 1;
        enable = 1;

        core_state = 3'b000;
        decoded_nzp = 3'b000;
        decoded_immediate = 0;
        decoded_nzp_write_enable = 0;
        decoded_pc_mux = 0;
        alu_out = 0;
        current_pc = 0;

        #15;
        reset = 0;

        // TEST 1: normal PC + 1 update
    
        core_state = 3'b101;      // EXECUTE 
        current_pc = 8'd10;
        decoded_pc_mux = 0;       
        #10;

        // EXPECT: next_pc = 11

              // TEST 2: NZP write during UPDATE state
 
        core_state = 3'b110;       // UPDATE
        decoded_nzp_write_enable = 1;
        alu_out = 3'b101;          
        #10;

        decoded_nzp_write_enable = 0;

        // TEST 3: branch taken (decoded_pc_mux = 1 AND NZP matches)
        core_state = 3'b101;        // EXECUTE
        decoded_pc_mux = 1;         // enable branch logic
        decoded_nzp = 3'b100;       // looking for "positive" flag
        decoded_immediate = 8'd50;  // branch target
        current_pc = 8'd20;
        #10;

        // EXPECT: next_pc = 50  (branch taken)

        // TEST 4: branch NOT taken

        decoded_nzp = 3'b001;       // branch when negative
        #10;

        // EXPECT: next_pc = current_pc + 1 = 21

        #30;
    end

endmodule

