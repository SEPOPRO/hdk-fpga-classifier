// hd_kernel_synth_small.v — HDK kernel for Yosys (Verilog-2005 compatible)
module popcount_tree #(parameter WIDTH = 1000)(
    input  wire             clk, rst_n, en,
    input  wire [WIDTH-1:0] data,
    output reg  [14:0]      result,
    output reg              done
);
    reg [14:0] i;
    always @(posedge clk) begin
        if (!rst_n) begin result <= 0; done <= 0; end
        else begin
            done <= 0;
            if (en) begin
                result = 0;
                for (i = 0; i < WIDTH; i = i + 1)
                    if (data[i]) result = result + 1;
                done <= 1;
            end
        end
    end
endmodule

module hd_kernel #(parameter WIDTH = 1000)(
    input  wire             clk, rst_n, en,
    input  wire [WIDTH-1:0] vector_a, vector_b,
    output reg  [15:0]      sim,
    output reg              done
);
    wire [14:0] pc; wire pc_done;
    popcount_tree #(.WIDTH(WIDTH)) pc_inst (
        .clk(clk), .rst_n(rst_n), .en(en),
        .data(vector_a ^ vector_b), .result(pc), .done(pc_done)
    );
    always @(posedge clk) begin
        if (!rst_n) begin sim <= 0; done <= 0; end
        else begin done <= pc_done;
            if (pc_done) sim <= 16'd4096 - (pc * 16'd8192) / {16{WIDTH}};
        end
    end
endmodule

module hdk_classifier_top #(parameter WIDTH = 1000)(
    input  wire         clk, rst_n, start,
    input  wire [WIDTH-1:0] doc_vector,
    output reg          done
);
    reg [WIDTH-1:0] proto; reg [1:0] state; reg [4:0] cidx;
    wire [15:0] s; wire sd;
    hd_kernel #(.WIDTH(WIDTH)) k(
        .clk(clk), .rst_n(rst_n), .en(state==1),
        .vector_a(doc_vector), .vector_b(proto), .sim(s), .done(sd)
    );
    always @(posedge clk) begin
        if (!rst_n) begin state <= 0; done <= 0; end
        else begin
            case (state)
                0: if (start) begin state <= 1; cidx <= 0; end
                1: if (sd) begin
                    if (cidx < 19) cidx <= cidx + 1;
                    else state <= 2;
                end
                2: begin done <= 1; state <= 0; end
            endcase
        end
    end
endmodule
