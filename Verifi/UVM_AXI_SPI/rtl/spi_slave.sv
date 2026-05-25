`timescale 1ns / 1ps


module spi_slave (
    input  logic       clk,
    input  logic       sclk,
    input  logic       reset,
    input  logic       mosi,
    input  logic       cs_n,
    input  logic [7:0] tx_data,
    input  logic       cpol,
    input  logic       cpha,
    output logic       done,
    output logic       busy,
    output logic [7:0] rx_data,
    output logic       miso

);





    typedef enum logic [1:0] {
        IDLE = 2'b00,
        DATA,
        STOP
    } spi_state_e;

    spi_state_e state;

    logic [2:0] bit_cnt;
    logic [7:0] tx_shift_reg, rx_shift_reg;


    logic sclk_0, sclk_1;
    logic cs_n_1, cs_n_0;

    logic sclk_pose;
    logic sclk_neg;

    logic rx_edge;
    logic tx_edge;


    assign sclk_pose = (sclk_1 == 1'b0) && (sclk_0 == 1'b1);   // make a posedge detect
    assign sclk_neg = (sclk_1 == 1'b1) && (sclk_0 == 1'b0);  // make a negedge detect

    assign rx_edge = (cpol == cpha) ? sclk_pose : sclk_neg;  // pose -> rx, neg -> tx
    assign tx_edge = (cpol == cpha) ? sclk_neg : sclk_pose;  // neg -> rx, pose -> tx

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            bit_cnt      <= 3'd0;
            busy         <= 1'b0;
            done         <= 1'b0;
            busy         <= 1'b0;
            rx_data      <= 8'h00;
            miso         <= 1'b1;
            tx_shift_reg <= 8'h00;
            rx_shift_reg <= 8'h00;
        end else begin
            sclk_0 <= sclk;
            sclk_1 <= sclk_0;
            //
            cs_n_0 <= cs_n;
            cs_n_1 <= cs_n_0; 
            if (cs_n_1) begin
                state <= IDLE;
                done <= 1'b0;
                busy <= 1'b0;
                miso <= 1'b1;
            end
            case (state)
                IDLE: begin
                    miso <= 1'b1;
                    done <= 1'b0;
                    tx_shift_reg <= 8'h00;
                    if (cs_n_1 == 1'b0) begin
                        miso         <= tx_data[7];
                        tx_shift_reg <= {tx_data[6:0], 1'b0};
                        bit_cnt      <= 3'd0;
                        busy         <= 1'b1;
                        state        <= DATA;
                    end
                end
                DATA: begin
                    if (rx_edge) begin  //  receive 
                        if (bit_cnt == 7) begin
                            rx_data <= {rx_shift_reg[6:0], mosi};
                            bit_cnt <= 3'd0;
                            state   <= STOP;
                        end else begin
                            rx_shift_reg <= {rx_shift_reg[6:0], mosi};
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                    if (tx_edge) begin  // transmit               
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        miso <= tx_shift_reg[7];
                    end
                end


                STOP: begin
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end



endmodule
