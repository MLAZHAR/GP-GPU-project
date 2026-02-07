`timescale 1ns/1ns

module scheduler_tb;

    parameter THREADS_PER_BLOCK = 4;
    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg reset;
    reg start;
    
    // control signals  as inp
    reg decoded_mem_read_enable;
    reg decoded_mem_write_enable;
    reg decoded_ret;
    
    // memory access state as inp
    reg [2:0] fetcher_state;
    reg [1:0] lsu_state [THREADS_PER_BLOCK-1:0];
    
    wire [7:0] current_pc;
    reg [7:0] next_pc [THREADS_PER_BLOCK-1:0];
    
    // execution state as out
    wire [2:0] core_state;
    wire done;
    
    // state definitions like DUT
    localparam IDLE = 3'b000;
    localparam FETCH = 3'b001;
    localparam DECODE = 3'b010;
    localparam REQUEST = 3'b011;
    localparam WAIT = 3'b100;
    localparam EXECUTE = 3'b101;
    localparam UPDATE = 3'b110;
    localparam DONE = 3'b111;
    
    // LSU state 
    localparam LSU_IDLE = 2'b00;
    localparam LSU_REQUESTING = 2'b01;
    localparam LSU_WAITING = 2'b10;
    localparam LSU_READY = 2'b11;
    
    // DUT instantiation
    scheduler #(
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .decoded_mem_read_enable(decoded_mem_read_enable),
        .decoded_mem_write_enable(decoded_mem_write_enable),
        .decoded_ret(decoded_ret),
        .fetcher_state(fetcher_state),
        .lsu_state(lsu_state),
        .current_pc(current_pc),
        .next_pc(next_pc),
        .core_state(core_state),
        .done(done)
    );
    
    // clk 
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // TASK: init all signals
    task automatic init_signals();
        begin
            reset = 1;
            start = 0;
            decoded_mem_read_enable = 0;
            decoded_mem_write_enable = 0;
            decoded_ret = 0;
            fetcher_state = 3'b000;
            
            // init all LSU states to IDLE
            for (int i = 0; i < THREADS_PER_BLOCK; i++) begin
                lsu_state[i] = LSU_IDLE;
                next_pc[i] = 8'h00;
            end
        end
    endtask
  
    // TASK: reset 
    task automatic apply_reset();
        begin
            reset = 1;
            @(posedge clk);
            @(posedge clk);
            reset = 0;
            @(posedge clk);
        end
    endtask
    
    // TASK: Wait for specific state to synchronizes testbench with DUT state transitions.
    task automatic wait_for_state(input [2:0] expected_state);
        begin
            int timeout_counter = 0;
            while (core_state !== expected_state) begin
                @(posedge clk);
                timeout_counter++;
                if (timeout_counter > 100) begin
                    $display("[%0t] ERROR: Timeout waiting for state %s, stuck in %s", 
                             $time, get_state_name(expected_state), get_state_name(core_state));// debug 
                    $finish;
                end
            end
            
            $display("[%0t] WAIT_STATE: Reached state %s", $time, get_state_name(expected_state));
        end
    endtask
   
    // TASK: simulate fetcher using fork-join_none(background op)
    task automatic simulate_fetcher(input int fetch_latency);
        begin
            fork
                begin
                    forever begin
                        @(posedge clk);
                        if (core_state == FETCH) begin
                            $display("[%0t] FETCHER: FETCH state detected, starting fetch with %0d cycle latency", 
                                     $time, fetch_latency);
                            fetcher_state = 3'b001; // fetching
                            repeat(fetch_latency) @(posedge clk);
                            fetcher_state = 3'b010; // FETCHED
                            $display("[%0t] FETCHER: Fetch complete, setting fetcher_state=3'b010", $time);
                            wait(core_state != FETCH); // Wait until state changes
                            fetcher_state = 3'b000; // Reset to idle
                            $display("[%0t] FETCHER: Fetch cycle complete, resetting fetcher_state", $time);
                        end
                    end
                end
            join_none
        end
    endtask
    

    // TASK: simulate single LSU memory access
    task automatic simulate_lsu_access(
        input int thread_id,
        input int memory_latency
    );
        begin
            $display("[%0t] LSU[%0d]: Starting memory access (latency=%0d cycles)", 
                     $time, thread_id, memory_latency);
            
            // REQUESTING state
            lsu_state[thread_id] = LSU_REQUESTING;
            $display("[%0t] LSU[%0d]: State = REQUESTING (2'b01)", $time, thread_id);
            @(posedge clk);
            
            // WAITING state for specified latency
            lsu_state[thread_id] = LSU_WAITING;
            $display("[%0t] LSU[%0d]: State = WAITING (2'b10)", $time, thread_id);
            repeat(memory_latency - 1) @(posedge clk);
            
            // Return to IDLE (data ready)
            lsu_state[thread_id] = LSU_IDLE;
            $display("[%0t] LSU[%0d]: Memory access complete, State = IDLE (2'b00)", 
                     $time, thread_id);
        end
    endtask
    

    // TASK: Set next PC values (for all threads)
    task automatic set_next_pc(input [7:0] pc_value);
        begin
            $display("[%0t] SET_NEXT_PC: Setting all next_pc to 0x%02h", $time, pc_value);//debug 
            
            for (int i = 0; i < THREADS_PER_BLOCK; i++) begin
                next_pc[i] = pc_value;
            end
            
            // Verify the assignment
            $display("[%0t] SET_NEXT_PC: Verification - next_pc[0]=0x%02h, next_pc[1]=0x%02h, next_pc[2]=0x%02h, next_pc[3]=0x%02h", 
                     $time, next_pc[0], next_pc[1], next_pc[2], next_pc[3]); // expected to get all same pc 
        end
    endtask
    
    // TASK: execute one complete instruction cycle (FETCH -> UPDATE)
    task automatic execute_instruction(
        input bit has_memory_access,
        input int memory_latency,
        input int thread_id_with_mem,
        input bit is_ret_instruction
    );
        begin
            $display("\n");
            $display("[%0t] EXECUTE_INST: Starting instruction at PC=0x%02h", $time, current_pc);      
            // Debug: Print input parameters 
            $display("[%0t] EXECUTE_INST: Parameters:", $time);
            $display("                   has_memory_access  = %b", has_memory_access);
            $display("                   memory_latency     = %0d", memory_latency);
            $display("                   thread_id_with_mem = %0d", thread_id_with_mem);
            $display("                   is_ret_instruction = %b", is_ret_instruction);
            
            // Set decoded signals
            decoded_ret = is_ret_instruction;
            decoded_mem_read_enable = has_memory_access;
            decoded_mem_write_enable = 0;
            
            $display("[%0t] EXECUTE_INST: Set decoded_ret=%b, decoded_mem_read_enable=%b", 
                     $time, decoded_ret, decoded_mem_read_enable);
            
            // Assert start if in IDLE
            if (core_state == IDLE) begin
                $display("[%0t] EXECUTE_INST: Core in IDLE state, asserting start", $time);
                start = 1;
                @(posedge clk);
                start = 0;
                $display("[%0t] EXECUTE_INST: start asserted and deasserted", $time);
            end else begin
                $display("[%0t] EXECUTE_INST: Core not in IDLE (state=%s), skipping start", 
                         $time, get_state_name(core_state));
            end
            
            // FETCH -> DECODE (fetcher task handles this automatically)
            $display("[%0t] EXECUTE_INST: Waiting for DECODE state...", $time);
            wait_for_state(DECODE);
            
            // DECODE -> REQUEST (1 cycle)
            $display("[%0t] EXECUTE_INST: in DECODE state, advancing to REQUEST", $time);
            @(posedge clk);
            $display("[%0t] EXECUTE_INST: now in %s state", $time, get_state_name(core_state));//debug
            
            // REQUEST -> WAIT
            if (has_memory_access) begin
                $display("[%0t] EXECUTE_INST: Memory access needed, launching LSU task for thread %0d", 
                         $time, thread_id_with_mem);
                fork
                    simulate_lsu_access(thread_id_with_mem, memory_latency);
                join_none
            end else begin
                $display("[%0t] EXECUTE_INST: No memory access needed", $time);
            end
            
            @(posedge clk);
            $display("[%0t] EXECUTE_INST: now in %s state", $time, get_state_name(core_state));
            
            // WAIT -> EXECUTE
            $display("[%0t] EXECUTE_INST: Waiting for EXECUTE state...", $time);
            wait_for_state(EXECUTE);
            
            // *the problm: set next_pc DURING EXECUTE state ***
            $display("[%0t] EXECUTE_INST: In EXECUTE state, checking if we should set next_pc", $time);
            $display("[%0t] EXECUTE_INST: is_ret_instruction = %b", $time, is_ret_instruction);
            $display("[%0t] EXECUTE_INST: !is_ret_instruction = %b", $time, !is_ret_instruction);
            
            if (!is_ret_instruction) begin
                $display("[%0t] EXECUTE_INST: not a RET instruction, setting next_pc", $time);
                $display("[%0t] EXECUTE_INST: Current PC = 0x%02h, will set next_pc to 0x%02h", 
                         $time, current_pc, current_pc + 8'h01);
                
                set_next_pc(current_pc + 8'h01);// expecting to work   facing huge problem of pc increment 
                
                // Verify
                $display("[%0t] EXECUTE_INST:   next_pc[0] = 0x%02h", $time, next_pc[0]);
                $display("[%0t] EXECUTE_INST:   next_pc[1] = 0x%02h", $time, next_pc[1]);
                $display("[%0t] EXECUTE_INST:   next_pc[2] = 0x%02h", $time, next_pc[2]);
                $display("[%0t] EXECUTE_INST:   next_pc[3] = 0x%02h", $time, next_pc[3]);
            end else begin
                $display("[%0t] EXECUTE_INST: RET instruction detected, NOT setting next_pc", $time);
            end
            
            // EXECUTE -> UPDATE (1 cycle)
            $display("[%0t] EXECUTE_INST: Advancing from EXECUTE to UPDATE", $time);
            @(posedge clk);
            $display("[%0t] EXECUTE_INST: Now in %s state", $time, get_state_name(core_state));
            
            // Wait for UPDATE to complete
            $display("[%0t] EXECUTE_INST: UPDATE state active, waiting for completion...", $time);
            @(posedge clk);
            
            $display("[%0t] EXECUTE_INST: UPDATE complete, now in %s state", 
                     $time, get_state_name(core_state));
            $display("[%0t] EXECUTE_INST: current_pc after UPDATE = 0x%02h", $time, current_pc);
            $display("[%0t] EXECUTE_INST: done signal = %b", $time, done);
            
            if (is_ret_instruction) begin
                $display("[%0t] EXECUTE_INST: *** RET instruction executed - Block done ***", $time);
            end else begin
                $display("[%0t] EXECUTE_INST: *** Instruction complete - PC updated to 0x%02h ***", 
                         $time, current_pc);
            end
        end
    endtask
    

    // TASK: check expected state and PC
    task automatic check_state_and_pc(
        input [2:0] expected_state,
        input [7:0] expected_pc
    );
        begin
            $display("[%0t] CHECK: state and PC", $time);
            
            if (core_state !== expected_state) begin
                $display("[%0t] CHECK: *** ERROR *** Expected state=%s, got=%s", 
                         $time, get_state_name(expected_state), //debug
                         get_state_name(core_state));
            end else begin
                $display("[%0t] CHECK: PASS - State is %s", $time, 
                         get_state_name(expected_state));
            end
            
            if (current_pc !== expected_pc) begin
                $display("[%0t] CHECK: *** ERROR *** Expected PC=0x%02h, got=0x%02h", 
                         $time, expected_pc, current_pc);
            end else begin
                $display("[%0t] CHECK: PASS - PC is 0x%02h", $time, current_pc);
            end
        end
    endtask
    
    // FUNCTION: Get state name for display
    function string get_state_name(input [2:0] state);
        case (state)
            IDLE:    return "IDLE";
            FETCH:   return "FETCH";
            DECODE:  return "DECODE";
            REQUEST: return "REQUEST";
            WAIT:    return "WAIT";
            EXECUTE: return "EXECUTE";
            UPDATE:  return "UPDATE";
            DONE:    return "DONE";
            default: return "UNKNOWN";
        endcase
    endfunction
    

    // TEST SCENARIO 1: Basic Sequential Execution (No Memory Access)
    task automatic test_sequential_execution();
        begin
            $display("\n\n");
            $display("// TEST 1: BASIC SEQUENTIAL EXECUTION (NO MEMORY ACCESS)");     
            init_signals();
            apply_reset();
            
            // Verify initial state
            $display("[%0t] TEST1: Verifying initial conditions", $time);
            $display("[%0t] TEST1:   core_state = %s", $time, get_state_name(core_state));
            $display("[%0t] TEST1:   current_pc = 0x%02h", $time, current_pc);
            $display("[%0t] TEST1:   done = %b", $time, done);
            
            // Start fetcher simulation (1 cycle latency)
            simulate_fetcher(1);//background
            
            // Execute 5 instructions sequentially
            for (int i = 0; i < 5; i++) begin
                $display("\n");
                $display("[%0t] TEST1: *** ITERATION %0d - Starting instruction at PC=0x%02h ***", 
                         $time, i, current_pc);
                
                execute_instruction(
                    .has_memory_access(1'b0),
                    .memory_latency(0),
                    .thread_id_with_mem(0),
                    .is_ret_instruction(1'b0)
                );
                
                // Verify PC incremented correctly 
                if (current_pc !== (i + 1)) begin
                    $display("[%0t] TEST1: *** ERROR *** PC should be %0d (0x%02h), got %0d (0x%02h)", 
                             $time, i+1, i+1, current_pc, current_pc);
                    $finish;
                end else begin
                    $display("[%0t] TEST1: PASS - PC correctly updated to %0d (0x%02h)", 
                             $time, current_pc, current_pc);//expected 
                end
            end
            
            $display("\n");
            $display(" TEST1: done");
            #(CLK_PERIOD * 5);
        end
    endtask
    

    // TEST SCENARIO 2: Memory Access with Wait
    task automatic test_memory_access();
        begin
            $display("\n\n");
            $display("// TEST 2: MEMORY ACCESS WITH WAIT");
            
            init_signals();
            apply_reset();
            
            simulate_fetcher(1);
            
            // Inst 1: No memory access
            $display("\n[%0t] TEST2: Instruction 1 - No memory access", $time);
            execute_instruction(
                .has_memory_access(1'b0),
                .memory_latency(0),
                .thread_id_with_mem(0),
                .is_ret_instruction(1'b0)
            );
            
            // Inst 2: Thread 0 accesses memory (5 cycle latency)
            $display("\n[%0t] TEST2: Instruction 2 - Thread 0 memory access (5 cycles)", $time);
            execute_instruction(
                .has_memory_access(1'b1),
                .memory_latency(5),
                .thread_id_with_mem(0),
                .is_ret_instruction(1'b0)
            );
            
            // Instruction 3: Thread 2 accesses memory (3 cycle latency)
            $display("\n[%0t] TEST2: Instruction 3 - Thread 2 memory access (3 cycles)", $time);
            execute_instruction(
                .has_memory_access(1'b1),
                .memory_latency(3),
                .thread_id_with_mem(2),
                .is_ret_instruction(1'b0)
            );
            
            $display("\n TEST2: dome");
            #(CLK_PERIOD * 5);
        end
    endtask
    
    // TEST SCENARIO 3: Multiple Threads with Memory Access
    task automatic test_multiple_thread_memory();
        begin
            $display("\n\n");
            $display("// TEST 3: MULTIPLE THREADS ACCESS MEMORY");
            
            init_signals();
            apply_reset();
            
            simulate_fetcher(1);
            
            // Execute one normal instruction first
            execute_instruction(
                .has_memory_access(1'b0),
                .memory_latency(0),
                .thread_id_with_mem(0),
                .is_ret_instruction(1'b0)
            );
            
            // Execute instruction where multiple threads access memory
            $display("\n[%0t] TEST3: Starting multi-thread memory instruction", $time);
            
            decoded_ret = 0;
            decoded_mem_read_enable = 1;
            
            start = 1;
            @(posedge clk);
            start = 0;
            
            wait_for_state(DECODE);
            @(posedge clk);
            
            // In REQUEST state, trigger multiple LSU accesses with different latencies
            $display("[%0t] TEST3: lsu access is happening ", $time);
            fork
                simulate_lsu_access(0, 3);  // Thread 0: 3 cycles
                simulate_lsu_access(1, 5);  // Thread 1: 5 cycles (last one)
                simulate_lsu_access(2, 2);  // Thread 2: 2 cycles
                simulate_lsu_access(3, 4);  // Thread 3: 4 cycles
            join_none
            
            @(posedge clk);
            
            $display("[%0t] TEST3: Entered WAIT state - waiting for all threads...", $time);
            wait_for_state(EXECUTE);
            $display("[%0t] TEST3: All threads completed - proceeding to EXECUTE", $time);
            
            // Set next_pc and complete the instruction
            set_next_pc(current_pc + 1);
            
            @(posedge clk);
            @(posedge clk);
            
            $display("\n TEST3: DONE");
            #(CLK_PERIOD * 5);
        end
    endtask
    
    // TEST SCENARIO 4: RET Instruction (Kernel Completion)
    task automatic test_ret_instruction();
        begin
            $display("\n\n");
            $display("// TEST 4: RET INSTRUCTION & COMPLETION");
            
            init_signals();
            apply_reset();
            
            simulate_fetcher(1);
            
            // Execute 2 normal instructions
            for (int i = 0; i < 2; i++) begin
                $display("\n[%0t] TEST4: Normal instruction %0d", $time, i+1);
                execute_instruction(
                    .has_memory_access(1'b0),
                    .memory_latency(0),
                    .thread_id_with_mem(0),
                    .is_ret_instruction(1'b0)
                );
            end
            
            // Execute RET instruction
            $display("\n[%0t] TEST4: *** Executing RET instruction ***", $time);
            execute_instruction(
                .has_memory_access(1'b0),
                .memory_latency(0),
                .thread_id_with_mem(0),
                .is_ret_instruction(1'b1)
            );
            
            // Check that we're in DONE state and done=1
            @(posedge clk);
            if (core_state !== DONE) begin
                $display("[%0t] TEST4: ERROR : Expected DONE state, got %s", 
                         $time, get_state_name(core_state));
            end else begin
                $display(" TEST4: PASS ");
            end
            
            if (done !== 1) begin
                $display("[%0t] TEST4: *** ERROR *** done signal should be HIGH", $time);
            end else begin
                $display(" TEST4: PASS");
            end
            
            // Verify we stay in DONE
            $display("[%0t] TEST4: CHECK IF STAYS IN DONE STATE..", $time);
            repeat(5) begin
                @(posedge clk);
                if (core_state !== DONE) begin
                    $display("[%0t] TEST4: *** ERROR *** Should stay in DONE state, got %s", 
                             $time, get_state_name(core_state));
                end
            end
            $display(" TEST4: PASS ");
            
            $display("\n TEST4: DONE");
            #(CLK_PERIOD * 5);
        end
    endtask
    

	// TEST SCENARIO 5: Reset During Execution
	task automatic test_reset_during_execution();
   	 begin
        $display("\n\n");
        $display("// TEST 5: RESET DURING EXECUTION");
        
        init_signals();
        apply_reset();
        
        simulate_fetcher(1);
        
        // Execute one instruction normally
        $display("\n[%0t] TEST5: Executing first instruction normally", $time);
        execute_instruction(
            .has_memory_access(1'b0),
            .memory_latency(0),
            .thread_id_with_mem(0),
            .is_ret_instruction(1'b0)
        );
        
        // Start another instruction and reset mid-way
        $display("\n[%0t] TEST5: Starting second instruction...", $time);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for DECODE state
        wait_for_state(DECODE);
        
        // Verify we're in REQUEST state
        $display("\n[%0t] TEST5: i'm in: %s", $time, get_state_name(core_state));//DEBUG
        
        // Wait half a clock cycle to be in the middle of REQUEST state
        #(CLK_PERIOD/2);
        
        $display("[%0t] TEST5: assert reset", $time);
        reset = 1;
        
        // Wait for the next clock edge where reset will take effect
        @(posedge clk);
        #1;
        // Check reset effects immediately after clock edge
        $display("[%0t] TEST5: Checking reset effects...", $time);
        
        if (core_state !== IDLE) begin
            $display("[%0t] TEST5: *** ERROR *** State should be IDLE, got %s", 
                     $time, get_state_name(core_state));
        end else begin
            $display(" TEST5: PASS ");//expected 
        end
        
        if (current_pc !== 0) begin
            $display("[%0t] TEST5: *** ERROR *** PC should be 0, got 0x%02h", 
                     $time, current_pc);
        end else begin
            $display("TEST5: PASS");//expected 
        end
        
        if (done !== 0) begin
            $display("[%0t] TEST5: *** ERROR *** done should be 0, got %b", $time, done);
        end else begin
            $display("TEST5: PASS");
        end
        
        // Deassert reset properly
        #(CLK_PERIOD/2);
        reset = 0;
        @(posedge clk);
        
        $display("\n TEST5: DONE");
        #(CLK_PERIOD * 5);
    end
endtask
    
    // MAIN TEST SEQUENCE
    initial begin        
        // Small delay before starting tests
        #(CLK_PERIOD * 2);
        
        // Run all test scenarios
        test_sequential_execution();
        test_memory_access();
        test_multiple_thread_memory();
        test_ret_instruction();
        test_reset_during_execution();
        
        $finish;
    end

endmodule