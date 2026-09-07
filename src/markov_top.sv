module markov_top #(
    parameter N      = 6,
    parameter DW     = 11,
    parameter ACC_W  = 32,
    parameter N_ITER = 10
)(
    input  logic clk,
    input  logic rst_n,

    input  logic start,
    output logic done,

    input  logic rd_en,
    input  logic [$clog2(N)-1:0] rd_addr,
    output logic signed [DW-1:0] rd_data
);

    localparam CNT_W  = (N <= 1) ? 1 : $clog2(N);
    localparam ITER_W = (N_ITER <= 1) ? 1 : $clog2(N_ITER + 1);
    localparam ADDR_W = (N <= 1) ? 1 : $clog2(N*N);

    // ================================================================
    // Probability vectors
    //
    // P_cur  = input vector for current Markov iteration
    // P_next = output vector being calculated
    // P_out  = completed result exposed through rd_data
    // ================================================================

    logic signed [DW-1:0] P_cur  [0:N-1];
    logic signed [DW-1:0] P_next [0:N-1];
    logic signed [DW-1:0] P_out  [0:N-1];

    // ================================================================
    // Single transition memory
    // ================================================================

    logic [ADDR_W-1:0] transition_addr;
    logic signed [DW-1:0] transition_data;

    // ================================================================
    // Single MAC
    // ================================================================

    logic signed [DW-1:0] mac_a;
    logic signed [DW-1:0] mac_b;

    logic signed [ACC_W-1:0] mac_result;

    logic mac_valid_in;
    logic mac_clear;
    logic mac_valid;

    // ================================================================
    // Counters
    //
    // output_idx:
    //     Which output element P_next[] are we calculating?
    //
    // input_idx:
    //     Which P_cur[] element are we multiplying?
    //
    // Example:
    //
    // output_idx = 2
    // input_idx  = 4
    //
    // means:
    //
    //     P_cur[4] * T[4][2]
    // ================================================================

    logic [CNT_W-1:0] output_idx;
    logic [CNT_W-1:0] input_idx;

    logic [ITER_W-1:0] iter_cnt;

    integer i;

    // ================================================================
    // FSM
    // ================================================================

    typedef enum logic [3:0] {
        IDLE,
        INIT,
        MAC_START,
        MAC_WAIT,
        STORE,
        ITER_DONE,
        DONE
    } state_t;

    state_t state;

    // ================================================================
    // Transition matrix addressing
    //
    // The original design uses:
    //
    //     transition_addr[g] = col*N + g
    //
    // where:
    //
    //     col = input state
    //     g   = output state
    //
    // Therefore the original calculation is:
    //
    //     P_cur[col] * T[col][g]
    //
    // We preserve exactly that ordering here:
    //
    //     address = input_idx * N + output_idx
    // ================================================================

    assign transition_addr =
        input_idx * N + output_idx;

    // ================================================================
    // MAC inputs
    // ================================================================

    assign mac_a = transition_data;
    assign mac_b = P_cur[input_idx];

    // ================================================================
    // Single transition memory
    // ================================================================

    transition_mem #(
        .N(N),
        .DW(DW)
    ) transition_inst (
        .addr(transition_addr),
        .data(transition_data)
    );

    // ================================================================
    // Single MAC
    // ================================================================

    mac_unit #(
        .DW(DW),
        .ACC_W(ACC_W)
    ) mac_inst (
        .clk(clk),
        .rst_n(rst_n),

        .a(mac_a),
        .b(mac_b),

        .valid_in(mac_valid_in),
        .clear_acc(mac_clear),

        .acc_out(mac_result),
        .valid_out(mac_valid)
    );

    // ================================================================
    // MAC control
    //
    // The first multiply for each output clears the accumulator.
    //
    // Subsequent multiplies accumulate into it.
    // ================================================================

    always_comb begin
        mac_valid_in = 1'b0;
        mac_clear    = 1'b0;

        if (state == MAC_START) begin

            mac_valid_in = 1'b1;

            if (input_idx == 0)
                mac_clear = 1'b1;

        end
    end

    // ================================================================
    // Main FSM
    // ================================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state      <= IDLE;
            output_idx <= '0;
            input_idx  <= '0;
            iter_cnt   <= '0;
            done       <= 1'b0;

            for (i = 0; i < N; i = i + 1) begin
                P_cur[i]  <= '0;
                P_next[i] <= '0;
                P_out[i]  <= '0;
            end

        end else begin

            done <= 1'b0;

            case (state)

                // ----------------------------------------------------
                // IDLE
                // ----------------------------------------------------

                IDLE: begin

                    if (start) begin
                        iter_cnt <= '0;
                        state    <= INIT;
                    end

                end

                // ----------------------------------------------------
                // INIT
                //
                // Initial probability vector:
                //
                //     P_cur = [512, 0, 0, 0, 0, 0]
                //
                // 512 represents 1.0 in Q9 fixed point.
                // ----------------------------------------------------

                INIT: begin

                    for (i = 0; i < N; i = i + 1) begin

                        if (i == 0)
                            P_cur[i] <= 11'sd512;
                        else
                            P_cur[i] <= '0;

                        P_next[i] <= '0;
                        P_out[i]  <= '0;

                    end

                    output_idx <= '0;
                    input_idx  <= '0;

                    state <= MAC_START;

                end

                // ----------------------------------------------------
                // MAC_START
                //
                // Launch one multiplication.
                //
                // The current input/output indices remain unchanged
                // until MAC_WAIT completes.
                // ----------------------------------------------------

                MAC_START: begin

                    state <= MAC_WAIT;

                end

                // ----------------------------------------------------
                // MAC_WAIT
                //
                // Wait for the one-cycle MAC pipeline.
                // ----------------------------------------------------

                MAC_WAIT: begin

                    if (mac_valid) begin

                        if (input_idx == N-1) begin

                            // All N terms for this output have now
                            // been accumulated.
                            state <= STORE;

                        end else begin

                            input_idx <= input_idx + 1'b1;
                            state     <= MAC_START;

                        end

                    end

                end

                // ----------------------------------------------------
                // STORE
                //
                // mac_result contains:
                //
                //   sum(P_cur[i] * T[i][output_idx])
                //
                // Convert from Q18-ish product scaling back to
                // Q9 by shifting right by 9.
                //
                // IMPORTANT:
                //
                // Store into P_next, NOT P_cur.
                //
                // This guarantees every output uses the same P_cur
                // vector for the entire Markov iteration.
                // ----------------------------------------------------

                STORE: begin

                    P_next[output_idx] <= mac_result >>> 9;

                    if (output_idx == N-1) begin

                        state <= ITER_DONE;

                    end else begin

                        output_idx <= output_idx + 1'b1;
                        input_idx  <= '0;

                        state <= MAC_START;

                    end

                end

                // ----------------------------------------------------
                // ITER_DONE
                //
                // All six P_next values have been calculated.
                //
                // Now copy P_next -> P_cur for the next iteration.
                //
                // For the final iteration, also copy to P_out.
                // ----------------------------------------------------

                ITER_DONE: begin

                    for (i = 0; i < N; i = i + 1) begin
                        P_cur[i] <= P_next[i];
                    end

                    if (iter_cnt == N_ITER-1) begin

                        for (i = 0; i < N; i = i + 1) begin
                            P_out[i] <= P_next[i];
                        end

                        state <= DONE;

                    end else begin

                        iter_cnt   <= iter_cnt + 1'b1;
                        output_idx <= '0;
                        input_idx  <= '0;

                        state <= MAC_START;

                    end

                end

                // ----------------------------------------------------
                // DONE
                // ----------------------------------------------------

                DONE: begin

                    done  <= 1'b1;
                    state <= IDLE;

                end

                // ----------------------------------------------------
                // Safety
                // ----------------------------------------------------

                default: begin
                    state <= IDLE;
                end

            endcase

        end

    end

    // ================================================================
    // Readback
    // ================================================================

    assign rd_data = rd_en ? P_out[rd_addr] : '0;

endmodule
