module cpu(init_ins, init_data, clk);
    input [127:0] init_ins;
    input [127:0] init_data;
    input wire clk;

    wire [2:0] seq_out;
    wire [7:0] decoder_out;

    reg enable;
    reg imem_enable, dmem_enable, alu_enable, decoder_enable;
    reg seq_reset, initial_load, memory_write;
    reg decoder_in;
    reg [7:0] IR, DR, AC, TR, alu_op1, alu_op2;
    wire [7:0] alu_out, imem_out, dmem_out;
    reg [3:0] AR, PC;
    wire signed [7:0] bus_output;
    reg [3:0] bus_selector;
    reg [2:0] opcode;

    instruction_memory ins_memory(imem_enable, imem_out, AR, initial_load, init_ins, clk);
    data_memory data_memory(dmem_enable, dmem_out, AR, TR, memory_write, initial_load, init_data, clk);
    counter sequencer(seq_out, clk, seq_reset);
    decoder decoder(decoder_enable, decoder_out, decoder_in);
    alu alu(alu_out, alu_enable, opcode, DR, AC);
    bus bus(bus_output, PC, AC, IR, DR, TR, AR, imem_out, dmem_out, bus_selector);

    initial begin
        enable = 1;
        initial_load = 1;
        imem_enable = 0;
        dmem_enable = 0;
        alu_enable = 0;
        decoder_enable = 0;
        seq_reset = 1;
        PC = 0;
        AC = 0;
    end

    always @(seq_out) begin
        if (enable == 1) begin
            initial_load = 0;
            case(seq_out)
                3'b000: // ins fetch
                begin
                    seq_reset = 0;
                    bus_selector = 4'b0111; // Select PC
                    AR = bus_output;
                    imem_enable = 1;
                end
                3'b001: // decode
                begin
                    imem_enable = 0;
                    bus_selector = 4'b0101; // Select imem
                    #2
                    IR = bus_output;
                    decoder_enable = 1;

                end
                3'b010: // op fetch
                begin
                    decoder_in = IR[6:4];
                    opcode = IR[6:4] ;
                    if (IR[7] == 1)
                        enable = 0;
                    AR = IR[3:0];
                    #2
                    dmem_enable = 1;
                    bus_selector = 4'b0110; //data memory
                    memory_write = 0;
                    decoder_enable = 0;

                end
                3'b011: // execute
                begin

                    dmem_enable = 0;
                    DR = dmem_out;
                    if (decoder_out[0]) // Add
                    begin
                        alu_enable = 1'b1 ;
                        alu_op1 = DR;
                        alu_op2 = AC;

                    end
                    else if (decoder_out[3]) // Load
                    begin
                        alu_enable = 1;
                        alu_op1 = DR;
                        alu_op2 = AC;
                    end
                    else if (decoder_out[4]) // Arithmetic shift left
                    begin
                        alu_enable = 1;
                        alu_op1 = DR;
                        alu_op2 = AC;
                    end
                    else if (decoder_out[5]) // Store
                    begin
                        bus_selector = 4'b0001; // Select AC
                        TR = bus_output;
                    end
                    else if (decoder_out[7]) // Root
                    begin
                        alu_enable = 1;
                        alu_op1 = DR;
                        alu_op2 = AC;
                    end
                    else if (decoder_out[6]) // XNOR
                    begin
                        alu_enable = 1;
                        alu_op1 = DR;
                        alu_op2 = AC;
                    end
                    else if (decoder_out[2]) // Arithmetic shift right
                    begin
                        alu_enable = 1;
                        alu_op1 = DR;
                        alu_op2 = AC;
                    end
                    else if (decoder_out[1]) // 2's complement
                    begin
                        alu_enable = 1;
                        alu_op1 = DR;
                        alu_op2 = AC;
                    end
                end
                3'b100: // writeback
                begin
                    #10
                    alu_enable = 0;
                    AC = alu_out;
                    if (~decoder_out[5]) begin
                        bus_selector = 4'b0011; // Select DR
                        TR = bus_output;
                    end
                    memory_write = 1;
                    dmem_enable = 1;
                end
                3'b101: // program counter
                begin
                    memory_write = 0;
                    dmem_enable = 0;
                    PC = PC + 1;
                end
                3'b110: // reset
                begin
                    seq_reset = 1;
                end
            endcase
        end
    end
