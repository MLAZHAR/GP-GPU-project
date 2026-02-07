`default_nettype none
`timescale 1ns/1ns

module decoder_tb;
    // Inp
    reg clk;
    reg reset;
    reg [2:0] core_state;
    reg [15:0] instruction;
    
    // Outp
    wire [3:0] decoded_rd_address;
    wire [3:0] decoded_rs_address;
    wire [3:0] decoded_rt_address;
    wire [2:0] decoded_nzp;
    wire [7:0] decoded_immediate;
    wire decoded_reg_write_enable;
    wire decoded_mem_read_enable;
    wire decoded_mem_write_enable;
    wire decoded_nzp_write_enable;
    wire [1:0] decoded_reg_input_mux;
    wire [1:0] decoded_alu_arithmetic_mux;
    wire decoded_alu_output_mux;
    wire decoded_pc_mux;
    wire decoded_ret;

    // Instantiate the decoder
    decoder uut (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .instruction(instruction),
        .decoded_rd_address(decoded_rd_address),
        .decoded_rs_address(decoded_rs_address),
        .decoded_rt_address(decoded_rt_address),
        .decoded_nzp(decoded_nzp),
        .decoded_immediate(decoded_immediate),
        .decoded_reg_write_enable(decoded_reg_write_enable),
        .decoded_mem_read_enable(decoded_mem_read_enable),
        .decoded_mem_write_enable(decoded_mem_write_enable),
        .decoded_nzp_write_enable(decoded_nzp_write_enable),
        .decoded_reg_input_mux(decoded_reg_input_mux),
        .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux),
        .decoded_alu_output_mux(decoded_alu_output_mux),
        .decoded_pc_mux(decoded_pc_mux),
        .decoded_ret(decoded_ret)
    );

    // ClK
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task: Reset the decoder
    task reset_decoder;
        begin
            reset = 1;
            core_state = 3'b000;
            instruction = 16'h0000;
            @(posedge clk);
            @(posedge clk);
            reset = 0;
            @(posedge clk);
        end
    endtask


    // Task: Decode an instruction
    task decode_instruction;
        input [15:0] instr;
        begin
	   instruction = instr;
            core_state = 3'b010;
            @(posedge clk);
            @(posedge clk);
            #1;
        end
    endtask

    // Task: Check decoded instruction fields
    task check_instruction_fields;
        input [3:0] expected_rd;
        input [3:0] expected_rs;
        input [3:0] expected_rt;
        input [2:0] expected_nzp;
        input [7:0] expected_imm;
        begin
            assert(decoded_rd_address == expected_rd) else
                $error("Time %0t: RD address mismatch - Expected: %h, Got: %h", $time, expected_rd, decoded_rd_address);//DEBUG
            assert(decoded_rs_address == expected_rs) else
                $error("Time %0t: RS address mismatch - Expected: %h, Got: %h", $time, expected_rs, decoded_rs_address);//
            assert(decoded_rt_address == expected_rt) else
                $error("Time %0t: RT address mismatch - Expected: %h, Got: %h", $time, expected_rt, decoded_rt_address);//
            assert(decoded_nzp == expected_nzp) else
                $error("Time %0t: NZP mismatch - Expected: %b, Got: %b", $time, expected_nzp, decoded_nzp);//
            assert(decoded_immediate == expected_imm) else
                $error("Time %0t: Immediate mismatch - Expected: %h, Got: %h", $time, expected_imm, decoded_immediate);//
        end
    endtask

    // Task: Check control signals for NOP
    task check_nop_signals;
        begin
            assert(decoded_reg_write_enable == 0) else
                $error("Time %0t: NOP reg_write_enable should be 0", $time);//
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: NOP mem_read_enable should be 0", $time);//
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: NOP mem_write_enable should be 0", $time);//
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: NOP nzp_write_enable should be 0", $time);//
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: NOP reg_input_mux should be 00", $time);//
            assert(decoded_alu_arithmetic_mux == 2'b00) else
                $error("Time %0t: NOP alu_arithmetic_mux should be 00", $time);//
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: NOP alu_output_mux should be 0", $time);//
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: NOP pc_mux should be 0", $time);//
            assert(decoded_ret == 0) else
                $error("Time %0t: NOP ret should be 0", $time);//
        end
    endtask

    // Task: Check control signals for BRnzp
    task check_branch_signals;
        begin
            assert(decoded_reg_write_enable == 0) else
                $error("Time %0t: BRANCH reg_write_enable should be 0", $time);//
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: BRANCH mem_read_enable should be 0", $time);//
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: BRANCH mem_write_enable should be 0", $time);//
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: BRANCH nzp_write_enable should be 0", $time);//
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: BRANCH reg_input_mux should be 00", $time);//
            assert(decoded_alu_arithmetic_mux == 2'b00) else
                $error("Time %0t: BRANCH alu_arithmetic_mux should be 00", $time);//
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: BRANCH alu_output_mux should be 0", $time);//
            assert(decoded_pc_mux == 1) else
                $error("Time %0t: BRANCH pc_mux should be 1", $time);//
            assert(decoded_ret == 0) else
                $error("Time %0t: BRANCH ret should be 0", $time);//
        end
    endtask

    // Task: Check control signals for CMP
    task check_cmp_signals;
        begin
            assert(decoded_reg_write_enable == 0) else
                $error("Time %0t: CMP reg_write_enable should be 0", $time);
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: CMP mem_read_enable should be 0", $time);
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: CMP mem_write_enable should be 0", $time);
            assert(decoded_nzp_write_enable == 1) else
                $error("Time %0t: CMP nzp_write_enable should be 1", $time);
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: CMP reg_input_mux should be 00", $time);
            assert(decoded_alu_arithmetic_mux == 2'b00) else
                $error("Time %0t: CMP alu_arithmetic_mux should be 00", $time);
            assert(decoded_alu_output_mux == 1) else
                $error("Time %0t: CMP alu_output_mux should be 1", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: CMP pc_mux should be 0", $time);
            assert(decoded_ret == 0) else
                $error("Time %0t: CMP ret should be 0", $time);
        end
    endtask

    // Task: Check control signals for ADD
    task check_add_signals;
        begin
            assert(decoded_reg_write_enable == 1) else
                $error("Time %0t: ADD reg_write_enable should be 1", $time);
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: ADD mem_read_enable should be 0", $time);
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: ADD mem_write_enable should be 0", $time);
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: ADD nzp_write_enable should be 0", $time);
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: ADD reg_input_mux should be 00", $time);
            assert(decoded_alu_arithmetic_mux == 2'b00) else
                $error("Time %0t: ADD alu_arithmetic_mux should be 00", $time);
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: ADD alu_output_mux should be 0", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: ADD pc_mux should be 0", $time);
            assert(decoded_ret == 0) else
                $error("Time %0t: ADD ret should be 0", $time);
        end
    endtask

    // Task: Check control signals for SUB
    task check_sub_signals;
        begin
            assert(decoded_reg_write_enable == 1) else
                $error("Time %0t: SUB reg_write_enable should be 1", $time);
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: SUB mem_read_enable should be 0", $time);
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: SUB mem_write_enable should be 0", $time);
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: SUB nzp_write_enable should be 0", $time);
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: SUB reg_input_mux should be 00", $time);
            assert(decoded_alu_arithmetic_mux == 2'b01) else
                $error("Time %0t: SUB alu_arithmetic_mux should be 01", $time);
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: SUB alu_output_mux should be 0", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: SUB pc_mux should be 0", $time);
            assert(decoded_ret == 0) else
                $error("Time %0t: SUB ret should be 0", $time);
        end
    endtask

    // Task: Check control signals for MUL
    task check_mul_signals;
        begin
            assert(decoded_reg_write_enable == 1) else
                $error("Time %0t: MUL reg_write_enable should be 1", $time);
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: MUL mem_read_enable should be 0", $time);
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: MUL mem_write_enable should be 0", $time);
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: MUL nzp_write_enable should be 0", $time);
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: MUL reg_input_mux should be 00", $time);
            assert(decoded_alu_arithmetic_mux == 2'b10) else
                $error("Time %0t: MUL alu_arithmetic_mux should be 10", $time);
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: MUL alu_output_mux should be 0", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: MUL pc_mux should be 0", $time);
            assert(decoded_ret == 0) else
                $error("Time %0t: MUL ret should be 0", $time);
        end
    endtask

    // Task: Check control signals for DIV
    task check_div_signals;
        begin
            assert(decoded_reg_write_enable == 1) else
                $error("Time %0t: DIV reg_write_enable should be 1", $time);
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: DIV mem_read_enable should be 0", $time);
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: DIV mem_write_enable should be 0", $time);
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: DIV nzp_write_enable should be 0", $time);
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: DIV reg_input_mux should be 00", $time);
            assert(decoded_alu_arithmetic_mux == 2'b11) else
                $error("Time %0t: DIV alu_arithmetic_mux should be 11", $time);
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: DIV alu_output_mux should be 0", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: DIV pc_mux should be 0", $time);
            assert(decoded_ret == 0) else
                $error("Time %0t: DIV ret should be 0", $time);
        end
    endtask

    // Task: Check control signals for LDR
    task check_ldr_signals;
        begin
            assert(decoded_reg_write_enable == 1) else
                $error("Time %0t: LDR reg_write_enable should be 1", $time);
            assert(decoded_mem_read_enable == 1) else
                $error("Time %0t: LDR mem_read_enable should be 1", $time);
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: LDR mem_write_enable should be 0", $time);
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: LDR nzp_write_enable should be 0", $time);
            assert(decoded_reg_input_mux == 2'b01) else
                $error("Time %0t: LDR reg_input_mux should be 01", $time);
            assert(decoded_alu_arithmetic_mux == 2'b00) else
                $error("Time %0t: LDR alu_arithmetic_mux should be 00", $time);
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: LDR alu_output_mux should be 0", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: LDR pc_mux should be 0", $time);
            assert(decoded_ret == 0) else
                $error("Time %0t: LDR ret should be 0", $time);
        end
    endtask

    // Task: Check control signals for STR
    task check_str_signals;
        begin
            assert(decoded_reg_write_enable == 0) else
                $error("Time %0t: STR reg_write_enable should be 0", $time);
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: STR mem_read_enable should be 0", $time);
            assert(decoded_mem_write_enable == 1) else
                $error("Time %0t: STR mem_write_enable should be 1", $time);
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: STR nzp_write_enable should be 0", $time);
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: STR reg_input_mux should be 00", $time);
            assert(decoded_alu_arithmetic_mux == 2'b00) else
                $error("Time %0t: STR alu_arithmetic_mux should be 00", $time);
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: STR alu_output_mux should be 0", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: STR pc_mux should be 0", $time);
            assert(decoded_ret == 0) else
                $error("Time %0t: STR ret should be 0", $time);
        end
    endtask

    // Task: Check control signals for CONST
    task check_const_signals;
        begin
            assert(decoded_reg_write_enable == 1) else
                $error("Time %0t: CONST reg_write_enable should be 1", $time);
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: CONST mem_read_enable should be 0", $time);
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: CONST mem_write_enable should be 0", $time);
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: CONST nzp_write_enable should be 0", $time);
            assert(decoded_reg_input_mux == 2'b10) else
                $error("Time %0t: CONST reg_input_mux should be 10", $time);
            assert(decoded_alu_arithmetic_mux == 2'b00) else
                $error("Time %0t: CONST alu_arithmetic_mux should be 00", $time);
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: CONST alu_output_mux should be 0", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: CONST pc_mux should be 0", $time);
            assert(decoded_ret == 0) else
                $error("Time %0t: CONST ret should be 0", $time);
        end
    endtask

    // Task: Check control signals for RET
    task check_ret_signals;
        begin
            assert(decoded_reg_write_enable == 0) else
                $error("Time %0t: RET reg_write_enable should be 0", $time);
            assert(decoded_mem_read_enable == 0) else
                $error("Time %0t: RET mem_read_enable should be 0", $time);
            assert(decoded_mem_write_enable == 0) else
                $error("Time %0t: RET mem_write_enable should be 0", $time);
            assert(decoded_nzp_write_enable == 0) else
                $error("Time %0t: RET nzp_write_enable should be 0", $time);
            assert(decoded_reg_input_mux == 2'b00) else
                $error("Time %0t: RET reg_input_mux should be 00", $time);
            assert(decoded_alu_arithmetic_mux == 2'b00) else
                $error("Time %0t: RET alu_arithmetic_mux should be 00", $time);
            assert(decoded_alu_output_mux == 0) else
                $error("Time %0t: RET alu_output_mux should be 0", $time);
            assert(decoded_pc_mux == 0) else
                $error("Time %0t: RET pc_mux should be 0", $time);
            assert(decoded_ret == 1) else
                $error("Time %0t: RET ret should be 1", $time);
        end
    endtask

    // Task: Test NOP instruction
    task test_nop;
        begin
            decode_instruction(16'h0000);
            check_instruction_fields(4'h0, 4'h0, 4'h0, 3'b000, 8'h00);
            check_nop_signals();
        end
    endtask

    // Task: Test BRnzp
    task test_branch;
        input [2:0] nzp;
        input [7:0] offset;
        begin
            decode_instruction({4'b0001, nzp, 1'b0, offset});
            check_instruction_fields({nzp, 1'b0}, offset[7:4], offset[3:0], nzp, offset);
            check_branch_signals();
        end
    endtask

    // Task: Test CMP
    task test_cmp;
        input [3:0] rs;
        input [3:0] rt;
        begin
            decode_instruction({4'b0010, 4'h0, rs, rt});
            check_instruction_fields(4'h0, rs, rt, 3'b000, {rs, rt});
            check_cmp_signals();
        end
    endtask

    // Task: Test ADD
    task test_add;
        input [3:0] rd;
        input [3:0] rs;
        input [3:0] rt;
        begin
            decode_instruction({4'b0011, rd, rs, rt});
            check_instruction_fields(rd, rs, rt, rd[3:1], {rs, rt});
            check_add_signals();
        end
    endtask

    // Task: Test SUB
    task test_sub;
        input [3:0] rd;
        input [3:0] rs;
        input [3:0] rt;
        begin
            decode_instruction({4'b0100, rd, rs, rt});
            check_instruction_fields(rd, rs, rt, rd[3:1], {rs, rt});
            check_sub_signals();
        end
    endtask

    // Task: Test MUL
    task test_mul;
        input [3:0] rd;
        input [3:0] rs;
        input [3:0] rt;
        begin
            decode_instruction({4'b0101, rd, rs, rt});
            check_instruction_fields(rd, rs, rt, rd[3:1], {rs, rt});
            check_mul_signals();
        end
    endtask

    // Task: Test DIV
    task test_div;
        input [3:0] rd;
        input [3:0] rs;
        input [3:0] rt;
        begin
            decode_instruction({4'b0110, rd, rs, rt});
            check_instruction_fields(rd, rs, rt, rd[3:1], {rs, rt});
            check_div_signals();
        end
    endtask

    // Task: Test LDR
    task test_ldr;
        input [3:0] rd;
        input [3:0] rs;
        input [3:0] rt;
        begin
            decode_instruction({4'b0111, rd, rs, rt});
            check_instruction_fields(rd, rs, rt, rd[3:1], {rs, rt});
            check_ldr_signals();
        end
    endtask

    // Task: Test STR
    task test_str;
        input [3:0] rd;
        input [3:0] rs;
        input [3:0] rt;
        begin
            decode_instruction({4'b1000, rd, rs, rt});
            check_instruction_fields(rd, rs, rt, rd[3:1], {rs, rt});
            check_str_signals();
        end
    endtask

    // Task: Test CONST
    task test_const;
        input [3:0] rd;
        input [7:0] imm;
        begin
            decode_instruction({4'b1001, rd, imm});
            check_instruction_fields(rd, imm[7:4], imm[3:0], rd[3:1], imm);
            check_const_signals();
        end
    endtask

    // Task: Test RET
    task test_ret;
        begin
            decode_instruction(16'hF000);
            check_instruction_fields(4'h0, 4'h0, 4'h0, 3'b000, 8'h00);
            check_ret_signals();
        end
    endtask

   // Main test sequence
	initial begin
    reset_decoder();           

    // Test all instructions
    test_nop();
    // Expected: All control signals = 0, no operation performed
    
    test_branch(3'b111, 8'h0F);
    // Expected: pc_mux = 1, nzp = 3'b111, offset = 8'h0F, branch unconditionally
    
    test_branch(3'b100, 8'h20);
    // Expected: pc_mux = 1, nzp = 3'b100, offset = 8'h20, branch if negative
    
    test_cmp(4'h3, 4'h5);
    // Expected: nzp_write_enable = 1, alu_output_mux = 1, compare R3 and R5
    
    test_add(4'h3, 4'h1, 4'h2);
    // Expected: reg_write_enable = 1, alu_arithmetic_mux = 00, R3 = R1 + R2
    
    test_sub(4'h5, 4'h6, 4'h7);
    // Expected: reg_write_enable = 1, alu_arithmetic_mux = 01, R5 = R6 - R7
    
    test_mul(4'hA, 4'hB, 4'hC);
    // Expected: reg_write_enable = 1, alu_arithmetic_mux = 10, R10 = R11 * R12
    
    test_div(4'h8, 4'h4, 4'h2);
    // Expected: reg_write_enable = 1, alu_arithmetic_mux = 11, R8 = R4 / R2
    
    test_ldr(4'h2, 4'h3, 4'h4);
    // Expected: reg_write_enable = 1, mem_read_enable = 1, reg_input_mux = 01, R2 = Mem[R3+R4]
    
    test_str(4'h1, 4'h5, 4'h6);
    // Expected: mem_write_enable = 1, Mem[R5+R6] = R1
    
    test_const(4'h7, 8'hAB);
    // Expected: reg_write_enable = 1, reg_input_mux = 10, R7 = 0xAB
    
    test_ret();
    // Expected: decoded_ret = 1, all other control signals = 0, thread finishes

    #20;           
    $finish;      
end
endmodule