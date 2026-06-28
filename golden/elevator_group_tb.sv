`timescale 1ns / 1ps

module elevator_group_tb;

    localparam int NUM_LIFTS  = 4;
    localparam int NUM_FLOORS = 8;

    logic clk;
    logic reset;

    logic hall_req_valid;
    logic [2:0] hall_req_floor;
    logic hall_req_up;

    logic [7:0] hall_up_buttons;
    logic [7:0] hall_down_buttons;

    logic [7:0] cabin_buttons [NUM_LIFTS];

    logic [NUM_LIFTS-1:0] emergency_stop;
    logic [NUM_LIFTS-1:0] door_obstructed;

    logic door_open [NUM_LIFTS];
    logic idle [NUM_LIFTS];
    logic moving_up [NUM_LIFTS];
    logic moving_down [NUM_LIFTS];
    logic service_dir_up [NUM_LIFTS];
    logic service_dir_down [NUM_LIFTS];
    logic [2:0] current_floor [NUM_LIFTS];
    logic [7:0] pending_requests [NUM_LIFTS];
    logic [2:0] max_request [NUM_LIFTS];
    logic [2:0] min_request [NUM_LIFTS];
    logic estop_latched [NUM_LIFTS];
    logic [2:0] fsm_state [NUM_LIFTS];

    logic [1:0] last_assigned_lift;
    logic [2:0] last_assigned_floor;
    logic last_assigned_up;
    logic hall_queue_full;
    logic [3:0] hall_queue_count;

    elevator_group #(
        .NUM_LIFTS(NUM_LIFTS),
        .NUM_FLOORS(NUM_FLOORS),
        .DOOR_OPEN_CYCLES(4)
    ) dut (
        .clk(clk),
        .reset(reset),
        .hall_req_valid(hall_req_valid),
        .hall_req_floor(hall_req_floor),
        .hall_req_up(hall_req_up),
        .hall_up_buttons(hall_up_buttons),
        .hall_down_buttons(hall_down_buttons),
        .cabin_buttons(cabin_buttons),
        .emergency_stop(emergency_stop),
        .door_obstructed(door_obstructed),
        .door_open(door_open),
        .idle(idle),
        .moving_up(moving_up),
        .moving_down(moving_down),
        .service_dir_up(service_dir_up),
        .service_dir_down(service_dir_down),
        .current_floor(current_floor),
        .pending_requests(pending_requests),
        .max_request(max_request),
        .min_request(min_request),
        .estop_latched(estop_latched),
        .fsm_state(fsm_state),
        .last_assigned_lift(last_assigned_lift),
        .last_assigned_floor(last_assigned_floor),
        .last_assigned_up(last_assigned_up),
        .hall_queue_full(hall_queue_full),
        .hall_queue_count(hall_queue_count)
    );

    task automatic hall_call(input logic [2:0] floor, input logic up = 1'b1);
        begin
            @(negedge clk);
            hall_req_valid = 1'b1;
            hall_req_floor = floor;
            hall_req_up    = up;
            @(negedge clk);
            hall_req_valid = 1'b0;
        end
    endtask

    task automatic cabin_call(input int lift, input logic [2:0] floor);
        begin
            @(negedge clk);
            cabin_buttons[lift][floor] = 1'b1;
            @(negedge clk);
            cabin_buttons[lift][floor] = 1'b0;
        end
    endtask

    initial begin
        clk               = 1'b0;
        reset             = 1'b1;
        hall_req_valid    = 1'b0;
        hall_req_floor    = 3'd0;
        hall_req_up       = 1'b1;
        hall_up_buttons   = 8'h00;
        hall_down_buttons = 8'h00;
        emergency_stop    = '0;
        door_obstructed   = '0;

        for (int i = 0; i < NUM_LIFTS; i++) begin
            cabin_buttons[i] = 8'h00;
        end

        #20 reset = 1'b0;

        // Scenario 1: all lifts idle at floor 0, hall calls should rotate via round-robin
        hall_call(3'd5);
        repeat (20) @(negedge clk);
        hall_call(3'd2);
        repeat (20) @(negedge clk);

        // Scenario 2: cabin call inside lift 1
        cabin_call(1, 3'd6);
        repeat (40) @(negedge clk);

        // Scenario 3: simultaneous hall calls while lifts spread out
        hall_call(3'd7);
        hall_call(3'd1, 1'b0);
        repeat (80) @(negedge clk);

        $display("Done. Floors: L0=%0d L1=%0d L2=%0d L3=%0d",
                 current_floor[0], current_floor[1], current_floor[2], current_floor[3]);
        $finish;
    end

    initial begin
        $monitor(
            "t=%0t q=%0d asg=L%0d@f%0d idle=%b%b%b%b fl=%0d %0d %0d %0d",
            $time,
            hall_queue_count,
            last_assigned_lift,
            last_assigned_floor,
            idle[0], idle[1], idle[2], idle[3],
            current_floor[0], current_floor[1], current_floor[2], current_floor[3]
        );
    end

    always #5 clk = ~clk;

endmodule
