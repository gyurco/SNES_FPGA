//============================================================================
//  SNES top-level for MiST and compatible boards (Mistica...) with the SDRAM
//  at ~86 MHz (4 x clk_sys, CAS latency 2) instead of ~129 MHz
//
//  Memory as in SNESTang (nand2mario) and in the Calypso port
//  (teiram/calypso-ports, snes): a 3 channel interleaved CL2 controller,
//  each channel with its own bank(s) of the 32MB SDRAM:
//    channel 0  bank 0     cartridge ROM (up to 8MB)
//               bank 1     WRAM, BSRAM
//    channel 1  bank 2     ARAM
//    channel 2  bank 3     VRAM
//  For boards whose SDRAM gives errors at the ~129 MHz of sdram_cl3.sv.
//  The SDRAM clock phase can be moved from the OSD while the core runs.
//
//  Based on the MiST top-level of gyurco/SNES_FPGA and on the Calypso port.
//
//  Shaeon (Carlos Palmero), 2026. GPL v2 or later.
//============================================================================

module SNES_MIST_LC(
    input CLOCK_27,
    output LED,
    output [VGA_BITS-1:0] VGA_R,
    output [VGA_BITS-1:0] VGA_G,
    output [VGA_BITS-1:0] VGA_B,
    output VGA_HS,
    output VGA_VS,

    input SPI_SCK,
    inout SPI_DO,
    input SPI_DI,
    input SPI_SS2,
    input SPI_SS3,
    input CONF_DATA0,

`ifndef NO_DIRECT_UPLOAD
    input SPI_SS4,
`endif

`ifdef I2S_AUDIO
    output I2S_BCK,
    output I2S_LRCK,
    output I2S_DATA,
`endif

`ifdef USE_AUDIO_IN
    input AUDIO_IN,
`endif

    output [12:0] SDRAM_A,
    inout [15:0] SDRAM_DQ,
    output SDRAM_DQML,
    output SDRAM_DQMH,
    output SDRAM_nWE,
    output SDRAM_nCAS,
    output SDRAM_nRAS,
    output SDRAM_nCS,
    output [1:0] SDRAM_BA,
    output SDRAM_CLK,
    output SDRAM_CKE,

    output AUDIO_L,
    output AUDIO_R,
    input  UART_RX,
    output UART_TX
);

assign UART_TX = 1'b1;

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

assign LED = ~ioctl_download & ~bk_ena;

