`default_nettype none
`timescale 1ns/1ns
// ARITHMETIC-LOGIC UNIT
// > Executes computations on register values
// > In this minimal implementation, the ALU supports the 4 basic arithmetic operations
// > Each thread in each core has it's own ALU
// > ADD, SUB, MUL, DIV instructions are all executed here
module alu (
    input wire clk,
    input wire reset,
    input wire enable,  // If current block has less threads then block size, some ALUs will be inactive

    input wire [2:0] core_state,                    // Changed from 'input reg' to 'input wire'
    input wire [1:0] decoded_alu_arithmetic_mux,    // Changed from 'input reg' to 'input wire'
    input wire decoded_alu_output_mux,              // Changed from 'input reg' to 'input wire'
    input wire [7:0] rs,                            // Changed from 'input reg' to 'input wire'
    input wire [7:0] rt,                            // Changed from 'input reg' to 'input wire'
    output reg [7:0] alu_out
);
    localparam ADD = 2'b00,
        SUB = 2'b01,
        MUL = 2'b10,
        DIV = 2'b11;
    
    always @(posedge clk) begin 
        if (reset) begin 
            alu_out <= 8'b0;
        end else if (enable) begin
            if (core_state == 3'b101) begin 
                if (decoded_alu_output_mux == 1) begin 
                    alu_out <= {5'b0, (rs - rt > 0), (rs - rt == 0), (rs - rt < 0)};
                end else begin 
                    case (decoded_alu_arithmetic_mux)
                        ADD: alu_out <= rs + rt;
                        SUB: alu_out <= rs - rt;
                        MUL: alu_out <= rs * rt;
                        DIV: alu_out <= rs / rt;
                    endcase
                end
            end
        end
    end
endmodule