endmodule



module bus(bus_out, PC, AC, IR, DR, TR, AR, ins_mem, data_mem, bus_selector);
        input [7:0] PC, AC, IR, DR, TR, AR, ins_mem, data_mem;
        input [3:0] bus_selector;
        output reg signed [7:0] bus_out;

        always @(*) begin
              case (bus_selector)
                  4'b0000: bus_out = AR;
                  4'b0001: bus_out = AC;
                  4'b0010: bus_out = IR;
                  4'b0011: bus_out = DR;
                  4'b0100: bus_out = TR;
                  4'b0101: bus_out = ins_mem;
                  4'b0110: bus_out = data_mem;
                  4'b0111: bus_out = PC;
                  default: bus_out = 8'b00000000;
                  endcase
       end
endmodule

module instruction_memory(enable, ins_out, AR, first_load, init_ins, clk);
    input [3:0] AR;
    input first_load, clk, enable;
    input [127:0] init_ins;
    output reg [7:0] ins_out;
    reg [7:0] memory [15:0];

    integer i;

    always @(posedge clk) begin
        if (first_load == 1) begin
            for (i = 0; i < 16; i = i + 1)
                memory[i] = init_ins[i*8+:8];
        end else if (enable == 1)
            ins_out = memory[AR];
    end
endmodule

module data_memory(enable, data_out, AR, data_in, write, first_load, init_data, clk);
    input [3:0] AR;
    input write, first_load, clk, enable;
    input [7:0] data_in;
    input [127:0] init_data;
    output reg [7:0] data_out;
    reg [7:0] memory [15:0];

    integer i;

    always @(posedge clk) begin
        if (first_load == 1) begin
            for (i = 0; i < 16; i = i + 1)
                memory[i] = init_data[i*8+:8];
        end else if (enable == 1 && write == 1)
            memory[AR] = data_in;
        else if (enable == 1)
            data_out = memory[AR];
    end
endmodule

module alu(out, enable, opcode, op1, op2);
    input enable;
    input [2:0]opcode;
    input signed [7:0] op1, op2;
    output reg signed [7:0] out;

    reg signed [7:0] root_temp;

always   begin
        #5
        //if (enable == 1'b1) begin
            case(opcode)
                3'b000: out = op1 + op2; // sum
                3'b011: out = op1 << 1; // arithmetic shift left
                3'b111: begin // root
                    root_temp = 0;
                    for (; root_temp * root_temp < op1;)
                        root_temp = root_temp + 1;
                    out = root_temp;
                end
                3'b100: out = ~(op1 ^ op2); // xnor
                3'b101: out = op1 >> 1; // arithmetic shift right (division by 2)
                3'b110: out = -op1; // 2's complement
                default: out = out;
            endcase
       // end
    end
endmodule

module counter(out, clk, reset);
    input clk, reset;
    output reg [2:0] out;
    always @ (posedge clk) begin
        out = out + 1;
        if (reset==1)
            out = 3'b000;
    end
endmodule

module decoder(en, out, in);
    input [2:0] in;
    input en;
    output reg [7:0] out;

    always @ (in) begin
        if (en == 1) begin
            case (in)
                3'b000: out = 8'b00000001;
                3'b001: out = 8'b00000010; // 2's complement
                3'b010: out = 8'b00000100; // Arithmetic shift right
                3'b011: out = 8'b00001000;
                3'b100: out = 8'b00010000;
                3'b101: out = 8'b00100000;
                3'b110: out = 8'b01000000; // XNOR
                3'b111: out = 8'b10000000;
            endcase
        end
    end
endmodule

