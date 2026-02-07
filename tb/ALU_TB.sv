`timescale 1ns/1ns
`default_nettype none

module tb_alu;

    // Inputs 
    reg clk;
    reg reset;
    reg enable;
    
    reg [2:0] core_state;
    reg [1:0] decoded_alu_arithmetic_mux;
    reg decoded_alu_output_mux;
    reg [7:0] rs;
    reg [7:0] rt;
    
    // Output 
    wire [7:0] alu_out;
    
    // Instantiate 
    alu dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .core_state(core_state),
        .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux),
        .decoded_alu_output_mux(decoded_alu_output_mux),
        .rs(rs),
        .rt(rt),
        .alu_out(alu_out)
    );
    
    // Clock d
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Stimulus
    initial begin
        // Initialize Inputs
        reset = 1;
        enable = 0;
        core_state = 3'b000;
        decoded_alu_arithmetic_mux = 2'b00;
        decoded_alu_output_mux = 0;
        rs = 0;
        rt = 0;
        
        #20;
        reset = 0;
        enable = 1;
        core_state = 3'b101;  // EXECUTE state
        
        // Test 1: ADD operation (rs=10, rt=20)
        decoded_alu_output_mux = 0; // Select arithmetic output
        decoded_alu_arithmetic_mux = 2'b00; // ADD
        rs = 8'd10;
        rt = 8'd20;                         //expect 30
        #10;
        
        // Test 2: SUB operation (rs=50, rt=15)
        decoded_alu_arithmetic_mux = 2'b01; // SUB
        rs = 8'd50;
        rt = 8'd15;
        #10;                                 //expect 35
        
        // Test 3: MUL operation (rs=7, rt=6)
        decoded_alu_arithmetic_mux = 2'b10; // MUL
        rs = 8'd7;
        rt = 8'd6;
        #10;                                //expect 42
        
        // Test 4: DIV operation (rs=30, rt=5)
        decoded_alu_arithmetic_mux = 2'b11; // DIV
        rs = 8'd30;
        rt = 8'd5;
        #10;                               //expect 6
       
        // Test 5: Comparison output (rs=15, rt=10) => (N=0,Z=0,P=1)
        decoded_alu_output_mux = 1; // Select comparison output
        rs = 8'd15;
        rt = 8'd10;
        #10;
     
                 
        // Test 6: Comparison output (rs=5, rt=5) => (N=0,Z=1,P=0)
        rs = 8'd5;
        rt = 8'd5;
        #10;
                 
        // Test 7: Comparison output (rs=3, rt=7) => (N=1,Z=0,P=0)
        rs = 8'd3;
        rt = 8'd7;

   
     

    end

endmodule
       
   




















