`timescale 1ns / 1ps

module elevator_controller_tb;

    logic clk;
    logic reset;
    logic req_valid;
    logic [2:0] req_floor;
    logic req_cabin;
    logic req_hall_up;
    logic [7:0] cabin_buttons;
    logic [7:0] hall_up_buttons;
    logic [7:0] hall_down_buttons;
    logic emergency_stop;
    logic top_limit;
    logic bottom_limit;
    logic door_obstructed;

    logic door_open;
    logic idle;
    logic moving_up;
    logic moving_down;
    logic service_dir_up;
    logic service_dir_down;
    logic [2:0] current_floor;
    logic [7:0] pending_requests;
    logic [7:0] transit_hall_pending;
    logic [2:0] max_request;
    logic [2:0] min_request;
    logic estop_latched;
    logic [2:0] fsm_state;

    elevator_controller #(
        .NUM_FLOORS(8),
        .DOOR_OPEN_CYCLES(4)
    ) dut (
        .clk(clk),
        .reset(reset),
        .req_valid(req_valid),
        .req_floor(req_floor),
        .req_cabin(req_cabin),
        .req_hall_up(req_hall_up),
        .cabin_buttons(cabin_buttons),
        .hall_up_buttons(hall_up_buttons),
        .hall_down_buttons(hall_down_buttons),
        .emergency_stop(emergency_stop),
        .top_limit(top_limit),
        .bottom_limit(bottom_limit),
        .door_obstructed(door_obstructed),
        .door_open(door_open),
        .idle(idle),
        .moving_up(moving_up),
        .moving_down(moving_down),
        .service_dir_up(service_dir_up),
        .service_dir_down(service_dir_down),
        .current_floor(current_floor),
        .pending_requests(pending_requests),
        .transit_hall_pending(transit_hall_pending),
        .max_request(max_request),
        .min_request(min_request),
        .estop_latched(estop_latched),
        .fsm_state(fsm_state)
    );

    task automatic pulse_request(input logic [2:0] floor, input logic cabin = 1'b1, input logic hall_up = 1'b0);
        begin
            @(negedge clk);
            req_valid   <= 1'b1;
            req_floor   <= floor;
            req_cabin   <= cabin;
            req_hall_up <= hall_up;
            @(negedge clk);
            req_valid   <= 1'b0;
        end
    endtask

    initial begin
        clk               = 1'b0;
        reset             = 1'b1;
        req_valid         = 1'b0;
        req_floor         = 3'd0;
        req_cabin         = 1'b1;
        req_hall_up       = 1'b0;
        cabin_buttons     = 8'h00;
        hall_up_buttons   = 8'h00;
        hall_down_buttons = 8'h00;
        emergency_stop    = 1'b0;
        door_obstructed   = 1'b0;
        top_limit         = 1'b0;
        bottom_limit      = 1'b0;

        #20 reset = 1'b0;

        pulse_request(3'd1);
        repeat (20) @(negedge clk);
        pulse_request(3'd4);
        repeat (10) @(negedge clk);
        pulse_request(3'd3);
        repeat (10) @(negedge clk);
        pulse_request(3'd7);

        repeat (10) @(negedge clk);
        emergency_stop = 1'b1;
        repeat (4) @(negedge clk);
        emergency_stop = 1'b0;

        repeat (10) @(negedge clk);
        pulse_request(3'd2);
        repeat (30) @(negedge clk);

        $display("Simulation finished at floor %0d, requests=%b", current_floor, pending_requests);
        $finish;
    end

    initial begin
        $monitor(
            "t=%0t floor=%0d state=%0d idle=%b up=%b down=%b door=%b req=%b max=%0d min=%0d",
            $time,
            current_floor,
            fsm_state,
            idle,
            moving_up,
            moving_down,
            door_open,
            pending_requests,
            max_request,
            min_request
        );
    end

    always #5 clk = ~clk;

    always_comb begin
        top_limit    = (current_floor == 3'd7);
        bottom_limit = (current_floor == 3'd0);
    end

endmodule
