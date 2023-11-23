`timescale 1ps/1ps
`define start 3'b000 
`define readram 3'b001 
`define writeaddr1 3'b010 
`define writeaddr2 3'b011 
`define increment 3'b100 
`define done 3'b101 

module flash_reader(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
                    output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
                    output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
                    output logic [9:0] LEDR);

// You may use the SW/HEX/LEDR ports for debugging. DO NOT delete or rename any ports or signals.

logic clk, rst_n;

assign clk = CLOCK_50;
assign rst_n = KEY[3];

logic flash_mem_read, flash_mem_waitrequest, flash_mem_readdatavalid;
logic [22:0] flash_mem_address;
logic [31:0] flash_mem_readdata; 
logic [3:0] flash_mem_byteenable;

assign flash_mem_byteenable = 4'b1111; //instructions page 2, bottom paragraph
//audio sample is 16 bits
    //therefore every time 32 bit read is done, you will get two samples
    //first audio sample will be in lower order of 16 bits, and next sample will be in upper order

flash flash_inst(.clk_clk(clk), .reset_reset_n(rst_n), .flash_mem_write(1'b0), .flash_mem_burstcount(1'b1),
                 .flash_mem_waitrequest(flash_mem_waitrequest), .flash_mem_read(flash_mem_read), .flash_mem_address(flash_mem_address),
                 .flash_mem_readdata(flash_mem_readdata), .flash_mem_readdatavalid(flash_mem_readdatavalid), .flash_mem_byteenable(flash_mem_byteenable), .flash_mem_writedata());

                //outputs are flash_mem_waitrequest, flash_mem_readdata, and flash_mem_readdatavalid

logic [7:0] s_addr, oc_addr; //I searched for the double of 0x7FFFF
logic [31:0] keeper;
logic signed [15:0] s_wrdata, s_readdata;
logic s_wren;

s_mem samples(.address(s_addr), .clock(CLOCK_50), .data(s_wrdata), .wren(s_wren), .q(s_readdata));

logic [2:0] state, nextstate;

// the rest of your code goes here.  don't forget to instantiate the on-chip memory
always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        state <= `start;
    end else begin
        state <= nextstate;
    end
end


always_ff @(posedge clk) begin
    case(state)
        `start: begin //initialize these variables
            flash_mem_address <= 0;
            oc_addr <= 0; //oc_addr helps us track s_addr
            keeper <= 0;
        end
        `readram: begin
            flash_mem_address <= flash_mem_address;
            oc_addr <= oc_addr;
            keeper <= keeper;
        end
        `writeaddr1: begin
            if (flash_mem_readdatavalid) begin
                flash_mem_address <= flash_mem_address;
                oc_addr <= oc_addr;
                keeper <= flash_mem_readdata; //if the read data is valid, store the data
            end else begin
                flash_mem_address <= flash_mem_address;
                oc_addr <= oc_addr;
                keeper <= keeper;
            end
        end
        `writeaddr2: begin
            flash_mem_address <= flash_mem_address;
            oc_addr <= oc_addr;
            keeper <= keeper;
        end
        `increment: begin
            flash_mem_address <= flash_mem_address + 1;
            oc_addr <= oc_addr + 2;
            keeper <= keeper;
        end
        `done: begin
            flash_mem_address <= flash_mem_address;
            oc_addr <= oc_addr;
            keeper <= keeper;
        end
        default: begin
            flash_mem_address <= flash_mem_address;
            oc_addr <= oc_addr;
            keeper <= keeper;
        end
    endcase
end

always_comb begin
    case(state)
        `start: begin
            if (~flash_mem_waitrequest) begin //move on from start if wait request is 0
                nextstate = `readram;
                flash_mem_read = 0;
                s_wrdata = 0;
                s_wren = 0;
                s_addr = oc_addr;
                HEX0 = 7'b0111111;
            end else begin
                nextstate = `start;
                flash_mem_read = 0;
                s_wrdata = 0;
                s_wren = 0;
                s_addr = oc_addr;
                HEX0 = 7'b0111111;
            end
        end
        `readram: begin
            nextstate = `writeaddr1;
            flash_mem_read = 1;
            s_wrdata = 0;
            s_wren = 0;
            s_addr = oc_addr;
            HEX0 = 7'b0000110;
        end
        `writeaddr1: begin
            if (flash_mem_readdatavalid) begin
                nextstate = `writeaddr2;
                flash_mem_read = 0;
                s_wrdata = flash_mem_readdata[15:0]; //assign s_wrdata to readdata
                s_wren = 1;
                s_addr = oc_addr;
                HEX0 = 7'b1011011;
            end else begin
                nextstate = `writeaddr1;
                flash_mem_read = 0;
                s_wrdata = 0;
                s_wren = 0;
                s_addr = oc_addr;
                HEX0 = 7'b1011011;
            end
        end
        `writeaddr2: begin
            if (flash_mem_address == 'd127) begin //stop when half of 255
                nextstate = `done;
                flash_mem_read = 0;
                s_wrdata = keeper[31:16]; //assign s_wrdata to stored data
                s_wren = 1;
                s_addr = oc_addr + 1;
                HEX0 = 7'b1001111;
            end else begin
                nextstate = `increment;
                flash_mem_read = 0;
                s_wrdata = keeper[31:16]; //assign s_wrdata to stored data
                s_wren = 1;
                s_addr = oc_addr + 1;
                HEX0 = 7'b1001111;
            end
        end
        `increment: begin
            nextstate = `readram;
            flash_mem_read = 0;
            s_wrdata = 0;
            s_wren = 0;
            s_addr = oc_addr;
            HEX0 = 7'b1100110;
        end
        `done: begin
            nextstate = `done;
            flash_mem_read = 0;
            s_wrdata = 0;
            s_wren = 0;
            s_addr = oc_addr;
            HEX0 = 7'b1101101;
        end
        default: begin
            nextstate = `start;
            flash_mem_read = 0;
            s_wrdata = 0;
            s_wren = 0;
            s_addr = oc_addr;
            HEX0 = 7'bxxxxxxx;
        end
    endcase
end


endmodule: flash_reader
