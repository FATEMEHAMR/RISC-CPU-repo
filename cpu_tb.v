module cpu_testbench();
    reg [127:0] init_ins;
    reg [127:0] init_data;
    reg clk;

    // Instantiate the CPU
    cpu uut (
        .init_ins(init_ins),
        .init_data(init_data),
        .clk(clk)
    );

    // Generate clock signal
    always begin
        #5 clk = ~clk;
    end

    initial begin
        // Initialize inputs
        clk = 0;
        init_ins = 128'h00000000000000000000000000000000; // All zeros initially
        init_data = 128'h00000000000000000000000000000000; // All zeros initially

        // Apply initial instruction and data memory values
        init_ins[7:0]    = 8'b01000000; // Load mem_0 into AC
        init_ins[15:8]   = 8'b00000001; // Subtract 1 (no-op to use skip next instruction feature if zero)
        init_ins[23:16]  = 8'b11111111; // Exit (jump to end)
        init_ins[31:24]  = 8'b01100110; // 2's complement of AC
        init_ins[39:32]  = 8'b01010001; // Store 2's complement in mem_1 (used as counter)
        init_ins[47:40]  = 8'b01000100; // Arithmetic shift right (division by 2) on AC
        init_ins[55:48]  = 8'b00000001; // Subtract 1 (no-op to use skip next instruction feature if zero)
        init_ins[63:56]  = 8'b11110111; // Jump to loop if not zero
        init_ins[71:64]  = 8'b01010010; // Load mem_1 into AC
        init_ins[79:72]  = 8'b00000010; // Add 1 to AC (increment the count)
        init_ins[87:80]  = 8'b01010001; // Store back to mem_1 (now it contains the exponent)
        init_ins[95:88]  = 8'b01110101; // Load 1 into AC (root of mem_1 is 1)
        init_ins[103:96] = 8'b01010010; // Store 1 in mem_1
        init_ins[111:104]= 8'b01000001; // Load mem_1 into AC
        init_ins[119:112]= 8'b00110000; // Multiply AC by 2
        init_ins[127:120]= 8'b11111110; // Jump to next step if count + 1 shifts completed
        // Repeat last 8-bit data for a valid exit
        init_ins[135:128]= 8'b01010000; // Store result back to mem_0
        init_ins[143:136]= 8'b11111111; // Exit
        init_data[7:0]   = 8'b00001010; // Initial data at mem_0 (10)

        // Monitor changes to the CPU's internal registers
        $monitor("Time: %0t | PC: %b | AC: %b | IR: %b | DR: %b | TR: %b | AR: %b | ALU Out: %b | bus_output: %b | seq_out: %b",
                 $time, uut.PC, uut.AC, uut.IR, uut.DR, uut.TR, uut.AR, uut.alu_out, uut.bus_output, uut.seq_out);

        // Run the simulation for a sufficient period
        #4000 $finish;
    end
endmodule
