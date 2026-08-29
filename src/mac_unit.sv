module mac_unit #(parameter DW=11, parameter ACC_W=32)(
    input logic clk, rst_n,
    input logic signed [DW-1:0] a, b,
    input logic valid_in, clear_acc,
    

    output logic signed [ACC_W-1:0] acc_out,
    output logic valid_out
);

logic signed [2*DW-1:0] product;
logic signed [ACC_W-1:0] product_ext;
logic valid_reg, clear_reg;


assign product = a * b;
assign product_ext = {{(ACC_W-(2*DW)){product[2*DW-1]}}, product};

always_ff @(posedge clk or negedge rst_n) begin //upon starting the chip, should also go through this process
    if(!rst_n) begin
        acc_out <= 0; 
	valid_out <= 0;
        valid_reg <= 0; 
	clear_reg <= 0;
    end else begin
        valid_reg <= valid_in;
        clear_reg <= clear_acc;
        if(valid_reg) begin
            if(clear_reg) 
		acc_out <= product_ext;
            else          
		acc_out <= acc_out + product_ext;
        end
        valid_out <= valid_reg;
    end
end
endmodule
