// ==========================================================================
// popcount_tree_20k.v — 20,000-bit Population Count for Yosys synthesis
//
// Synthesizable by Yosys. No VHDL needed.
// Target: Artix-7 resource estimation
// ==========================================================================

module popcount_tree_20k (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,
    input  wire [19999:0] data,
    output reg  [14:0]  result,
    output reg          done
);

    // Sequential: count bits using a loop
    // Yosys will synthesize this into LUT-based carry chain logic
    always @(posedge clk) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (en) begin
                result <= count_bits(data);
                done <= 1;
            end
        end
    end

    // Combinatorial function for popcount
    function [14:0] count_bits;
        input [19999:0] vec;
        integer i;
        reg [14:0] acc;
        begin
            acc = 0;
            for (i = 0; i < 20000; i = i + 1) begin
                if (vec[i]) acc = acc + 1;
            end
            count_bits = acc;
        end
    endfunction

endmodule

// ==========================================================================
// hd_kernel.vhd — XOR + POPCOUNT + Similarity
// ==========================================================================

module hd_kernel (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,
    input  wire [19999:0] vector_a,
    input  wire [19999:0] vector_b,
    output reg  [15:0]  similarity,  // Q4.12 fixed point
    output reg          done
);

    wire [19999:0] xor_result;
    wire [14:0] popcount;
    wire pc_done;

    assign xor_result = vector_a ^ vector_b;

    popcount_tree_20k pc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .data(xor_result),
        .result(popcount),
        .done(pc_done)
    );

    // similarity = 4096 - (2 * popcount * 4096) / 20000
    // Q4.12: 1.0 = 4096
    always @(posedge clk) begin
        if (!rst_n) begin
            similarity <= 0;
            done <= 0;
        end else begin
            done <= pc_done;
            if (pc_done) begin
                similarity <= 16'd4096 - (popcount * 16'd8192) / 16'd20000;
            end
        end
    end

endmodule

// ==========================================================================
// Top module: HDK Classifier
// ==========================================================================

module hdk_classifier_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [19999:0] doc_vector,
    output reg  [4:0]   class_id,
    output reg  [15:0]  confidence,
    output reg          done
);

    // Prototype memory: 20 classes × 20000 bits
    // In real FPGA: stored in BRAM
    reg [19999:0] prototypes [0:19];
    integer i;

    // Initialize with test data (simplified)
    initial begin
        for (i = 0; i < 20; i = i + 1) begin
            prototypes[i] = {20000{1'b0}};
        end
    end

    // Classification FSM
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam MIN = 2'd2;
    localparam DONE = 2'd3;

    reg [1:0] state;
    reg [4:0] class_idx;
    reg [14:0] min_dist;
    reg [4:0] min_class;

    // Hamming distance computation
    wire [15:0] sim;
    wire sim_done;

    hd_kernel kernel_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(state == COMPUTE),
        .vector_a(doc_vector),
        .vector_b(prototypes[class_idx]),
        .similarity(sim),
        .done(sim_done)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            class_id <= 0;
            confidence <= 0;
            class_idx <= 0;
            min_dist <= 20000;
            min_class <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COMPUTE;
                        class_idx <= 0;
                        min_dist <= 20000;
                        min_class <= 0;
                    end
                end

                COMPUTE: begin
                    if (sim_done) begin
                        // Convert similarity to distance (Q4.12 → distance)
                        // similarity = 4096 - 2*popcount/D
                        // distance = 2*popcount/D (approximately)
                        // For min distance comparison, use sim directly
                        // (higher sim = better match)
                        if (class_idx < 19) begin
                            class_idx <= class_idx + 1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    class_id <= min_class;
                    confidence <= min_dist;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
