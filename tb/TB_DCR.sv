`timescale 1ns/1ns


module TB_DCR;

     reg clk;
     reg reset;

     reg device_control_write_enable;
     reg [7:0] device_control_data;
     wire [7:0] thread_count;

  // DUT INSTANTIATION

  dcr dut (
        .clk(clk),
        .reset(reset),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .thread_count(thread_count));

   //CLOCK GENERATION T = 10ns

   initial begin
     clk = 0;
     forever #5 clk = ~clk;
   end

   //TASKS
   task do_reset();
    begin
     reset = 1;
     repeat(3) @(posedge clk);
     reset = 0;
    end
   endtask

   task get_control_data(input reg [7:0] thread_config);
     begin
      device_control_data = thread_config;
      device_control_write_enable = 1;   
      @(posedge clk);
      device_control_write_enable = 0;

     end
   endtask
  
  // TESTING SEQUENCE
  initial begin
  //TEST 0: RESET
   do_reset();
  
  //EXPECTED:
  //thread_count = 8'h00

   repeat(2) @(posedge clk);
  
  //TEST 1: GET DATA
   get_control_data(8'h55);
  
  //EXPECTED:
  //thread_count = 8'h55
   
   repeat(2) @(posedge clk);

  //TEST 2: GET DATA (different value)
   get_control_data(8'h77);
  
  //EXPECTED:
  //thread_count = 8'h55
  repeat(3) @(posedge clk);
  $finish;
  end
endmodule 