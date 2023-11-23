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

logic [7:0] s_addr;
logic [31:0] keeper;
logic signed [15:0] s_wrdata, s_readdata;
logic s_wren;

s_mem samples(.address(s_addr), .clock(clk), .data(s_wrdata), .wren(s_wren), .q(s_readdata));

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
            flash_mem_address <= 23'd0;  
            keeper <= 32'd0;
            flash_mem_read <= 0;
            s_wrdata <= 0;
            s_wren <= 0;
            s_addr <= 8'd0;
            HEX0 = 7'b0000000;
        end
        `readram: begin
            if (~flash_mem_waitrequest) begin
                flash_mem_address <= flash_mem_address;
                keeper <= keeper;
                flash_mem_read <= 1;
                s_wrdata <= 0;
                s_wren <= 0;
                s_addr <= s_addr;

            end else begin
                flash_mem_address <= flash_mem_address;
                keeper <= keeper;
                flash_mem_read <= 1;
                s_wrdata <= 0;
                s_wren <= 0;
                s_addr <= s_addr;
  
            end
        end
        `writeaddr1: begin
            if (flash_mem_readdatavalid) begin
                flash_mem_address <= flash_mem_address;
                keeper <= flash_mem_readdata; //if the read data is valid, store the data
                flash_mem_read <= 1;
                s_wrdata <= flash_mem_readdata[15:0]; //assign s_wrdata to readdata
                s_wren <= 1; //WRITE ENABLE ON
                s_addr <= s_addr;
                if (flash_mem_readdata != 32'd0) begin
                    HEX0 = 7'b1111001;
                end

            end else begin
                flash_mem_address <= flash_mem_address;
                keeper <= keeper;
                flash_mem_read <= 1;
                s_wrdata <= 0;
                s_wren <= 0;
                s_addr <= s_addr;
                
            end
        end
        `writeaddr2: begin
            flash_mem_address <= flash_mem_address;

            keeper <= keeper;
            flash_mem_read <= 0;
            s_wrdata <= keeper[31:16]; //assign s_wrdata to stored data
            s_wren <= 1;
            s_addr <= s_addr + 1;

        end
        `increment: begin
            flash_mem_address <= flash_mem_address + 1;
            keeper <= keeper;
            flash_mem_read <= 0;
            s_wrdata <= 0;
            s_wren <= 0;
            s_addr <= s_addr + 1;
     
        end
        `done: begin
            flash_mem_address <= flash_mem_address;
            keeper <= keeper;
            flash_mem_read <= 0;
            s_wrdata <= 0;
            s_wren <= 0;
            s_addr <= s_addr;
 
        end
        default: begin
            flash_mem_address <= flash_mem_address;
            keeper <= keeper;
            flash_mem_read <= 0;
            s_wrdata <= 0;
            s_wren <= 0;
            s_addr <= s_addr;
    
        end
    endcase
end

always_comb begin
    case(state)
        `start: begin
            if (~flash_mem_waitrequest) begin //move on from start if wait request is 0
                nextstate = `readram;         
            end else begin
                nextstate = `start;
            end
        end
        `readram: begin
            if (~flash_mem_waitrequest) begin 
                nextstate = `writeaddr1;         
            end else begin
                nextstate = `readram;
            end
            
        end
        `writeaddr1: begin
            if (flash_mem_readdatavalid) begin
                nextstate = `writeaddr2;
                
            end else begin
                nextstate = `writeaddr1;
                
            end
        end
        `writeaddr2: begin
            if (flash_mem_address == 'd127) begin //stop when half of 255
                nextstate = `done;
                
            end else begin
                nextstate = `increment;

            end
        end
        `increment: begin
            nextstate = `readram;
            
        end
        `done: begin
            nextstate = `done;
           
        end
        default: begin
            nextstate = `start;
            
        end
    endcase
end


endmodule: flash_reader