`include "build_id.v"
parameter CONF_STR = {
    "SNES;;",
    "F1SNES,SFCSMCBIN,Load;",
    "F2,SPC,Load;",
    "S,SAV,Mount;",
    "T3,Write Save RAM;",
    `SEP
    "OEF,Video Region,NTSC,PAL,NTSC-DeJittered;",
    "OAB,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
    "OG,Blend,On,Off;",
    "O12,ROM Type,Auto,LoROM,HiROM,ExHiROM;",
    "O56,Mouse,None,Port1,Port2;",
    "OPQ,Lightgun,Off,Super Scope,Justifier;",
    "O7,Swap Joysticks,No,Yes;",
    "OH,Multitap,Disabled,Port2;",
    "OSU,SDRAM Clock Phase,0,+0.26ns,+0.53ns,+0.79ns,-1.06ns,-0.79ns,-0.53ns,-0.26ns;",
    "T0,Reset;",
    "V,v1.0-86MHz.",`BUILD_DATE
};

wire [1:0] st_rom = status[2:1];
wire [1:0] scanlines = status[11:10];
wire [1:0] video_region = status[15:14];
wire [1:0] mouse_mode = status[6:5];
wire       joy_swap = status[7];
wire       multitap = status[17];
wire       BLEND = ~status[16];
wire       bk_save = status[3];
wire [1:0] GUN_MODE = status[26:25];
// SDRAM_CLK phase offset from the OSD, in steps of 2 x 1/8 of the VCO period
// (2 x 132 ps): 0 .. +3, -4 .. -1
wire signed [6:0] sdram_phase = {{3{status[30]}}, status[30:28], 1'b0};

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys, clk_mem;
wire [2:0] pll_cntsel;
wire pll_updown, pll_step, pll_done;
wire pll_settled;

pll_lc pll(
    .inclk0(CLOCK_27),
    .c0(SDRAM_CLK),
    .c1(clk_mem),
    .c2(clk_sys),
    .locked(locked),
    .scanclk(clk_sys),
    .phasecounterselect(pll_cntsel),
    .phaseupdown(pll_updown),
    .phasestep(pll_step),
    .phasedone(pll_done)
);

pll_phase pll_phase (
    .clk(clk_sys),
    .locked(locked),
    .c0_target(sdram_phase),
    .c4_target(7'sd0),
    .cntsel(pll_cntsel),
    .updown(pll_updown),
    .step(pll_step),
    .done(pll_done),
    .settled(pll_settled)
);

// the SDRAM is initialized again after its clock phase moves (moving it
// through bad phases can leave it misconfigured)
reg  mem_ok = 1'b0;
reg  [6:0] sdram_phase_l = 7'd0;
reg        sdram_moving = 1'b1;
always @(posedge clk_sys) begin
    sdram_phase_l <= sdram_phase;
    if (sdram_phase != sdram_phase_l) sdram_moving <= 1'b1;
    else if (pll_settled) sdram_moving <= 1'b0;
    mem_ok <= locked & ~sdram_moving;
end

wire sdram_ready;
reg reset;
always @(posedge clk_sys) begin
    reset <= buttons[1] | status[0] | ioctl_download | ~sdram_ready;
end

reg RESET_N = 0;
reg [1:0] rst_div = 2'd0;
always @(posedge clk_sys) begin
    rst_div <= rst_div + 1'd1;
    if (rst_div == 2) RESET_N <= ~reset;
end

//////////////////   MiST I/O   ///////////////////
wire [10:0] conf_str_addr;
reg   [7:0] conf_str_char;

wire [31:0] joystick0;
wire [31:0] joystick1;
wire [31:0] joystick2;
wire [31:0] joystick3;
wire [31:0] joystick4;

wire  [1:0] buttons;
wire [31:0] status;
wire        ypbpr;
wire        scandoubler_disable;
wire        no_csync;

wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire [31:0] ioctl_filesize;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;  // YOvfl, XOvfl, dy8, dx8, 1, mbtn, rbtn, lbtn
wire        mouse_strobe;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_buff_rd;
wire        img_mounted;
wire [31:0] img_size;

user_io #(
    .ROM_DIRECT_UPLOAD(DIRECT_UPLOAD),
    .FEATURES(32'h0 | (BIG_OSD << 13))
) user_io (
    .clk_sys(clk_sys),
    .clk_sd(clk_sys),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),
    .conf_addr(conf_str_addr),
    .conf_chr(conf_str_char),

    .status(status),
    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(no_csync),
    .buttons(buttons),
    .joystick_0(joystick0),
    .joystick_1(joystick1),
    .joystick_2(joystick2),
    .joystick_3(joystick3),
    .joystick_4(joystick4),

    .mouse_x(mouse_x),
    .mouse_y(mouse_y),
    .mouse_flags(mouse_flags),
    .mouse_strobe(mouse_strobe),

    .sd_conf(1'b0),
    .sd_sdhc(1'b1),
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_dout_strobe(sd_buff_wr),
    .sd_din_strobe(sd_buff_rd),
    .img_mounted(img_mounted),
    .img_size(img_size)
);

wire [24:0] ps2_mouse = { mouse_strobe_level, mouse_y[7:0], mouse_x[7:0], mouse_flags };
reg         mouse_strobe_level;

always @(posedge SPI_SCK)
    conf_str_char <= CONF_STR[(($size(CONF_STR)>>3) - conf_str_addr - 1)<<3 +:8];

always @(posedge clk_sys) if (mouse_strobe) mouse_strobe_level <= ~mouse_strobe_level;

data_io #(.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD), .DOUT_16(1'b1)) data_io
(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_DI(SPI_DI),
    .SPI_DO(SPI_DO),
    .SPI_SS2(SPI_SS2),
    .SPI_SS4(SPI_SS4),

    .clkref_n(1'b0),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(8'd0),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_filesize(ioctl_filesize)
);

wire cart_download = ioctl_download && ioctl_index[5:1] == 0; //0-1
wire spc_download  = ioctl_download && ioctl_index[5:0] == 6'd2;



////////////////////////////  MEMORY  ///////////////////////////////////

wire [24:0] ioctl_addr_adj = ioctl_addr[24:0] - ioctl_filesize[9:0];
wire        ioctl_hdr      = ioctl_addr[24:0] < ioctl_filesize[9:0];
wire        rom_wr         = cart_download & ioctl_wr & ~ioctl_hdr;

wire [23:0] ROM_ADDR;
wire [23:0] ROM_ADDR_EARLY;
wire        ROM_CE_N, ROM_OE_N, ROM_WE_N, ROM_WORD;
wire [15:0] ROM_D, ROM_Q;

// The DSP/LoROM/HiROM mapper gives the address at the start of the cycle
// (ROM_ADDR only half way through): more time for the SDRAM.
`ifdef EXTRA_CHIPS_1
wire [23:0] rom_addr_cpu = ROM_ADDR;
`elsif EXTRA_CHIPS_2
wire [23:0] rom_addr_cpu = ROM_ADDR;
`else
wire [23:0] rom_addr_cpu = ROM_ADDR_EARLY;
`endif

wire [16:0] WRAM_ADDR;
wire        WRAM_CE_N, WRAM_OE_N, WRAM_RD_N, WRAM_WE_N;
wire  [7:0] WRAM_Q, WRAM_D;
wire        wram_rd = ~WRAM_CE_N & ~WRAM_RD_N;
wire        wram_wr = ~WRAM_CE_N & ~WRAM_WE_N;

wire [19:0] BSRAM_ADDR;
wire        BSRAM_CE_N, BSRAM_OE_N, BSRAM_WE_N, BSRAM_RD_N;
wire  [7:0] BSRAM_Q, BSRAM_D;
wire        bsram_rd = ~BSRAM_CE_N & (~BSRAM_RD_N || rom_type[7:4] == 4'hC); // OBC1 reads without RD
wire        bsram_wr = ~BSRAM_CE_N & ~BSRAM_WE_N;

wire        VRAM_OE_N;
wire [15:0] VRAM1_ADDR, VRAM2_ADDR;
wire        VRAM1_WE_N, VRAM2_WE_N;
wire  [7:0] VRAM1_D, VRAM1_Q, VRAM2_D, VRAM2_Q;

wire [15:0] ARAM_ADDR;
wire        ARAM_CE_N, ARAM_OE_N, ARAM_WE_N;
wire  [7:0] ARAM_Q, ARAM_D;
wire        aram_rd = ~ARAM_CE_N & ~ARAM_OE_N;
wire        aram_wr = ~ARAM_CE_N & ~ARAM_WE_N;
wire [15:0] aram_dout;
assign ARAM_Q = ARAM_ADDR[0] ? aram_dout[15:8] : aram_dout[7:0];

wire        DOT_CLK_CE;

// ---------------- requests (clk_sys, as in SNESTang) ----------------
reg         rom_req = 0;   reg [22:1] rom_a;  reg [15:0] rom_d;  reg rom_w;  reg [23:1] rom_addr_sd;
wire [15:0] rom_dout;
assign ROM_Q = (ROM_WORD || ~rom_addr_cpu[0]) ? rom_dout : { rom_dout[7:0], rom_dout[15:8] };

reg         wramw_req = 0; reg [16:0] wramw_a; reg [7:0] wramw_d;
reg         wramr_req = 0; reg [16:0] wramr_a; reg wramr_ok = 1'b0;
reg  [16:0] ww_a_l;        reg  [7:0] ww_d_l;   reg ww_fix = 1'b0;
wire        wramw_ack;
wire [15:0] wramr_dout;
assign WRAM_Q = WRAM_ADDR[0] ? wramr_dout[15:8] : wramr_dout[7:0];

reg         aram_req = 0;  reg [15:0] aram_a; reg [15:0] aram_d; reg aram_w;

reg         vram1_req = 0, vram2_req = 0;
reg  [14:0] vram1_a, vram2_a, vram1_wa, vram2_wa;
reg   [7:0] vram1_din, vram2_din, vram1_wd, vram2_wd;
reg         vram1_w, vram2_w;
reg         vram1_wpend = 1'b0, vram2_wpend = 1'b0;
reg  [14:0] vram1_wa_p, vram2_wa_p;
reg   [7:0] vram1_wd_p, vram2_wd_p;
wire        vram1_ack, vram2_ack;
reg         vram1_ack_s, vram2_ack_s;

// BSRAM port: the core, or the save RAM engine while the core is halted
reg         bs_req = 0;    reg [18:0] bs_a;   reg [7:0] bs_d;   reg bs_w;
wire        bs_ack;
wire  [7:0] bs_dout;
reg  [18:0] bsram_addr_sd;
assign BSRAM_Q = bs_dout;

// save RAM engine side (pulse in, pulse out)
reg         ld_req, ld_we;
reg  [22:0] ld_addr;
reg   [7:0] ld_din;
wire  [7:0] ld_q = bs_dout;
reg         ld_done = 0;
reg         ld_pend = 0;
localparam [22:0] BSRAM_PBASE = 23'd0;

always @(posedge clk_sys) begin
    reg wram_rdD, wram_wrD, bsram_rdD, bsram_wrD, aram_rdD, aram_wrD, vram1_weD, vram2_weD;

    wram_rdD  <= wram_rd;   wram_wrD  <= wram_wr;
    bsram_rdD <= bsram_rd;  bsram_wrD <= bsram_wr;
    aram_rdD  <= aram_rd;   aram_wrD  <= aram_wr;
    vram1_weD <= VRAM1_WE_N; vram2_weD <= VRAM2_WE_N;
    vram1_ack_s <= vram1_ack; vram2_ack_s <= vram2_ack;
    ld_done   <= 1'b0;

    // ROM: download writes, or reads when the CPU address changes
    if (rom_wr && !ioctl_addr_adj[23]) begin
        rom_a <= ioctl_addr_adj[22:1]; rom_d <= ioctl_dout; rom_w <= 1'b1;
        rom_req <= ~rom_req;
        rom_addr_sd <= 23'h7FFFFF;
    end else if (!cart_download && !ROM_CE_N && rom_addr_sd != rom_addr_cpu[23:1]) begin
        rom_addr_sd <= rom_addr_cpu[23:1];
        rom_a <= rom_addr_cpu[22:1]; rom_w <= 1'b0;
        rom_req <= ~rom_req;
    end

    // WRAM writes: at the start of the strobe, so they are done before the
    // next cycle (a write and a read share channel 1). A DMA from ROM to
    // $2180 may give the data later in the cycle: if the data or the
    // address seen at the end of the strobe differ, the write is repeated.
    if (wram_wr) begin ww_a_l <= WRAM_ADDR; ww_d_l <= WRAM_D; end
    if (wram_wr && !wram_wrD) begin
        wramw_a <= WRAM_ADDR; wramw_d <= WRAM_D;
        wramw_req <= ~wramw_req;
        if (WRAM_ADDR[16:1] == wramr_a[16:1]) wramr_ok <= 1'b0;   // the word read before is old now
    end else if (wram_wrD && !wram_wr && (ww_a_l != wramw_a || ww_d_l != wramw_d)) begin
        ww_fix <= 1'b1;
    end
    if (ww_fix && wramw_ack == wramw_req) begin
        ww_fix  <= 1'b0;
        wramw_a <= ww_a_l; wramw_d <= ww_d_l;
        wramw_req <= ~wramw_req;
        if (ww_a_l[16:1] == wramr_a[16:1]) wramr_ok <= 1'b0;
    end
    // WRAM reads: on a new word, a new read strobe, or after a write to it
    if (wram_rd && (WRAM_ADDR[16:1] != wramr_a[16:1] || !wram_rdD || !wramr_ok)) begin
        wramr_a   <= WRAM_ADDR;
        wramr_req <= ~wramr_req;
        wramr_ok  <= 1'b1;
    end

    // ARAM
    if ((aram_rd && ARAM_ADDR[15:1] != aram_a[15:1]) || (aram_wr && ARAM_ADDR != aram_a) || (aram_rd && !aram_rdD) || (aram_wr && !aram_wrD)) begin
        aram_req <= ~aram_req;
        aram_a   <= ARAM_ADDR;
        aram_d   <= {ARAM_D, ARAM_D};
        aram_w   <= aram_wr;
    end
    if (spc_download) begin
        if (ioctl_wr & ioctl_addr < 24'h10100) aram_req <= ~aram_req;
        aram_a <= ioctl_addr - 9'd256;
        aram_d <= ioctl_dout;
        aram_w <= 1'b1;
    end

    // VRAM: writes at the end of the strobe (as in the Calypso port).
    // A request is only made when the previous one has been taken (req ==
    // ack): after a write the PPU moves its address and prefetches, and a
    // read toggle on top of a pending write cancelled both (lost writes =
    // wrong tiles, seen in Test Drive II and Super Ghouls'n Ghosts).
    if (RESET_N) begin
        if (~VRAM1_WE_N) begin vram1_wa <= VRAM1_ADDR[14:0]; vram1_wd <= VRAM1_D; end
        if (~vram1_weD & VRAM1_WE_N) begin vram1_wpend <= 1'b1; vram1_wa_p <= vram1_wa; vram1_wd_p <= vram1_wd; end
        if (vram1_req == vram1_ack_s) begin
            if (vram1_wpend) begin
                vram1_wpend <= 1'b0;
                vram1_a <= vram1_wa_p; vram1_din <= vram1_wd_p; vram1_w <= 1'b1; vram1_req <= ~vram1_req;
            end else if (VRAM1_WE_N && VRAM1_ADDR[14:0] != vram1_a && ~VRAM_OE_N) begin
                vram1_a <= VRAM1_ADDR[14:0]; vram1_w <= 1'b0; vram1_req <= ~vram1_req;
            end
        end
        if (~VRAM2_WE_N) begin vram2_wa <= VRAM2_ADDR[14:0]; vram2_wd <= VRAM2_D; end
        if (~vram2_weD & VRAM2_WE_N) begin vram2_wpend <= 1'b1; vram2_wa_p <= vram2_wa; vram2_wd_p <= vram2_wd; end
        if (vram2_req == vram2_ack_s) begin
            if (vram2_wpend) begin
                vram2_wpend <= 1'b0;
                vram2_a <= vram2_wa_p; vram2_din <= vram2_wd_p; vram2_w <= 1'b1; vram2_req <= ~vram2_req;
            end else if (VRAM2_WE_N && VRAM2_ADDR[14:0] != vram2_a && ~VRAM_OE_N) begin
                vram2_a <= VRAM2_ADDR[14:0]; vram2_w <= 1'b0; vram2_req <= ~vram2_req;
            end
        end
    end

    // BSRAM: the save RAM engine while it works, otherwise the core
    if (bk_busy) begin
        if (ld_req) begin
            bs_a <= ld_addr[18:0]; bs_d <= ld_din; bs_w <= ld_we;
            bs_req <= ~bs_req; ld_pend <= 1'b1;
        end else if (ld_pend && bs_ack == bs_req) begin
            ld_pend <= 1'b0; ld_done <= 1'b1;
        end
        bsram_addr_sd <= 19'h7FFFF;
    end else if ((bsram_wr && !bsram_wrD) ||
                 (bsram_rd && (BSRAM_ADDR[18:0] != bsram_addr_sd || !bsram_rdD))) begin
        // writes at the start of the strobe: CPU data, valid already
        bsram_addr_sd <= bsram_wr ? 19'h7FFFF : BSRAM_ADDR[18:0];
        bs_a <= BSRAM_ADDR[18:0]; bs_d <= BSRAM_D; bs_w <= bsram_wr;
        bs_req <= ~bs_req;
    end
end


sdram_lc sdram
(
    .init_n(mem_ok),
    .clk(clk_mem),
    .clkref(DOT_CLK_CE),
    .ready(sdram_ready),

    .SDRAM_DQ(SDRAM_DQ), .SDRAM_A(SDRAM_A), .SDRAM_DQML(SDRAM_DQML), .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_BA(SDRAM_BA), .SDRAM_nCS(SDRAM_nCS), .SDRAM_nWE(SDRAM_nWE), .SDRAM_nCAS(SDRAM_nCAS),
    .SDRAM_nRAS(SDRAM_nRAS), .SDRAM_CKE(SDRAM_CKE),

    .rom_req(rom_req), .rom_ack(), .rom_addr(rom_a), .rom_din(rom_d), .rom_we(rom_w), .rom_dout(rom_dout),

    .aram_req(aram_req), .aram_ack(), .aram_addr(aram_a), .aram_din(aram_d), .aram_we(aram_w),
    .aram_16(spc_download), .aram_dout(aram_dout),

    .wramw_req(wramw_req), .wramw_ack(wramw_ack), .wramw_addr(wramw_a), .wramw_din(wramw_d),
    .wramr_req(wramr_req), .wramr_ack(), .wramr_addr(wramr_a), .wramr_dout(wramr_dout),

    .bs_req(bs_req), .bs_ack(bs_ack), .bs_addr(bs_a), .bs_din(bs_d), .bs_we(bs_w), .bs_dout(bs_dout),

    .vram1_req(vram1_req), .vram1_ack(vram1_ack), .vram1_addr(vram1_a), .vram1_din(vram1_din), .vram1_dout(VRAM1_Q), .vram1_we(vram1_w),
    .vram2_req(vram2_req), .vram2_ack(vram2_ack), .vram2_addr(vram2_a), .vram2_din(vram2_din), .vram2_dout(VRAM2_Q), .vram2_we(vram2_w)
);

//////////////////////////// BACKUP RAM / LOADER /////////////////////

// SD sector buffer: port B is the user_io side, port A the copy engine
reg   [8:0] buf_addr;
reg   [7:0] buf_din;
reg         buf_we;
wire  [7:0] buf_q;

sector_buf sector_buf
(
    .clk(clk_sys),

    .addr_a(buf_addr),
    .din_a(buf_din),
    .we_a(buf_we),
    .q_a(buf_q),

    .addr_b(sd_buff_addr),
    .din_b(sd_buff_dout),
    .we_b(sd_buff_wr & sd_ack),
    .q_b(sd_buff_din)
);

localparam BK_IDLE     = 3'd0;
localparam BK_SD       = 3'd1;   // waiting for the SD transfer of one sector
localparam BK_TO_MEM = 3'd2;   // sector buffer -> BSRAM (load)
localparam BK_BUF_RD   = 3'd3;   // sector buffer read latency
localparam BK_BUF_Q    = 3'd4;   // sector buffer data valid, write it
localparam BK_TO_BUF   = 3'd5;   // BSRAM -> sector buffer (save)
localparam BK_WAIT     = 3'd6;   // waiting for a loader access

reg   [2:0] bk_state = BK_IDLE;
reg   [2:0] bk_next;
reg         bk_ena = 0;
reg         bk_load = 0;
reg   [9:0] bk_last;             // last sector (save RAM is at most 512KB)
reg   [9:0] bk_sector;
reg   [9:0] bk_idx;              // byte index in the sector, bit 9 = done


always @(posedge clk_sys) begin
    reg img_mountedD;
    reg ioctl_downloadD;
    reg bk_saveD;
    reg sd_ackD;

    ld_req <= 1'b0;
    buf_we <= 1'b0;

    img_mountedD    <= img_mounted;
    ioctl_downloadD <= ioctl_download;
    bk_saveD        <= bk_save;
    sd_ackD         <= sd_ack;

    if (~sd_ackD & sd_ack) { sd_rd, sd_wr } <= 2'b00;

    // ---------------- save RAM ----------------
    if (~img_mountedD & img_mounted) begin
        if (|img_size) begin
            bk_ena  <= 1;
            bk_load <= 1;
            bk_last <= |img_size[31:19] ? 10'd1023 :   // 512KB or more (BSRAM area of sdram_lc)
                       ~|img_size[18:9] ? 10'd0    :   // less than a sector
                       img_size[18:9] - 1'd1;
        end else
            bk_ena <= 0;
    end

    case (bk_state)
    BK_IDLE:
        if (bk_ena && RESET_N && !cart_download && (bk_load || (~bk_saveD & bk_save))) begin
            bk_sector <= 0;
            sd_lba    <= 0;
            bk_idx    <= 0;
            if (bk_load) begin
                sd_rd    <= 1'b1;
                bk_state <= BK_SD;
            end else
                bk_state <= BK_TO_BUF;
        end

    BK_SD:
        if (sd_ackD & ~sd_ack) begin
            bk_idx <= 0;
            if (bk_load)
                bk_state <= BK_TO_MEM;
            else if (bk_sector == bk_last)
                bk_state <= BK_IDLE;
            else begin
                bk_sector <= bk_sector + 1'd1;
                sd_lba    <= sd_lba + 1'd1;
                bk_state  <= BK_TO_BUF;
            end
        end

    // load: sector buffer byte bk_idx -> BSRAM
    BK_TO_MEM:
        if (bk_idx[9]) begin
            if (bk_sector == bk_last) begin
                bk_load  <= 0;
                bk_state <= BK_IDLE;
            end else begin
                bk_sector <= bk_sector + 1'd1;
                sd_lba    <= sd_lba + 1'd1;
                sd_rd     <= 1'b1;
                bk_state  <= BK_SD;
            end
        end else begin
            buf_addr <= bk_idx[8:0];
            bk_state <= BK_BUF_RD;
        end

    BK_BUF_RD: bk_state <= BK_BUF_Q;

    BK_BUF_Q: begin
        ld_req   <= 1'b1;
        ld_we    <= 1'b1;
        ld_addr  <= BSRAM_PBASE | {4'b0000, bk_sector, bk_idx[8:0]};
        ld_din   <= buf_q;
        bk_next  <= BK_TO_MEM;
        bk_state <= BK_WAIT;
    end

    // save: BSRAM byte bk_idx -> sector buffer
    BK_TO_BUF:
        if (bk_idx[9]) begin
            sd_wr    <= 1'b1;
            bk_state <= BK_SD;
        end else begin
            ld_req   <= 1'b1;
            ld_we    <= 1'b0;
            ld_addr  <= BSRAM_PBASE | {4'b0000, bk_sector, bk_idx[8:0]};
            buf_addr <= bk_idx[8:0];
            bk_next  <= BK_TO_BUF;
            bk_state <= BK_WAIT;
        end

    BK_WAIT:
        if (ld_done) begin
            if (bk_next == BK_TO_BUF) begin
                buf_din <= ld_q;
                buf_we  <= 1'b1;
            end
            bk_idx   <= bk_idx + 1'd1;
            bk_state <= bk_next;
        end

    default: bk_state <= BK_IDLE;
    endcase

    // a new download aborts any transfer and forgets the mounted file
    if (cart_download) begin
        bk_state <= BK_IDLE;
        bk_load  <= 0;
    end
    if (~ioctl_downloadD & ioctl_download) bk_ena <= 0;
end

wire bk_busy = bk_state != BK_IDLE;

////////////////////////////  ROM DETECT  /////////////////////////////////

reg spc_mode = 0;
always @(posedge clk_sys) begin
    if(buttons[1] | status[0]) spc_mode <= 0;
    if(ioctl_wr) spc_mode <= spc_download;
end

reg  [1:0] PAL;
reg  [7:0] rom_type;
reg  [7:0] rom_type_header;
reg  [7:0] mapper_header;
reg  [7:0] company_header;
reg  [3:0] rom_size;
reg [23:0] rom_mask, ram_mask;

wire [1:0] LHRom_type = st_rom == 0 ? ioctl_index[7:6] : st_rom - 1'd1;
wire [8:0] hdr_prefix = LHRom_type == 2 ? { 8'h40, 1'b1 } : // ExHiROM
                        LHRom_type == 1 ? { 8'h00, 1'b1 } : // HiROM
                        9'd0; // LoROM

always @(posedge clk_sys) begin
    reg [3:0] ram_size;

    if (cart_download) begin
        if(ioctl_wr) begin
            if (ioctl_addr == 0) begin
                ram_size <= 4'h0;
                rom_type <= { 6'd0, LHRom_type };
            end

            if(ioctl_addr_adj == { hdr_prefix, 15'h7FD4 }) mapper_header <= ioctl_dout[15:8];
            if(ioctl_addr_adj == { hdr_prefix, 15'h7FD6 }) { rom_size, rom_type_header } <= ioctl_dout[11:0];
            if(ioctl_addr_adj == { hdr_prefix, 15'h7FD8 }) ram_size <= ioctl_dout[3:0];
            if(ioctl_addr_adj == { hdr_prefix, 15'h7FDA }) company_header <= ioctl_dout[7:0];

            rom_mask <= (24'd1024 << ((rom_size < 4'd7) ? 4'hC : rom_size)) - 1'd1;
            ram_mask <= ram_size ? (24'd1024 << ram_size) - 1'd1 : 24'd0;

        end
    end
    else begin
        PAL <= video_region;
        //DSP3
        if (mapper_header == 8'h30 && rom_type_header == 8'd5 && company_header == 8'hB2) rom_type[7:4] <= 4'hA;
        //DSP1
        else if (((mapper_header == 8'h20 || mapper_header == 8'h21) && rom_type_header == 8'd3) ||
            (mapper_header == 8'h30 && rom_type_header == 8'd5) ||
            (mapper_header == 8'h31 && (rom_type_header == 8'd3 || rom_type_header == 8'd5))) rom_type[7] <= 1'b1;
        //DSP2
        else if (mapper_header == 8'h20 && rom_type_header == 8'd5) rom_type[7:4] <= 4'h9;
        //DSP4
        else if (mapper_header == 8'h30 && rom_type_header == 8'd3) rom_type[7:4] <= 4'hB;
        //OBC1
        else if (mapper_header == 8'h30 && rom_type_header == 8'h25) rom_type[7:4] <= 4'hC;
        //ST0XX
        else if (mapper_header == 8'h30 && rom_type_header == 8'hf6) begin
            rom_type[7:3] <= { 4'h8, 1'b1 };
            if (rom_size < 4'd10) rom_type[5] <= 1'b1; // Hayazashi Nidan Morita Shougi
        end
        // SDD1, GSU, SA1, SPC7110 and CX4 are detected as upstream, although
        // this build does not include them
        //SDD1
        else if (mapper_header == 8'h32 && (rom_type_header == 8'h43 || rom_type_header == 8'h45)) rom_type[7:4] <= 4'h5;
        //GSU
        else if (mapper_header == 8'h20 &&
            (rom_type_header == 8'h13 || rom_type_header == 8'h14 || rom_type_header == 8'h15 || rom_type_header == 8'h1a))
        begin
            rom_type[7:4] <= 4'h7;
            ram_mask <= (24'd1024 << 4'd6) - 1'd1;
        end
        //SA1
        else if (mapper_header == 8'h23 && (rom_type_header == 8'h32 || rom_type_header == 8'h34 || rom_type_header == 8'h35)) begin
            rom_type[7:4] <= 4'h6;
        // SPC7110
        end else if (mapper_header == 8'h3a && (rom_type_header == 8'hf5 || rom_type_header == 8'hf9)) begin
            rom_type[7:4] <= 4'hD;
            rom_type[3] <= rom_type_header[3]; // with RTC
        //CX4
        end else if (mapper_header == 8'h20 && rom_type_header == 8'hf3) begin
            rom_type[7:4] <= 4'h4;
        end
    end
end

////////////////////////////  SYSTEM  ///////////////////////////////////

wire [16:0] io_addr = ioctl_addr >= 17'h00100 && ioctl_addr < 17'h10100 ? ioctl_addr + 9'h100 :
                      ioctl_addr >= 17'h10100 ? {1'b1, ioctl_addr[7:0]} :
                      ioctl_addr[16:0];

main #(.USE_DSPn(1'b1), .USE_CX4(1'b0), .USE_SDD1(1'b0), .USE_SA1(1'b0), .USE_GSU(1'b0), .USE_DLH(1'b1), .USE_SPC7110(1'b0), .USE_BSX(1'b0), .USE_SUFAMI(1'b0), .USE_SS(1'b0), .HAVE_MLAB("FALSE")) main
(
    .RESET_N(RESET_N),

    .MCLK(clk_sys), // 21.4 MHz
    .ACLK(clk_sys),
    .HALT(bk_busy),

    .ROM_TYPE(rom_type),
    .ROM_MASK(rom_mask),
    .RAM_MASK(ram_mask),
    .RAM_SIZE(4'd0),

    .ROM_ADDR(ROM_ADDR),
    .ROM_ADDR_EARLY(ROM_ADDR_EARLY),
    .ROM_D(ROM_D),
    .ROM_Q(ROM_Q),
    .ROM_CE_N(ROM_CE_N),
    .ROM_OE_N(ROM_OE_N),
    .ROM_WE_N(ROM_WE_N),
    .ROM_WORD(ROM_WORD),

    .BSRAM_ADDR(BSRAM_ADDR),
    .BSRAM_D(BSRAM_D),
    .BSRAM_Q(BSRAM_Q),
    .BSRAM_CE_N(BSRAM_CE_N),
    .BSRAM_OE_N(BSRAM_OE_N),
    .BSRAM_WE_N(BSRAM_WE_N),
    .BSRAM_RD_N(BSRAM_RD_N),

    .WRAM_ADDR(WRAM_ADDR),
    .WRAM_D(WRAM_D),
    .WRAM_Q(WRAM_Q),
    .WRAM_CE_N(WRAM_CE_N),
    .WRAM_OE_N(WRAM_OE_N),
    .WRAM_WE_N(WRAM_WE_N),
    .WRAM_RD_N(WRAM_RD_N),

    .VRAM1_ADDR(VRAM1_ADDR),
    .VRAM1_DI(VRAM1_Q),
    .VRAM1_DO(VRAM1_D),
    .VRAM1_WE_N(VRAM1_WE_N),
    .VRAM2_ADDR(VRAM2_ADDR),
    .VRAM2_DI(VRAM2_Q),
    .VRAM2_DO(VRAM2_D),
    .VRAM2_WE_N(VRAM2_WE_N),
    .VRAM_OE_N(VRAM_OE_N),

    .ARAM_ADDR(ARAM_ADDR),
    .ARAM_D(ARAM_D),
    .ARAM_Q(ARAM_Q),
    .ARAM_CE_N(ARAM_CE_N),
    .ARAM_OE_N(ARAM_OE_N),
    .ARAM_WE_N(ARAM_WE_N),

    .GSU_ACTIVE(),
    .GSU_TURBO(1'b0),
    .GSU_FASTROM(1'b0),
    .SUFAMI_SWAP(1'b0),

    .BLEND(BLEND),
    .PAL(PAL[0]),
    .DIS_SHORTLINE(PAL[1]),
    .HIGH_RES(),
    .FIELD(),
    .INTERLACE(),
    .DOTCLK(DOTCLK),
    .R(R),
    .G(G),
    .B(B),
    .HBLANKn(HBLANKn),
    .VBLANKn(VBLANKn),
    .HSYNC(HSYNC),
    .VSYNC(VSYNC),

    .DOT_CLK_CE(DOT_CLK_CE),
    .SYSCLKR_CE(),
    .SYSCLKF_CE(),
    .REFRESH(),

    .JOY1_DI(JOY1_DO),
    .JOY2_DI(|GUN_MODE ? LG_DO : JOY2_DO),
    .JOY_STRB(JOY_STRB),
    .JOY1_CLK(JOY1_CLK),
    .JOY2_CLK(JOY2_CLK),
    .JOY1_P6(JOY1_P6),
    .JOY2_P6(JOY2_P6),
    .JOY2_P6_in(JOY2_P6_DI),

    .SPC_MODE(spc_mode),
    .IO_ADDR(io_addr),
    .IO_DAT(ioctl_dout),
    .IO_WR(spc_download & ioctl_wr & ioctl_addr < 17'h10200),

    .TURBO(1'b0),
    .TURBO_ALLOW(),

    .DBG_BG_EN(5'b11111),
    .DBG_CPU_EN(1'b1),

    .MSU_TRACK_NUM(),
    .MSU_TRACK_REQUEST(),
    .MSU_TRACK_MOUNTING(1'b0),
    .MSU_TRACK_MISSING(1'b0),
    .MSU_VOLUME(),
    .MSU_AUDIO_STOP(1'b0),
    .MSU_AUDIO_REPEAT(),
    .MSU_AUDIO_PLAYING(),
    .MSU_DATA_ADDR(),
    .MSU_DATA(8'd0),
    .MSU_DATA_ACK(1'b0),
    .MSU_DATA_SEEK(),
    .MSU_DATA_REQ(),
    .MSU_ENABLE(1'b0),

    .AUDIO_L(audioL),
    .AUDIO_R(audioR)
);

//////////////////   VIDEO   //////////////////
wire [7:0] R,G,B;
wire       HSYNC,VSYNC;
wire       HBLANKn,VBLANKn;

mist_video #(.SD_HCNT_WIDTH(10), .COLOR_DEPTH(8), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video
(
    .clk_sys(clk_sys),
    .scanlines(scanlines),
    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(no_csync),
    .rotate(2'b00),
    .ce_divider(3'd1),
    .SPI_DI(SPI_DI),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .HSync(~HSYNC),
    .VSync(~VSYNC),
    .HBlank(~HBLANKn),
    .VBlank(~VBLANKn),
    .R((LG_TARGET && |GUN_MODE) ? {8{LG_TARGET[0]}} : R),
    .G((LG_TARGET && |GUN_MODE) ? {8{LG_TARGET[1]}} : G),
    .B((LG_TARGET && |GUN_MODE) ? {8{LG_TARGET[2]}} : B),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B)
);

//////////////////   AUDIO   //////////////////
wire [15:0] audioL, audioR;

hybrid_pwm_sd dacl
(
    .clk(clk_sys),
    .n_reset(RESET_N),
    .din({~audioL[15], audioL[14:0]}),
    .dout(AUDIO_L)
);

hybrid_pwm_sd dacr
(
    .clk(clk_sys),
    .n_reset(RESET_N),
    .din({~audioR[15], audioR[14:0]}),
    .dout(AUDIO_R)
);

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd21_400_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audioR),
    .right_chan(audioL)
);
`endif

