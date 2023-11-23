`define init 3'b000
`define wait_request 3'b001
`define wait_ready_high 3'b010
`define write_sample 3'b011
`define wait_ready_low 3'b100
`define done 3'b101 //not sure if we need this, this is just to check we have gone through all samples (reached the end of the loop)

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
logic [3:0] state, nextstate; //states
logic sample_bits; //making 0 = the first 16 bits and 1 = the last 16 bits of the 32 bit sample
reg signed [15:0] sample_input; //inputted sample into the left and right writedatas. value depends on sample_bits flag

//assigning variables
assign flash_mem_byteenable = 4'b1111; //The lab specified to set all bits to 1
assign reset = ~(KEY[3]); //reset button is KEY[3] active-low from sound.sv "The audio core requires an active high reset signal"
assign read_s = 1'b0; //The lab specified to keep this bit off
assign rst_n = KEY[3];
assign clk = CLOCK_50;

always_ff @(posedge CLOCK_50) begin
    if (~rst_n) begin //synchronous reset
        state <= `init;
    end else begin
        state <= nextstate;
    end
end

always_ff @(posedge CLOCK_50) begin
    case(state)
        `init: begin //initialize regs
            write_s <= 0;
            flash_mem_read <= 1; //ready to read
            flash_mem_address <= 0;
            sample_bits <= 0; //start with the low 16 bits first
            nextstate <= `wait_request;
        end
        `wait_request: begin //waits for wait request to be set to 1'b0 (flash is ready for read request)
            if (!flash_mem_waitrequest && flash_mem_readdatavalid) begin //if waitrequest 1'b0 and datavalid = 1'b1 (flash is ready for read request and data is valid), ask lisa how readdata_valid works
                nextstate <= `wait_ready;
            end else begin
                nextstate <= `wait_request; //else stay in the same state
            end
        end
        `wait_ready_high: begin
            sample <= flash_mem_readdata; //sample gets readdata
            if (write_ready) begin //if ready to write go to write_sample state
                nextstate <= `write_sample;
                flash_mem_read <= 0; //no longer ready to read
            end else begin //else stay in the state
                nextstate <= `wait_ready;
                flash_mem_read <= 1; //still ready to read
            end
        end
        `write_sample: begin
            if (sample_bits) begin //making 0 = the first 16 bits and 1 = the last 16 bits of the 32 bit sample
                sample_input = sample[31:16]/signed'(16'd64); //samples divided by 64 before sending to CODEC to so it's not loud
            end else begin
                sample_input = sample[15:0]/signed'(16'd64);
            end
            writedata_left <= sample_input;
            writedata_right <= sample_input;
            write_s <= 1; //write to CODEC
            nextstate <= `wait_ready_low;
        end
        `wait_ready_low: begin
            if (!wait_ready) begin //wait until ready is low, we are waiting for the write to go through
                //add in shit
            end else begin
                nextstate <= `wait_ready_low; //stay in state until wait_ready = 0
            end
        end
    endcase
end

endmodule: music
