`default_nettype none
`timescale 1ns/1ns
// > Manages the entire control flow of a single compute core processing 1 block
// 1. FETCH - Retrieve instruction at current program counter (PC) from program memory
// 2. DECODE - Decode the instruction into the relevant control signals
// 3. REQUEST - If we have an instruction that accesses memory, trigger the async memory requests from LSUs
// 4. WAIT - Wait for all async memory requests to resolve (if applicable)
// 5. EXECUTE - Execute computations on retrieved data from registers / memory
// 6. UPDATE - Update register values (including NZP register) and program counter
// > Each core has it's own scheduler where multiple threads can be processed with
//   the same control flow at once.
// > Technically, different instructions can branch to different PCs, requiring "branch divergence." In
//   this minimal implementation, we assume no branch divergence (naive approach for simplicity)
module scheduler #(
    parameter THREADS_PER_BLOCK = 4
) (
    input wire clk,
    input wire reset,
    input wire start,
    
    // Control Signals
    // Changed 'input reg' to 'input logic' (Standard SystemVerilog)
    input wire decoded_mem_read_enable,
    input wire decoded_mem_write_enable,
    input wire decoded_ret,

    // Memory Access State
    input wire [2:0] fetcher_state,
    input wire [1:0] lsu_state [THREADS_PER_BLOCK-1:0],

    // Current & Next PC
    output logic [7:0] current_pc, // 'output logic' is preferred over 'output reg'
    input wire [7:0] next_pc [THREADS_PER_BLOCK-1:0],

    // Execution State
    output logic [2:0] core_state,
    output logic done
);
    // State Encoding
    localparam IDLE = 3'b000,
               FETCH = 3'b001,
               DECODE = 3'b010,
               REQUEST = 3'b011,
               WAIT = 3'b100,
               EXECUTE = 3'b101,
               UPDATE = 3'b110,
               DONE = 3'b111;
    
    // Internal variable for WAIT logic
    logic any_lsu_waiting; 

    always_ff @(posedge clk) begin 
        if (reset) begin
            current_pc <= 0;
            core_state <= IDLE;
            done <= 0;
        end else begin 
            case (core_state)
                IDLE: begin
                    if (start) begin 
                        core_state <= FETCH;
                    end
                end

                FETCH: begin 
                    if (fetcher_state == 3'b010) begin // Assuming 3'b010 is FETCHED
                        core_state <= DECODE;
                    end
                end

                DECODE: begin
                    core_state <= REQUEST;
                end

                REQUEST: begin 
                    core_state <= WAIT;
                end

                WAIT: begin
                    // 1. Initialize to 0 every cycle (Fixes implicit static error)
                    any_lsu_waiting = 1'b0;

                    // 2. Check all threads
                    for (int i = 0; i < THREADS_PER_BLOCK; i++) begin
                        // Check if state is REQUESTING (01) or WAITING (10)
                        if (lsu_state[i] == 2'b01 || lsu_state[i] == 2'b10) begin
                            any_lsu_waiting = 1'b1;
                        end
                    end

                    // 3. Transition only if no one is waiting
                    if (any_lsu_waiting == 1'b0) begin
                        core_state <= EXECUTE;
                    end
                end

                EXECUTE: begin
                    core_state <= UPDATE;
                end

                UPDATE: begin 
                    if (decoded_ret) begin 
                        done <= 1;
                        core_state <= DONE;
                    end else begin 
                        current_pc <= next_pc[THREADS_PER_BLOCK-1]; // Naive convergence
                        core_state <= FETCH;
                    end
                end

                DONE: begin 
                    // no-op
                end
                
                default: core_state <= IDLE;
            endcase
        end
    end

endmodule
