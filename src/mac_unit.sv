module mac_unit #(
    parameter DW    = 11,
    parameter ACC_W = 32
)(
    input  logic clk,
    input  logic rst_n,

    input  logic signed [DW-1:0] a,
    input  logic signed [DW-1:0] b,

    input  logic valid_in,
    input  logic clear_acc,

    output logic signed [ACC_W-1:0] acc_out,
    output logic valid_out
);

    logic signed [2*DW-1:0] product;
    logic signed [ACC_W-1:0] product_ext;

    logic valid_reg;
    logic clear_reg;

    assign product = a * b;

    // Sign-extend the 22-bit product to 32 bits.
    assign product_ext = {
        {(ACC_W-(2*DW)){product[2*DW-1]}},
        product
    };

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out   <= '0;
            valid_out <= 1'b0;
            valid_reg <= 1'b0;
            clear_reg <= 1'b0;
        end else begin
            valid_reg <= valid_in;
            clear_reg <= clear_acc;

            valid_out <= valid_reg;

            if (valid_reg) begin
                if (clear_reg)
                    acc_out <= product_ext;
                else
                    acc_out <= acc_out + product_ext;
            end
        end
    end

endmodule