////////////////////////////  I/O PORTS  ////////////////////////////////
wire [11:0] joy0 = { joystick0[7:6], joystick0[11:8], joystick0[5:0] };
wire [11:0] joy1 = { joystick1[7:6], joystick1[11:8], joystick1[5:0] };
wire [11:0] joy2 = { joystick2[7:6], joystick2[11:8], joystick2[5:0] };
wire [11:0] joy3 = { joystick3[7:6], joystick3[11:8], joystick3[5:0] };
wire [11:0] joy4 = { joystick4[7:6], joystick4[11:8], joystick4[5:0] };

wire       JOY_STRB;

wire [1:0] JOY1_DO;
wire       JOY1_CLK;
wire       JOY1_P6;
ioport port1
(
    .CLK(clk_sys),

    .PORT_LATCH(JOY_STRB),
    .PORT_CLK(JOY1_CLK),
    .PORT_P6(JOY1_P6),
    .PORT_DO(JOY1_DO),

    .JOYSTICK1(joy_swap ? joy1 : joy0),

    .MOUSE(ps2_mouse),
    .MOUSE_EN(mouse_mode[0])
);

wire [1:0] JOY2_DO;
wire       JOY2_CLK;
wire       JOY2_P6;
wire       JOY2_P6_DI = (LG_P6_out | ~|GUN_MODE);

