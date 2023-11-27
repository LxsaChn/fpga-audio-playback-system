`timescale 1ps/1ps
`define ready_request 2'b00
`define wait 2'b01
`define out_ok 2'b10
module tb_flash_reader();

// Your testbench goes here.
logic CLOCK_50 = 1'b0;
logic [3:0] KEY;
logic [9:0] SW;
logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
logic [9:0] LEDR;

int num_passes = 0;
int num_fails = 0;

flash_reader dut(.CLOCK_50, .KEY, .SW, .HEX0, .HEX1, .HEX2,
    .HEX3, .HEX4, .HEX5, .LEDR);

task reset; KEY[3] = 1'b0; #20; KEY[3] = 1'b1; endtask

task check_state(input[2:0] exp_val, input string msg);
    assert (exp_val == dut.state) begin
        $display("[PASS] %s: state is %-d", msg, dut.state);
        num_passes = num_passes + 1;
    end else begin
        $error("[FAIL] %s: state is %-d (expected %-d)", msg, dut.state, exp_val);
        num_fails = num_fails + 1;
    end
endtask

initial begin
    CLOCK_50 = 0;
    forever #5 CLOCK_50 = ~CLOCK_50;
end

initial begin
    #7;
    reset;

    $display("=========POST RESET TESTS==========");

    check_state(3'b000, "state is start");

    

    //wait a long time to pass
    #30000;
    check_state(3'b101, "state is done");

    $display("\n\n==== TEST SUMMARY ====");
    $display("  TEST COUNT: %-5d", num_passes + num_fails);
    $display("    - PASSED: %-5d", num_passes);
    $display("    - FAILED: %-5d", num_fails);
    $display("======================\n\n");

    $stop;
end

endmodule: tb_flash_reader

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
                flash_mem_waitrequest = 0;
                flash_mem_readdatavalid = 0;
            end else begin
                nextstate = `ready_request;
                flash_mem_waitrequest = 0;
                flash_mem_readdatavalid = 0;
            end
        end
        `wait: begin
            nextstate = `out_ok;
            flash_mem_waitrequest = 1;
            flash_mem_readdatavalid = 0;
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
