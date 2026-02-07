`timescale 1ns/1ns

module TB_REGISTERS;

     reg clk;
     reg reset;
     reg enable; 

   
     reg [7:0] block_id;
     reg [2:0] core_state;

    // instruction signals
     reg [3:0] decoded_rd_address;
     reg [3:0] decoded_rs_address;
     reg [3:0] decoded_rt_address;

    // control signals
     reg decoded_reg_write_enable;
     reg [1:0] decoded_reg_input_mux;
     reg [7:0] decoded_immediate;

    // thread unit outputs
     reg [7:0] alu_out;
     reg [7:0] lsu_out;

    // registers
     wire [7:0] rs;
     wire [7:0] rt;

// DUT INSTANTIATION
  registers dut (
    .clk(clk),
    .reset(reset),
    .enable(enable), 
    .block_id(block_id),
    .core_state(core_state),

    // instruction signals
    .decoded_rd_address(decoded_rd_address),
    .decoded_rs_address(decoded_rs_address),
    .decoded_rt_address(decoded_rt_address),

    // control Signals
    .decoded_reg_write_enable(decoded_reg_write_enable),
    .decoded_reg_input_mux(decoded_reg_input_mux),
    .decoded_immediate(decoded_immediate),

    // thread unit outputs
    .alu_out(alu_out),
    .lsu_out(lsu_out),

    // registers
    .rs(rs),
    .rt(rt)
     
 );

// CLOCK GENERATION
initial begin

   clk = 0;

   forever #5 clk = ~clk;

end

// TEST 0 RESET
initial begin
        reset = 1;
        
        decoded_rd_address = 4'd2;

        decoded_rs_address = 4'd2;
        
        core_state = 3'b011; // REQUEST STATE
        
        #20;
        
        reset = 0;
        
        enable = 1;


// TEST 1 READ OPERATION
      // EXPECT rt = rs = 0
        
        decoded_rt_address = 4'd0;

        decoded_rs_address = 4'd1;
        
        core_state = 3'b011; // REQUEST STATE
        
        #10;
        
// TEST 2 WRITE OPERATION ARITHMETIC
      // EXPECT rs = 8'hA5

        
        decoded_rd_address = 4'd2;

        decoded_rs_address = 4'd2;

        decoded_reg_write_enable = 1;

        decoded_reg_input_mux = 2'b00; // ARITHMETIC

        alu_out = 8'hA5;

        core_state = 3'b110; // UPDATE STATE
        
        #10; 

        decoded_rs_address = 4'd2;

        core_state = 3'b011; // REQUEST STATE

        #10;     

// TEST 2 WRITE OPERATION MEMORY
      // EXPECT rs = 8'h55
        
        decoded_rd_address = 4'd2;

        decoded_rs_address = 4'd2;

        decoded_reg_write_enable = 1;

        decoded_reg_input_mux = 2'b01; // MEMORY

        lsu_out = 8'h55;

        core_state = 3'b110; // UPDATE STATE
        
        #10; 

        decoded_rs_address = 4'd2;

        core_state = 3'b011; // REQUEST STATE

        #10;

// TEST 2 WRITE OPERATION CONSTANT
      // EXPECT rs = 8'hFF
        
        decoded_rd_address = 4'd2;

        decoded_rs_address = 4'd2;

        decoded_reg_write_enable = 1;

        decoded_reg_input_mux = 2'b10; // CONSTANT

        decoded_immediate = 8'hFF;

        core_state = 3'b110; // UPDATE STATE
        
        #10; 

        decoded_rs_address = 4'd2;

        core_state = 3'b011; // REQUEST STATE

        #10;

// TEST 3 ASSURING THAT THERE ARE NO WRITES TO (R13,R14,R15)
      // EXPECT rs = 8'h55
        
        block_id = 8'h55;

        decoded_rd_address = 4'd13;

        decoded_rs_address = 4'd13;

        decoded_reg_write_enable = 1;

        decoded_reg_input_mux = 2'b10; // CONSTANT

        decoded_immediate = 8'hFF;

        core_state = 3'b110; // UPDATE STATE
 
        enable = 1;
        
        #10; 

        decoded_rs_address = 4'd13;

        core_state = 3'b011; // REQUEST STATE
     
        enable = 1;

        @(posedge clk);

        #10;

// TEST 4 block_id UPDATES ONLY WHEN enable = 1
      // EXPECT rs = 8'h77
        
        block_id = 8'h77;

        decoded_rs_address = 4'd13;

        core_state = 3'b011; // REQUEST STATE
 
        enable = 1;

        @(posedge clk);
        
        #20;
        
        block_id = 8'h88;

        decoded_rs_address = 4'd13;

        core_state = 3'b011; // REQUEST STATE
 
        enable = 0;

        @(posedge clk);
        
        #10;

// TEST 5 
      // EXPECT rs = 8'h07

        enable = 0;
        
        decoded_rd_address = 4'd2;

        decoded_rs_address = 4'd2;

        decoded_reg_write_enable = 1;

        decoded_reg_input_mux = 2'b00; // ARITHMETIC

        alu_out = 8'h07;

        core_state = 3'b110; // UPDATE STATE
        
        #10; 

        decoded_rs_address = 4'd2;

        core_state = 3'b011; // REQUEST STATE

        #20; 

// FINISH SIMULATION

$finish;

end

endmodule;
