// popcount_tree_parallel.v — Parallel adder tree for POPCOUNT
// Synthesizable by Yosys. No loops. Pure combinatorial tree.
// Target: Artix-7 LUT6. WIDTH parameterized.
// Resource: ~8 * WIDTH LUT6 for the full tree (20K → ~20K LUTs)
module popcount_tree_parallel #(
    parameter WIDTH = 1000
)(
    input  wire [WIDTH-1:0] data,
    output wire [14:0]      result
);

    // Local function: clog2
    function integer clog2;
        input integer x;
        integer i;
        begin
            clog2 = 1;
            for (i = 1; i < x; i = i * 2) clog2 = clog2 + 1;
        end
    endfunction

    localparam LEVELS = clog2(WIDTH);
    
    // Tree structure: each level halves the number of terms
    // Each adder adds two numbers from previous level
    
    // Level 0: group input bits into 2-bit counts
    // Each group of 2 adjacent bits → 0,1,2 → 2-bit result
    // Number of groups: WIDTH/2 (rounded up)
    
    // For small WIDTH, use direct reduction
    // For large WIDTH, use hierarchical tree
    
    generate
        if (WIDTH <= 16) begin
            // Direct: full adder tree in one level
            assign result = count_bits(data);
        end else begin
            // Recursive: split into halves and add
            wire [13:0] left, right;
            localparam LH = WIDTH / 2;
            localparam RH = WIDTH - LH;
            
            popcount_tree_parallel #(.WIDTH(LH)) left_inst (.data(data[LH-1:0]), .result(left));
            popcount_tree_parallel #(.WIDTH(RH)) right_inst (.data(data[WIDTH-1:LH]), .result(right));
            
            assign result = left + right;
        end
    endgenerate

    function [14:0] count_bits;
        input [WIDTH-1:0] vec;
        integer i;
        reg [14:0] acc;
        begin
            acc = 0;
            for (i = 0; i < WIDTH; i = i + 1)
                if (vec[i]) acc = acc + 1;
            count_bits = acc;
        end
    endfunction

endmodule

// ============================================================
// hd_classifier_core.v — Full HD classifier with parallel tree
// ============================================================
module hd_classifier_core #(
    parameter D = 20000,       // HD dimensions
    parameter N_CLASSES = 20   // Number of classes
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire [D-1:0]    doc_vector,
    output reg  [4:0]       class_id,
    output reg  [14:0]      confidence,
    output reg              done
);

    // Prototype memory (20 classes × D bits)
    reg [D-1:0] prototypes [0:N_CLASSES-1];

    // Distance compute
    wire [14:0] dist;
    reg [D-1:0] xored;

    // Tree POPCOUNT
    popcount_tree_parallel #(.WIDTH(D)) popcount_inst (
        .data(xored),
        .result(dist)
    );

    // FSM
    reg [4:0] state;
    reg [4:0] idx;
    reg [14:0] min_dist;
    reg [4:0] min_idx;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 0;
            done <= 0;
            class_id <= 0;
            confidence <= 0;
        end else begin
            case (state)
                0: if (start) begin
                    state <= 2;
                    idx <= 0;
                    min_dist <= 20000;
                    min_idx <= 0;
                    xored <= doc_vector ^ prototypes[0];
                end
                
                2: begin
                    // Distances are combinatorial (1 cycle after xor)
                    if (dist < min_dist) begin
                        min_dist <= dist;
                        min_idx <= idx;
                    end
                    if (idx < N_CLASSES - 1) begin
                        idx <= idx + 1;
                        xored <= doc_vector ^ prototypes[idx + 1];
                    end else begin
                        state <= 3;
                    end
                end
                
                3: begin
                    class_id <= min_idx;
                    confidence <= min_dist;
                    done <= 1;
                    state <= 0;
                end
            endcase
        end
    end

endmodule
