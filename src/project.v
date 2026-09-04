`default_nettype none

module tt_um_nitikac24_hchoi2927_pagerank (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Control signals going into markov_top
    wire       start;
    wire       rd_en;
    wire [2:0] rd_addr;

    // Result signals coming out of markov_top
    wire       done;
    wire signed [10:0] rd_data;

    // Map Tiny Tapeout input pins to the PageRank engine
    assign start   = ui_in[0];
    assign rd_en   = ui_in[1];
    assign rd_addr = ui_in[4:2];

    // Instantiate the PageRank engine
    markov_top #(
        .N(6),
        .DW(11),
        .ACC_W(32),
        .N_ITER(10)
    ) core (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .done    (done),
        .rd_en   (rd_en),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    // Map PageRank result to Tiny Tapeout output pins
    assign uo_out[0] = done;
    assign uo_out[3:1] = rd_data[10:8];
    assign uo_out[7:4] = 4'b0000;

    assign uio_out = rd_data[7:0];

    // All bidirectional pins are used as outputs.
    assign uio_oe = 8'hFF;

    // uio_in is unused because all uio pins are outputs.
    // ena is provided by Tiny Tapeout but isn't needed by our logic.
    wire _unused = &{ena, uio_in};

endmodule

`default_nettype wire