module counter_test3;
    reg clk, reset;
    wire [2:0] out;
    counter count(out, clk, reset);
    always begin
        clk = ~clk;
        #10;
    end
    initial begin
        clk = 1; reset = 1;
        #15;
        reset = 0;
        #110;
        reset = 1;
        #20;
    end
endmodule

module decoder_test3;
    reg [2:0] in;
    wire [7:0] out;
    reg en;
    decoder deco(en, out, in);
    initial begin
        en = 1;
        in = 3'b000;
        #100;
        in = 3'b001; // 2's complement
        #100;
        in = 3'b010; // Arithmetic shift right
        #100;
        in = 3'b011;
        #100;
        in = 3'b100;
        #100;
        in = 3'b101;
        #100;
        in = 3'b110; // XNOR
        #100;
        in = 3'b111;
        #100;
    end
endmodule

module alu_test3;
    reg [7:0] op1, op2;
    reg enable;
    reg opcode;
    wire [7:0] out;
    alu alu(out, enable, opcode, op1, op2);
    initial begin
        enable = 1;
        opcode = 3'b000;
        op1 = 8'b00001001;
        op2 = 8'b00000001;
        #10;
        opcode = 3'b011;
        #10;
        opcode = 3'b111;
        #10;
        opcode = 3'b100; // XNOR
        #10;
        opcode = 3'b101; // Arithmetic shift right
        #10;
        opcode = 3'b110; // 2's complement
        #10;
    end
endmodule

module cpu_test3;
    reg [127:0] ins_mem, data_mem;
    reg clk;
    cpu cpu(ins_mem, data_mem, clk);
    always begin
        clk = ~clk;
        #10;
    end

    initial begin
        clk = 0;
        ins_mem = 0;
        data_mem = 0;

        // Load operand from memory location 0 to AC
        ins_mem[7-:8]   = 8'b01000000; // Load mem_0 into AC

        // Check if AC is zero
        ins_mem[15-:8]  = 8'b00000001; // Subtract 1 (no-op to use skip next instruction feature if zero)

        // If AC is zero, jump to the end
        ins_mem[23-:8]  = 8'b11111111; // Exit (jump to end)

        // Otherwise, find the highest set bit
        ins_mem[31-:8]  = 8'b01100110; // 2's complement of AC
        ins_mem[39-:8]  = 8'b01010001; // Store 2's complement in mem_1 (used as counter)

        // Loop: Shift right until AC becomes zero
        ins_mem[47-:8]  = 8'b01000100; // Arithmetic shift right (division by 2) on AC
        ins_mem[55-:8]  = 8'b00000001; // Subtract 1 (no-op to use skip next instruction feature if zero)
        ins_mem[63-:8]  = 8'b11110111; // Jump to loop if not zero

// At this point, mem_1 contains the count of shifts
        // Compute 2^(mem_1 + 1) by shifting left
        ins_mem[71-:8]  = 8'b01010010; // Load mem_1 into AC
        ins_mem[79-:8]  = 8'b00000010; // Add 1 to AC (increment the count)
        ins_mem[87-:8]  = 8'b01010001; // Store back to mem_1 (now it contains the exponent)

        // Initialize result to 1
        ins_mem[95-:8]  = 8'b01110101; // Load 1 into AC (root of mem_1 is 1)
        ins_mem[103-:8] = 8'b01010010; // Store 1 in mem_1

        // Compute 2^(count + 1)
        ins_mem[111-:8] = 8'b01000001; // Load mem_1 into AC
        ins_mem[119-:8] = 8'b00110000; // Multiply AC by 2
        ins_mem[127-:8] = 8'b11111110; // Jump to next step if count + 1 shifts completed
        ins_mem[127-:8] = 8'b01010000; // Store result back to mem_0

        // Exit
        ins_mem[127-:8] = 8'b11111111; // Exit

        // Initial data: operand to round up
        data_mem[7-:8]  = 8'b00001010; // Initial data at mem_0 (10)
    end
endmodule
