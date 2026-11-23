//============================================================================
//  Run time phase adjustment of two PLL outputs (Cyclone III / IV / 10 LP)
//
//  Moves c0 (SDRAM_CLK) and c4 one step at a time (1/8 of the VCO period:
//  132.3 ps with the 945 MHz VCO of mist/pll_lc.v) until they reach the
//  offsets asked for, relative to the phase compiled into the PLL. From the
//  Calypso port; SNES_MiST_LC only uses c0. Dynamic phase steps are
//  glitch free, so it is done while the core runs: the OSD option can be
//  changed while watching the game.
//
//  Shaeon (Carlos Palmero), 2026
//============================================================================

module pll_phase (
    input               clk,            // also the PLL scanclk
    input               locked,

    input  signed [6:0] c0_target,      // steps
    input  signed [6:0] c4_target,

    output reg    [2:0] cntsel,
    output reg          updown,
    output reg          step,
    input               done,

    output              settled         // both outputs are at their targets
);

localparam [2:0] SEL_C0 = 3'b010;
localparam [2:0] SEL_C4 = 3'b110;

reg signed [6:0] c0_cur = 7'sd0, c4_cur = 7'sd0;
reg        [2:0] state = 3'd0;
reg        [5:0] tmo;
reg        [1:0] done_s;
reg              which;           // 0 = c0, 1 = c4

assign settled = locked && state == 3'd0 && c0_cur == c0_target && c4_cur == c4_target;

always @(posedge clk) begin
    done_s <= {done_s[0], done};

    if (!locked) begin
        // the PLL restarts from the compiled phases
        c0_cur <= 7'sd0;
        c4_cur <= 7'sd0;
        state  <= 3'd0;
        step   <= 1'b0;
    end else case (state)
    3'd0: begin
        step <= 1'b0;
        if (c0_cur != c0_target) begin
            which  <= 1'b0;
            cntsel <= SEL_C0;
            updown <= c0_target > c0_cur;
            state  <= 3'd1;
        end else if (c4_cur != c4_target) begin
            which  <= 1'b1;
            cntsel <= SEL_C4;
            updown <= c4_target > c4_cur;
            state  <= 3'd1;
        end
        tmo <= 0;
    end
    3'd1: state <= 3'd2;              // counter select and direction settle
    3'd2: begin                       // phasestep high until phasedone drops
        step <= 1'b1;
        tmo  <= tmo + 1'd1;
        if ((!done_s[1] && tmo > 6'd3) || &tmo) begin
            step  <= 1'b0;
            tmo   <= 0;
            state <= 3'd3;
        end
    end
    3'd3: begin                       // wait for phasedone high again
        tmo <= tmo + 1'd1;
        if (done_s[1] || &tmo) begin
            if (!which) c0_cur <= updown ? c0_cur + 7'sd1 : c0_cur - 7'sd1;
            else        c4_cur <= updown ? c4_cur + 7'sd1 : c4_cur - 7'sd1;
            state <= 3'd4;
        end
    end
    3'd4: state <= 3'd0;              // one idle cycle between steps
    default: state <= 3'd0;
    endcase
end

endmodule
