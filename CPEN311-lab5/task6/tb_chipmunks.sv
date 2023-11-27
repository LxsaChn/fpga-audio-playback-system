`timescale 1ps/1ps
`define ready_request 2'b00
`define wait 2'b01
`define out_ok 2'b10
module tb_chipmunks();
logic CLOCK_50;
logic CLOCK2_50;
logic [3:0] KEY;
logic [9:0] SW;
logic AUD_DACLRCK;
logic AUD_ADCLRCK;
logic AUD_BCLK;
logic AUD_ADCDAT;
logic FPGA_I2C_SDAT;
logic FPGA_I2C_SCLK;
logic AUD_DACDAT;
logic AUD_XCK;
logic [6:0] HEX0;
logic [6:0] HEX1;
logic [6:0] HEX2;
logic [6:0] HEX3; 
logic [6:0] HEX4;
logic [6:0] HEX5;
logic LEDR;

chipmunks dut(.CLOCK_50, .CLOCK2_50, .KEY, .SW, .AUD_DACLRCK, .AUD_ADCLRCK, .AUD_BCLK, .AUD_ADCDAT, .FPGA_I2C_SDAT, .FPGA_I2C_SDAT, .AUD_DACDAT, .AUD_XCK, .HEX0, .HEX1, .HEX2, .HEX3, .HEX4, .HEX5, .LEDR);

task reset; KEY[3] = 1'b0; #20; KEY[3] = 1'b1; endtask

initial begin
    CLOCK_50 = 0;
    forever #5 CLOCK_50 = ~CLOCK_50;
end

initial begin
    reset;
    #300000;
    $stop;
end

endmodule: tb_chipmunks

// Any other simulation-only modules you need

module flash(input logic clk_clk, input logic reset_reset_n,
             input logic flash_mem_write, input logic [6:0] flash_mem_burstcount,
             output logic flash_mem_waitrequest, input logic flash_mem_read,
             input logic [22:0] flash_mem_address, output logic [31:0] flash_mem_readdata,
             output logic flash_mem_readdatavalid, input logic [3:0] flash_mem_byteenable,
             input logic [31:0] flash_mem_writedata);

// Your simulation-only flash module goes here.
logic [1:0] state, nextstate;

always_ff @(posedge clk_clk) begin
    if (~reset_reset_n) begin
        state <= `wait;
    end else begin
        state <= nextstate;
    end
end

assign flash_mem_readdata = 32'b11111111111111111111111111111111; //assign so that the output
                                            //is simply just the inputted address 
always_comb begin
    case(state)
        `ready_request: begin
            if (flash_mem_read == 1) begin
                nextstate = `wait;
                flash_mem_waitrequest = 1;
                flash_mem_readdatavalid = 0;
            end else begin
                nextstate = `ready_request;
                flash_mem_waitrequest = 0;
                flash_mem_readdatavalid = 0;
            end
        end
        `wait: begin
            //*************************************************************
            if (flash_mem_read == 1) begin
                nextstate = `out_ok;
                flash_mem_waitrequest = 1;
                flash_mem_readdatavalid = 0;
            end else begin
                nextstate = `ready_request;
                flash_mem_waitrequest = 1;
                flash_mem_readdatavalid = 0;
            end
            //****************************************************************
        end
        `out_ok: begin
            nextstate = `ready_request;
            flash_mem_waitrequest = 0;
            flash_mem_readdatavalid = 1;
        end
        default: begin
            nextstate = 2'bxx;
            flash_mem_waitrequest = 1'bx;
            flash_mem_readdatavalid = 1'bx;
        end
    endcase
end

endmodule: flash