ioport port2
(
    .CLK(clk_sys),

    .MULTITAP(multitap),

    .PORT_LATCH(JOY_STRB),
    .PORT_CLK(JOY2_CLK),
    .PORT_P6(JOY2_P6),
    .PORT_DO(JOY2_DO),

    .JOYSTICK1(joy_swap ? joy0 : joy1),
    .JOYSTICK2(joy2),
    .JOYSTICK3(joy3),
    .JOYSTICK4(joy4),

    .MOUSE(ps2_mouse),
    .MOUSE_EN(mouse_mode[1])
);

wire       LG_P6_out;
wire [1:0] LG_DO;
wire [2:0] LG_TARGET;
wire       LG_T = joy0[6] | joy1[6]; // always from joysticks
wire       DOTCLK;

lightgun lightgun
(
    .CLK(clk_sys),
    .RESET(~RESET_N),

    .MOUSE(ps2_mouse),
    .MOUSE_XY(1'b1),

    .JOY_X(),
    .JOY_Y(),

    .F(ps2_mouse[0]),
    .C(ps2_mouse[1]),
    .T(LG_T), // always from joysticks
    .P(ps2_mouse[2] | joy0[7] | joy1[7]), // always from joysticks and mouse (upstream ORs the whole joy1)

    .HDE(HBLANKn),
    .VDE(VBLANKn),
    .CLKPIX(DOTCLK),

    .TARGET(LG_TARGET),
    .SIZE(1'b0),
    .GUN_TYPE(GUN_MODE[1]),

    .PORT_LATCH(JOY_STRB),
    .PORT_CLK(JOY2_CLK),
    .PORT_P6(LG_P6_out),
    .PORT_DO(LG_DO)
);

endmodule
