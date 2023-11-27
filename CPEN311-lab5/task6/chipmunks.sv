`timescale 1ps/1ps

//state machine states
`define wait_request 4'b0000
`define read_flash_mem 4'b0001
`define store_samples 4'b0010
`define write_sample1 4'b0011
`define wait_ready_low1 4'b0100
`define write_sample2 4'b0101
`define wait_ready_low2 4'b0110

//switch states that will define playback speed
`define chipmunk 2'b01
`define laidback 2'b10

module chipmunks(input CLOCK_50, input CLOCK2_50, input [3:0] KEY, input [9:0] SW,
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
reg signed [15:0] sample1_input; //inputted sample into the left and right writedatas for the high sample (sample 1)
reg signed [15:0] sample2_input; //inputted sample into the left and right writedatas for the high sample (sample 2)
reg [1:0] speed; //one hot code to define playback
reg [1:0] mode; //just instantiating mode

//assigning variables
assign flash_mem_byteenable = 4'b1111; //The lab specified to set all bits to 1
assign reset = ~(KEY[3]); //reset button is KEY[3] active-low from sound.sv "The audio core requires an active high reset signal"
assign read_s = 1'b0; //The lab specified to keep this bit off
assign rst_n = KEY[3];
assign clk = CLOCK_50;

//keep track of the playback mode
assign mode = SW[1:0];

logic [1:0] slow_counter;
always_ff @(posedge CLOCK_50) begin
    if (~rst_n) begin //synchronous reset
        //initialize regs
        flash_mem_address <= 0;
        flash_mem_read <= 0;
        write_s <= 0;
        state <= `wait_request;
        slow_counter <= 0;
    end else begin
        case(state)
            `wait_request: begin
                if (!flash_mem_waitrequest) begin //waits for wait request to be set to 1'b0 
                    flash_mem_address <= flash_mem_address;
                    flash_mem_read <= 0;
                    write_s <= 0;
                    state <= `read_flash_mem;
                    slow_counter <= 0;
                end else begin
                    flash_mem_address <= flash_mem_address;
                    flash_mem_read <= 0;
                    write_s <= 0;
                    state <= `wait_request;
                    slow_counter <= 0;
                end
            end
            `read_flash_mem: begin
                flash_mem_read <= 1; //ready to read flash_mem
                state <= `store_samples;
            end
            `store_samples: begin
                if (flash_mem_readdatavalid) begin //if data read is valid
                    //******************************************************************************
                    if (mode == `chipmunk) begin
                        state <= `write_sample2;
                    end else begin
                        state <= `write_sample1;
                    end
                    //******************************************************************************
                    flash_mem_read = 0; //no longer reading flash_mem
                    //dividing sample inputs by 64 before sending to CODEC to so it's not loud
                    sample1_input <= signed'(flash_mem_readdata[15:0])/signed'(64);
                    sample2_input <= signed'(flash_mem_readdata[31:16])/signed'(64);
                end else begin
                    state <= `store_samples;
                    flash_mem_read = 1;
                    sample1_input <= 0;
                    sample2_input <= 0;
                end
            end
            `write_sample1: begin
                if (write_ready) begin //once write_ready is enabled
                    //******************************************************************************
                    if (mode == `chipmunk) begin
                        state <= `wait_ready_low2;
                        slow_counter <= slow_counter + 1;
                    end else if (mode == `laidback) begin //increment slow counter in slow state
                        state <= `wait_ready_low1;
                        slow_counter <= slow_counter + 1;
                    end else begin
                        state <= `wait_ready_low1;
                        slow_counter <= slow_counter + 1;
                    end
                    //******************************************************************************
                    write_s <= 1; //write sample data to CODEC
                    writedata_left <= sample1_input;
                    writedata_right <= sample1_input;
                end else begin
                    write_s <= 0;
                    writedata_left <= 0;
                    writedata_right <= 0;
                    state <= `write_sample1;
                end
            end
            `wait_ready_low1: begin
                if (!write_ready) begin //wait for write_ready to go low
                    //******************************************************************************
                    if (mode == `chipmunk) begin
                        state <= `wait_ready_low2;
                        slow_counter <= 2'b00;
                    end else if (mode == `laidback && slow_counter == 2'b01) begin
                        state <= `write_sample1;
                    end else begin
                        state <= `write_sample2;
                        slow_counter <= 2'b00;
                    end
                    //******************************************************************************
                end else begin
                    state <= `wait_ready_low1;
                end
            end
            `write_sample2: begin
                if (write_ready) begin
                    //******************************************************************************
                    if (mode == `laidback) begin
                        slow_counter <= slow_counter + 1;
                    end else begin
                        slow_counter <= slow_counter + 1;
                    end
                    //******************************************************************************
                    write_s <= 1; //write sample data to CODEC
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
            `wait_ready_low2: begin //wait for write_ready to go low
                 if (!write_ready) begin
                    //******************************************************************************
                    if (mode == `laidback && slow_counter == 2'b01) begin
                        state <= `write_sample2;
                    end else begin
                        state <= `wait_request;
                        slow_counter <= 2'b00;
                    end
                    //******************************************************************************
                    flash_mem_read <= 0;
                    if (flash_mem_address < 1048576) begin ////keeps looping until all addresses have been read, there are 2097152 samples so 2097152 / 2 addresses
                        flash_mem_address <= flash_mem_address + 1;
                    end else begin
                        flash_mem_address <= 0; //once it reads all addresses restart and begin loop again
                    end
                end else begin
                    state <= `wait_ready_low2;
                end
            end
            default: begin
                state <= 4'bxxxx; //default case, should never happen
            end
        endcase
    end
end
endmodule: chipmunks
