module markov_top #(
    parameter N = 6,
    parameter DW = 11,
    parameter ACC_W = 32,
    parameter N_ITER = 10
)(
    input logic clk,
    input logic rst_n,
    input logic start,
    output logic done,
    output logic signed [N-1:0][DW-1:0] P_out

);

typedef enum logic [3:0] { IDLE, INIT, RUN, WAIT, CHECK, FINISH } state_t;
state_t state;

logic [$clog2(N_ITER+1)-1:0] iter_cnt;
logic [$clog2(N)-1:0] j;
logic signed [DW-1:0] P_cur [0:N-1];
integer i; //Iteration counter


//Parallelization
logic [$clog2(N*N)-1:0] t_addr [0:N-1];  
logic signed [DW-1:0]   t_data [0:N-1];  
logic signed [DW-1:0]   b_shared;          // the one vector value all lanes share
logic signed [ACC_W-1:0] mac_out [0:N-1]; // 6 running totals (one per lane)
logic mac_enable, mac_clear;                     // go and clear signals
logic mac_done [0:N-1]; 


assign b_shared = P_cur[j];


genvar g;
generate
    for (g = 0; g < N; g = g + 1) begin : lane  //for all lanes
       
        assign t_addr[g] = j*N + g;

        transition_mem #(.N(N), .DW(DW)) tmem (
            .addr(t_addr[g]),
            .data(t_data[g])
        );

        mac_unit #(.DW(DW), .ACC_W(ACC_W)) mac (
            .clk(clk), .rst_n(rst_n),
            .a(t_data[g]),        // this lane's matrix value
            .b(b_shared),         // shared vector value (broadcast!)
            .valid_in(mac_enable),
            .clear_acc(mac_clear),
            .acc_out(mac_out[g]),
            .valid_out(mac_done[g])
        );
    end
endgenerate


always_comb begin
    mac_enable = 0;
    mac_clear  = 0;
    if (state == RUN) begin
        mac_enable = 1;             
        if (j == 0) mac_clear = 1;  
    end
end


//FSM 
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        j <= 0;
        iter_cnt <= 0;
        done <= 0;
        
	for(i=0;i<N;i=i+1) begin
            P_cur[i] <= 0;
            P_out[i] <= 0;
        end

    end else begin
        done <= 0;
        case(state)
            IDLE: begin
                if(start) begin
                    iter_cnt <= 0;
                    state <= INIT;
                end
            end


            INIT: begin
                for(i=0;i<N;i=i+1) begin
                    if(i==0)
                        P_cur[i] <= 11'sd512;
                    else
                        P_cur[i] <= 0;
                end
                j <= 0;
                state <= RUN;
            end


            RUN: begin
                if(j == N-1) begin
                    j <= 0;
                    state <= WAIT;
                end
                else begin
                    j <= j + 1;
                end
            end


            WAIT: begin
		if(mac_done[0]) begin
                state <= CHECK;
		end
            end


            CHECK: begin
                if(mac_done[0]) begin
                    for(i=0;i<N;i=i+1) begin
                        P_cur[i] <= DW'(mac_out[i] >>> 9);

                    end

                    if(iter_cnt == N_ITER-1) begin
                        for(i=0;i<N;i=i+1)
                            P_out[i] <= DW' (mac_out[i] >>> 9);
                        state <= FINISH;
                    end else begin
                        iter_cnt <= iter_cnt + 1;
                        j <= 0;
                        state <= RUN;
                    end
                end
            end
            FINISH: begin
                done <= 1;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end

        endcase
    end
end


endmodule
