`timescale 1ps/1ps

`define wait_request 4'b0000
`define read_flash_mem 4'b0001
`define store_samples 4'b0010
`define write_sample1 4'b0011
`define wait_ready_low1 4'b0100
`define write_sample2 4'b0101
`define wait_ready_low2 4'b0110

module music(input CLOCK_50, input CLOCK2_50, input [3:0] KEY, input [9:0] SW,
             input AUD_DACLRCK, input AUD_ADCLRCK, input AUD_BCLK, input AUD_ADCDAT,
             inout FPGA_I2C_SDAT, output FPGA_I2C_SCLK, output AUD_DACDAT, output AUD_XCK,
             output [6:0] HEX0, output [6:0] HEX1, output [6:0] HEX2,
             output [6:0] HEX3, output [6:0] HEX4, output [6:0] HEX5,
             output [9:0] LEDR);
			
// signals that are used to communicate with the audio core
// DO NOT alter these -- we will use them to test your design

reg read_ready, write_ready, write_s;
reg [15:0] writedata_left, writedata_right;
reg [15:0] readdata_left, readdata_right;	
wire reset, read_s;

// signals that are used to communicate with the flash core
// DO NOT alter these -- we will use them to test your design

reg flash_mem_read;
reg flash_mem_waitrequest;
reg [22:0] flash_mem_address;
reg [31:0] flash_mem_readdata;
reg flash_mem_readdatavalid;
reg [3:0] flash_mem_byteenable;
reg rst_n, clk;

// DO NOT alter the instance names or port names below -- we will use them to test your design

clock_generator my_clock_gen(CLOCK2_50, reset, AUD_XCK);
audio_and_video_config cfg(CLOCK_50, reset, FPGA_I2C_SDAT, FPGA_I2C_SCLK);
audio_codec codec(CLOCK_50,reset,read_s,write_s,writedata_left, writedata_right,AUD_ADCDAT,AUD_BCLK,AUD_ADCLRCK,AUD_DACLRCK,read_ready, write_ready,readdata_left, readdata_right,AUD_DACDAT);
flash flash_inst(.clk_clk(clk), .reset_reset_n(rst_n), .flash_mem_write(1'b0), .flash_mem_burstcount(1'b1),
                 .flash_mem_waitrequest(flash_mem_waitrequest), .flash_mem_read(flash_mem_read), .flash_mem_address(flash_mem_address),
                 .flash_mem_readdata(flash_mem_readdata), .flash_mem_readdatavalid(flash_mem_readdatavalid), .flash_mem_byteenable(flash_mem_byteenable), .flash_mem_writedata());

// your code for the rest of this task here
logic [3:0] state; //states
reg [31:0] sample;
reg done;
reg signed [15:0] sample1_input; //inputted sample into the left and right writedatas for the high sample (sample 1)
reg signed [15:0] sample2_input; //inputted sample into the left and right writedatas for the high sample (sample 2)

//assigning variables
assign flash_mem_byteenable = 4'b1111; //The lab specified to set all bits to 1
assign reset = ~(KEY[3]); //reset button is KEY[3] active-low from sound.sv "The audio core requires an active high reset signal"
assign read_s = 1'b0; //The lab specified to keep this bit off
assign rst_n = KEY[3];
assign clk = CLOCK_50;

always_ff @(posedge CLOCK_50) begin
    if (~rst_n) begin //synchronous reset
        flash_mem_address <= 23'd0;
        flash_mem_read <= 0;
        write_s <= 0;
        done <= 0;
        state <= `wait_request;
    end else begin
        case(state)
            `wait_request: begin
                if (flash_mem_waitrequest == 0) begin
                    flash_mem_address <= flash_mem_address;
                    flash_mem_read <= 0;
                    write_s <= 0;
                    state <= `read_flash_mem;
                end else begin
                    flash_mem_address <= flash_mem_address;
                    flash_mem_read <= 0;
                    write_s <= 0;
                    state <= `wait_request;
                end
            end
            `read_flash_mem: begin
                flash_mem_read <= 1;
                write_s <= 0;
                state <= `store_samples;
            end
            `store_samples: begin
                if (flash_mem_readdatavalid == 1) begin
                    state <= `write_sample1;
                    write_s <= 0;
                    sample1_input <= signed'(flash_mem_readdata[15:0])/signed'(64);
                    sample2_input <= signed'(flash_mem_readdata[31:16])/signed'(64);
                end else begin
                    state <= `store_samples;
                    write_s <= 0;
                    sample1_input <= 0;
                    sample2_input <= 0;
                end
            end
            `write_sample1: begin
                if (write_ready == 1) begin
                    write_s <= 1;
                    writedata_left <= sample1_input;
                    writedata_right <= sample1_input;
                    state <= `wait_ready_low1;
                end else begin
                    write_s <= 0;
                    writedata_left <= 0;
                    writedata_right <= 0;
                    state <= `write_sample1;
                end
            end
            `wait_ready_low1: begin
                if (write_ready == 0) begin
                    state <= `write_sample2;
                end else begin
                    state <= `wait_ready_low1;
                end
            end
            `write_sample2: begin
                if (write_ready == 1) begin
                    write_s <= 1;
                    writedata_left <= sample2_input;
                    writedata_right <= sample2_input;
                    state <= `wait_ready_low2;
                end else begin
                    write_s <= 0;
                    writedata_left <= 0;
                    writedata_right <= 0;
                    state <= `write_sample2;
                end
            end
            `wait_ready_low2: begin
                 if (write_ready == 0) begin
                    state <= `wait_request;
                    flash_mem_read <= 0;
                    if (flash_mem_address < 1048576) begin
                        flash_mem_address <= flash_mem_address + 1;
                    end else begin
                        flash_mem_address <= 0;
                        done <= 1;
                    end
                end else begin
                    state <= `wait_ready_low2;
                end
            end
            default: begin
                state <= 4'bxxxx;
            end
        endcase
    end
end

assign LEDR = {9'd0, done};
endmodule: music