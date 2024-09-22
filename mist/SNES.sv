//============================================================================
//  SNES top-level for MiST
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module SNES_MIST_TOP
(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

`ifdef EXTRA_CHIPS_1
localparam bit EXTRA_CHIPS_1=1'b1;
`else
localparam bit EXTRA_CHIPS_1=1'b0;
`endif

`ifdef EXTRA_CHIPS_2
localparam bit EXTRA_CHIPS_2=1'b1;
`else
localparam bit EXTRA_CHIPS_2=1'b0;
`endif

assign LED  = ~ioctl_download & ~bk_ena;

// Further macros affecting the core:
// USE_SIMPLE_SDRAM - use a simple 85MHz SDRAM controller for the cart ROM
// BRAM_LEVEL_1 - BSRAM and VRAM in BRAM
// BRAM_WRAM    - WRAM in BRAM (only cart ROM in SDRAM)
// BRAM_ARAM    - ARAM in BRAM
// EXTRA_CHIPS_1 - SDD1, SA1, GSU
// EXTRA_CHIPS_2 - CX4, SPC7110

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
`ifdef BRAM_LEVEL_1
	"OR,GSU Turbo,Off,On;",
`endif
	"T0,Reset;",
	"V,v1.0.",`BUILD_DATE
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
wire       GSU_TURBO = status[27];

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys, clk_mem, clk_hdmi;

`ifdef USE_CLOCK_50
pll_sdram pll
(
	.inclk0(CLOCK_50),
`else
pll pll
(
	.inclk0(CLOCK_27),
`endif
	.c0(SDRAM_CLK),
	.c1(clk_mem),
	.c2(clk_sys),
`ifdef USE_HDMI
	.c3(clk_hdmi),
`endif
	.locked(locked)
);

reg reset;
always @(posedge clk_sys) begin
	reset <= buttons[1] | status[0] | ioctl_download;
end

reg RESET_N = 0;
reg RFSH = 0;
always @(posedge clk_sys) begin
	reg [1:0] div;

	div <= div + 1'd1;
	RFSH <= !div;

	if (div == 2) RESET_N <= ~reset;
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
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wait;
wire [23:0] ioctl_filesize;

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

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

user_io #(
	.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD),
`ifdef DUAL_SDRAM
	.STRLEN($size(CONF_STR)>>3),
`endif
	.FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))
) user_io (
	.clk_sys(clk_sys),
	.clk_sd(clk_sys),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_CLK(SPI_SCK),
	.SPI_MOSI(SPI_DI),
	.SPI_MISO(SPI_DO),
`ifdef DUAL_SDRAM
	.conf_str(CONF_STR),
`else
	.conf_addr(conf_str_addr),
	.conf_chr(conf_str_char),
`endif

`ifdef USE_HDMI
	.i2c_start      (i2c_start      ),
	.i2c_read       (i2c_read       ),
	.i2c_addr       (i2c_addr       ),
	.i2c_subaddr    (i2c_subaddr    ),
	.i2c_dout       (i2c_dout       ),
	.i2c_din        (i2c_din        ),
	.i2c_ack        (i2c_ack        ),
	.i2c_end        (i2c_end        ),
`endif
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

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_filesize(ioctl_filesize)
);

////////////////////////////  SDRAM  ///////////////////////////////////
wire [23:0] ROM_ADDR;
wire [24:0] ioctl_addr_adj = ioctl_addr - ioctl_filesize[9:0]; // adjust for 512 byte SMC header
wire [23:0] rom_addr_rw = cart_download ? ioctl_addr_adj[23:0] : ROM_ADDR[23:0];
reg  [23:1] rom_addr_sd;
wire        ROM_CE_N;
wire        ROM_OE_N;
wire        ROM_WE_N;
wire        ROM_WORD;
wire [15:0] ROM_D;
wire [15:0] ROM_Q;
`ifndef USE_SIMPLE_SDRAM
assign      ROM_Q = (ROM_WORD || ~ROM_ADDR[0]) ? cpu_port0 : { cpu_port0[7:0], cpu_port0[15:8] };
`endif

wire [15:0] cpu_port0;
wire [15:0] cpu_port1;
reg         cpu_port;

reg         cpu_req;
reg   [1:0] cpu_ds;
reg  [15:0] cpu_din;
reg  [23:1] cpu_addr_sd;
reg         cpu_we;

reg         cpu2_req;
reg   [1:0] cpu2_ds;
reg  [15:0] cpu2_din;
reg  [23:1] cpu2_addr_sd;
reg         cpu2_we;

wire [16:0] WRAM_ADDR;
reg  [16:0] wram_addr_sd;
wire        WRAM_CE_N;
wire        WRAM_OE_N;
wire        WRAM_RD_N;
wire        WRAM_WE_N;
wire  [7:0] WRAM_SD_Q = WRAM_ADDR[0] ? cpu_port1[15:8] : cpu_port1[7:0];
wire  [7:0] WRAM_Q;
wire  [7:0] WRAM_D;
wire        wram_rd = ~WRAM_CE_N & ~WRAM_RD_N;
reg         wram_rdD;
wire        wram_wr = ~WRAM_CE_N & ~WRAM_WE_N;
reg         wram_wrD;

wire [19:0] BSRAM_ADDR;
reg  [19:0] bsram_sd_addr;
wire        BSRAM_CE_N;
wire        BSRAM_OE_N;
wire        BSRAM_WE_N;
wire        BSRAM_RD_N;
wire  [7:0] BSRAM_SD_Q = BSRAM_ADDR[0] ? bsram_dout[15:8] : bsram_dout[7:0];
wire  [7:0] BSRAM_Q;
wire  [7:0] BSRAM_D;
reg   [7:0] bsram_din;
wire [15:0] bsram_dout;
wire        bsram_rd = ~BSRAM_CE_N & (~BSRAM_RD_N || rom_type[7:4] == 4'hC);
reg         bsram_rdD;
wire        bsram_wr = ~BSRAM_CE_N & ~BSRAM_WE_N;
reg         bsram_wrD;
wire        bsram_req;
reg         bsram_req_reg;

wire        VRAM_OE_N;

wire [15:0] VRAM1_ADDR;
reg  [14:0] vram1_addr_sd;
wire        VRAM1_WE_N;
wire  [7:0] VRAM1_D, VRAM1_Q;
reg   [7:0] vram1_din;
wire        vram1_req;
reg         vram1_req_reg;
reg         vram1_we_nD;

wire [15:0] VRAM2_ADDR;
reg  [14:0] vram2_addr_sd;
wire        VRAM2_WE_N;
wire  [7:0] VRAM2_D, VRAM2_Q;
reg   [7:0] vram2_din;
wire        vram2_req;
reg         vram2_req_reg;
reg         vram2_we_nD;

wire [15:0] ARAM_ADDR;
reg  [15:0] aram_addr_sd;
wire        ARAM_CE_N;
wire        ARAM_OE_N;
wire        ARAM_WE_N;
wire  [7:0] ARAM_Q;
`ifndef BRAM_ARAM
assign ARAM_Q = ARAM_ADDR[0] ? aram_dout[15:8] : aram_dout[7:0];
`endif
wire  [7:0] ARAM_D;
reg  [15:0] aram_din;
wire [15:0] aram_dout;
wire        aram_rd = ~ARAM_CE_N & ~ARAM_OE_N;
reg         aram_rd_last;
wire        aram_wr = ~ARAM_CE_N & ~ARAM_WE_N;
reg         aram_wr_last;
wire        aram_req;
wire        aram_req_reg;

wire        DOT_CLK_CE;

always @(negedge clk_sys) begin

	wram_rdD <= wram_rd;
	wram_wrD <= wram_wr;
	if (spc_download) begin
	end
`ifndef USE_SIMPLE_SDRAM
	else
	if ((~cart_download && ~ROM_CE_N /*&& ~ROM_OE_N */&& rom_addr_sd != rom_addr_rw[23:1]) || (ioctl_wr & cart_download)) begin
		rom_addr_sd <= rom_addr_rw[23:1];
		cpu_req <= ~cpu_req;
		cpu_addr_sd <= rom_addr_rw[23:1];
		cpu_we <= cart_download;
		cpu_din <= ioctl_dout;
		cpu_ds <= 2'b11;
		cpu_port <= 0;
	end
`endif
`ifndef BRAM_WRAM
	else
	if ((wram_rd && WRAM_ADDR[16:1] != wram_addr_sd[16:1]) || (~wram_wrD & wram_wr) || (~wram_rdD & wram_rd)) begin
		wram_addr_sd <= WRAM_ADDR;
		cpu_req <= ~cpu_req;
		cpu_addr_sd <= {7'b1110111, WRAM_ADDR[16:1]};
		cpu_we <= wram_wr;
		cpu_din <= {WRAM_D, WRAM_D};
		cpu_ds <= {WRAM_ADDR[0], ~WRAM_ADDR[0]};
		cpu_port <= 1;
	end
`endif // BRAM_WRAM

`ifndef BRAM_ARAM
	aram_wr_last <= aram_wr;
	aram_rd_last <= aram_rd;
	if (spc_download) begin
		if (ioctl_wr & ioctl_addr < 24'h10100) aram_req <= ~aram_req;
		aram_addr_sd <= ioctl_addr - 9'd256;
		aram_din <= ioctl_dout;
	end else if ((aram_rd && ARAM_ADDR[15:1] != aram_addr_sd[15:1]) || (aram_wr && ARAM_ADDR != aram_addr_sd) || (aram_rd & ~aram_rd_last) || (aram_wr & ~aram_wr_last)) begin
		aram_req <= ~aram_req;
		aram_addr_sd <= ARAM_ADDR;
		aram_din <= {ARAM_D, ARAM_D};
	end
`endif // BRAM_ARAM

	if (~RESET_N) begin
//		vram1_addr_sd <= 15'h7fff;
//		vram2_addr_sd <= 15'h7fff;
	end else begin
`ifndef BRAM_LEVEL_1
		bsram_rdD <= bsram_rd;
		bsram_wrD <= bsram_wr;
		if ((bsram_rd && BSRAM_ADDR[19:1] != bsram_sd_addr[19:1]) || (~bsram_wrD & bsram_wr) || (~bsram_rdD & bsram_rd)) begin
			bsram_req <= ~bsram_req;
			bsram_sd_addr <= BSRAM_ADDR;
			bsram_din <= BSRAM_D;
		end

		vram1_we_nD <= VRAM1_WE_N;
		if ((vram1_we_nD & ~VRAM1_WE_N) || (VRAM1_ADDR[14:0] != vram1_addr_sd && ~VRAM_OE_N)) begin
			vram1_addr_sd <= VRAM1_ADDR[14:0];
			vram1_din <= VRAM1_D;
			vram1_req <= ~vram1_req;
		end

		vram2_we_nD <= VRAM2_WE_N;
		if ((vram2_we_nD & ~VRAM2_WE_N) || (VRAM2_ADDR[14:0] != vram2_addr_sd && ~VRAM_OE_N)) begin
			vram2_addr_sd <= VRAM2_ADDR[14:0];
			vram2_din <= VRAM2_D;
			vram2_req <= ~vram2_req;
		end
`endif // BRAM_LEVEL_1

	end

end

`ifdef BRAM_LEVEL_1

localparam  BSRAM_BITS = 17; // 1Mbits

dpram #(BSRAM_BITS,8) bsram 
(
	.clock(clk_sys),

	.address_a(BSRAM_ADDR),
	.data_a(BSRAM_D),
	.wren_a(~BSRAM_CE_N & ~BSRAM_WE_N),
	.q_a(BSRAM_Q),

	.address_b({sd_lba[BSRAM_BITS-9:0],sd_buff_addr}),
	.data_b(sd_buff_dout),
	.wren_b(sd_buff_wr & sd_ack),
	.q_b(sd_buff_din)
);

dpram #(15) vram1
(
	.clock(clk_sys),
	.address_a(VRAM1_ADDR[14:0]),
	.data_a(VRAM1_D),
	.wren_a(~VRAM1_WE_N),
	.q_a(VRAM1_Q)
);

dpram #(15) vram2
(
	.clock(clk_sys),
	.address_a(VRAM2_ADDR[14:0]),
	.data_a(VRAM2_D),
	.wren_a(~VRAM2_WE_N),
	.q_a(VRAM2_Q)
);

`endif // BRAM_LEVEL_1

`ifdef BRAM_WRAM
dpram #(17)	wram
(
	.clock(clk_sys),
	.address_a(WRAM_ADDR),
	.data_a(WRAM_D),
	.wren_a(~WRAM_CE_N & ~WRAM_WE_N),
	.q_a(WRAM_Q),
/*
	// clear the RAM on loading
	.address_b(mem_fill_addr[16:0]),
	.data_b(wram_fill_data),
	.wren_b(clearing_ram)
*/
);
`endif // BRAM_WRAM

`ifdef BRAM_ARAM
dpram_dif #(16,8,15,16) aram
(
	.clock(clk_sys),
	.address_a(ARAM_ADDR),
	.data_a(ARAM_D),
	.wren_a(~ARAM_CE_N & ~ARAM_WE_N),
	.q_A(ARAM_Q),
/*
	// clear the RAM on loading
	.address_b(spc_download ? addr_download[15:1] : mem_fill_addr[15:1]),
	.data_b(spc_download ? ioctl_dout : {2{aram_fill_data}}),
	.wren_b(spc_download ? ioctl_wr : clearing_ram)
*/
);
`endif // BRAM_ARAM

`ifndef BRAM_LEVEL_1
`define USE_MULTI_SDRAM
`endif
`ifndef BRAM_WRAM
`define USE_MULTI_SDRAM
`endif
`ifndef BRAM_ARAM
`define USE_MULTI_SDRAM
`endif

`ifdef USE_MULTI_SDRAM
sdram_cl3 sdram
(
	.init_n(locked),
	.clk(clk_mem),
	.clkref(DOT_CLK_CE),

	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_CKE(SDRAM_CKE),

`ifndef BRAM_WRAM
	.cpu_addr(cpu_addr_sd),
	.cpu_din(cpu_din),
	.cpu_req(cpu_req),
	.cpu_req_ack(),
	.cpu_we(cpu_we),
	.cpu_ds(cpu_ds),
	.cpu_port(cpu_port),
	.cpu_port0(cpu_port0),
	.cpu_port1(cpu_port1),
`endif

`ifndef BRAM_LEVEL_1
	.bsram_addr(bsram_sd_addr),
//	.bsram_din(bsram_din), // OBC1 doesn't like this
	.bsram_din(BSRAM_D),
	.bsram_dout(bsram_dout),
	.bsram_req(bsram_req),
	.bsram_req_ack(),
//	.bsram_we(~BSRAM_WE_N),
	.bsram_we(bsram_wrD),

	.bsram_io_addr(BSRAM_IO_ADDR),
	.bsram_io_din(BSRAM_IO_D),
	.bsram_io_dout(BSRAM_IO_Q),
	.bsram_io_req(bsram_io_req_d),
	.bsram_io_req_ack(),
	.bsram_io_we(bk_load),

	.vram1_req(vram1_req),
	.vram1_ack(),
	.vram1_addr(vram1_addr_sd),
	.vram1_din(vram1_din),
	.vram1_dout(VRAM1_Q),
	.vram1_we(~vram1_we_nD),

	.vram2_req(vram2_req),
	.vram2_ack(),
	.vram2_addr(vram2_addr_sd),
	.vram2_din(vram2_din),
	.vram2_dout(VRAM2_Q),
	.vram2_we(~vram2_we_nD),
`endif

`ifndef BRAM_ARAM
	.aram_16(spc_download),
	.aram_addr(aram_addr_sd),
	.aram_din(aram_din),
//	.aram_din(ARAM_D),
	.aram_dout(aram_dout),
	.aram_req(aram_req),
	.aram_req_ack(),
//	.aram_we(~ARAM_WE_N)
	.aram_we(spc_download | aram_wr_last)
`endif // BRAM_ARAM
);
`endif

`ifdef USE_SIMPLE_SDRAM

`ifdef DUAL_SDRAM
wire locked2;
wire clk_mem2;

pll_sdram2 pll_sdram2
(
	.inclk0(CLOCK_50),
	.c0(clk_mem2),
	.locked(locked2)
);
assign SDRAM2_CLK = clk_mem2;
`endif

sdram sdram2
(
`ifdef DUAL_SDRAM
	.SDRAM_DQ(SDRAM2_DQ),
	.SDRAM_A(SDRAM2_A),
	.SDRAM_DQML(SDRAM2_DQML),
	.SDRAM_DQMH(SDRAM2_DQMH),
	.SDRAM_BA(SDRAM2_BA),
	.SDRAM_nCS(SDRAM2_nCS),
	.SDRAM_nWE(SDRAM2_nWE),
	.SDRAM_nCAS(SDRAM2_nCAS),
	.SDRAM_nRAS(SDRAM2_nRAS),
	.SDRAM_CKE(SDRAM2_CKE),
`else
	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_CKE(SDRAM_CKE),
`endif

`ifdef DUAL_SDRAM
	.init_n(locked2),
	.clk(clk_mem2),
`else
	.init_n(locked),
	.clk(clk_mem),
`endif
	.addr(rom_addr_rw),
	.din(cart_download ? ioctl_dout : ROM_D),
	.dout(ROM_Q),
	.rd(~cart_download & (RESET_N ? ~ROM_OE_N : RFSH)),
	.wr(cart_download ? ioctl_wr : ~ROM_WE_N),
	.word(cart_download | ROM_WORD),
	.busy()
);

`endif
//////////////////////////  ROM DETECT  /////////////////////////////////

wire cart_download = ioctl_download && ioctl_index[5:1] == 0; //0-1
wire spc_download = ioctl_download && ioctl_index[5:0] == 6'd2;

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
		//SDD1
		else if (mapper_header == 8'h32 && (rom_type_header == 8'h43 || rom_type_header == 8'h45)) rom_type[7:4] <= 4'h5;
		//ST0XX
		else if (mapper_header == 8'h30 && rom_type_header == 8'hf6) begin
			rom_type[7:3] <= { 4'h8, 1'b1 };
			if (rom_size < 4'd10) rom_type[5] <= 1'b1; // Hayazashi Nidan Morita Shougi
		end
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

main #(.USE_DSPn(1'b1), .USE_CX4(EXTRA_CHIPS_2), .USE_SDD1(EXTRA_CHIPS_1), .USE_SA1(EXTRA_CHIPS_1), .USE_GSU(EXTRA_CHIPS_1), .USE_DLH(1'b1), .USE_SPC7110(EXTRA_CHIPS_2), .USE_BSX(1'b0), .HAVE_MLAB("FALSE")) main
(
	.RESET_N(RESET_N),

	.MCLK(clk_sys), // 21.47727 / 21.28137
	.ACLK(clk_sys),
	.HALT(bk_state == 1'b1),

	.ROM_TYPE(rom_type),
	.ROM_MASK(rom_mask),
	.RAM_MASK(ram_mask),

	.ROM_ADDR(ROM_ADDR),
	.ROM_D(ROM_D),
	.ROM_Q(ROM_Q),
	.ROM_CE_N(ROM_CE_N),
	.ROM_OE_N(ROM_OE_N),
	.ROM_WE_N(ROM_WE_N),
	.ROM_WORD(ROM_WORD),

	.BSRAM_ADDR(BSRAM_ADDR),
	.BSRAM_D(BSRAM_D),
`ifdef BRAM_LEVEL_1
	.BSRAM_Q(BSRAM_Q),
`else
	.BSRAM_Q(BSRAM_SD_Q),
`endif
	.BSRAM_CE_N(BSRAM_CE_N),
	.BSRAM_OE_N(BSRAM_OE_N),
	.BSRAM_WE_N(BSRAM_WE_N),
	.BSRAM_RD_N(BSRAM_RD_N),

	.WRAM_ADDR(WRAM_ADDR),
	.WRAM_D(WRAM_D),
`ifdef BRAM_WRAM
	.WRAM_Q(WRAM_Q),
`else
	.WRAM_Q(WRAM_SD_Q),
`endif
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
	.GSU_TURBO(GSU_TURBO),

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
/*
	.GG_EN(1'b0),
	.GG_CODE(128'd0),
	.GG_RESET(1'b0),
	.GG_AVAILABLE(1'b0),
*/
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

`ifdef USE_HDMI
i2c_master #(21_000_000) i2c_master (
	.CLK         (clk_sys),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.SD_HCNT_WIDTH(10), .COLOR_DEPTH(8), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1)) hdmi_video
(
	.clk_sys(clk_hdmi),
	.scanlines(scanlines),
	.scandoubler_disable(1'b0),
	.ypbpr(1'b0),
	.no_csync(1'b1),
	.rotate(2'b00),
	.ce_divider(3'd3),
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
	.VGA_HS(HDMI_HS),
	.VGA_VS(HDMI_VS),
	.VGA_R(HDMI_R),
	.VGA_G(HDMI_G),
	.VGA_B(HDMI_B),
	.VGA_DE(HDMI_DE)
);

assign HDMI_PCLK = clk_hdmi;

`endif

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
	.clk(clk_mem),
	.clk_rate(`AUDIO_CLOCK_RATE),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(audioR),
	.right_chan(audioL)
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_mem) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_mem),
	.rst_i(1'b0),
	.clk_rate_i(`AUDIO_CLOCK_RATE),
	.spdif_o(SPDIF),
	.sample_i({audioR, audioL})
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
	.P(ps2_mouse[2] | joy0[7] | joy1), // always from joysticks and mouse

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

//////////////////////////// BACKUP RAM /////////////////////
reg  [19:1] BSRAM_IO_ADDR;
wire [15:0] BSRAM_IO_D;
wire [15:0] BSRAM_IO_Q;
reg  [15:0] bsram_io_q_save;
reg         bsram_io_req, bsram_io_req_d;
reg         bk_ena, bk_load;
reg         bk_state;
reg  [11:0] sav_size;

`ifndef BRAM_LEVEL_1
assign      sd_buff_din = sd_buff_addr[0] ? bsram_io_q_save[15:8] : bsram_io_q_save[7:0];
`endif

always @(posedge clk_mem) bsram_io_req_d <= bsram_io_req;
always @(posedge clk_sys) begin

	reg img_mountedD;
	reg ioctl_downloadD;
	reg bk_loadD, bk_saveD;
	reg sd_ackD;

	if (~RESET_N) begin
		bk_ena <= 0;
		bk_state <= 0;
		bk_load <= 0;
	end else begin
		img_mountedD <= img_mounted;
		if (~img_mountedD & img_mounted) begin
			if (|img_size) begin
				bk_ena <= 1;
				bk_load <= 1;
				sav_size <= img_size[20:9];
			end else begin
				bk_ena <= 0;
			end
		end

		ioctl_downloadD <= ioctl_download;
		if (~ioctl_downloadD & ioctl_download) bk_ena <= 0;

		bk_loadD <= bk_load;
		bk_saveD <= bk_save;
		sd_ackD  <= sd_ack;

		if (~sd_ackD & sd_ack) { sd_rd, sd_wr } <= 2'b00;

		case (bk_state)
		0:	if (bk_ena && ((~bk_loadD & bk_load) || (~bk_saveD & bk_save))) begin
				bk_state <= 1;
				sd_lba <= 0;
				sd_rd <= bk_load;
				sd_wr <= ~bk_load;
				if (bk_save) begin
					BSRAM_IO_ADDR <= 0;
					bsram_io_req <= ~bsram_io_req;
				end else
					BSRAM_IO_ADDR <= 19'h7ffff;
			end
		1:	if (sd_ackD & ~sd_ack) begin
				if (sd_lba[11:0] == sav_size) begin
					bk_load <= 0;
					bk_state <= 0;
				end else begin
					sd_lba <= sd_lba + 1'd1;
					sd_rd  <= bk_load;
					sd_wr  <= ~bk_load;
				end
			end
		endcase

		if (sd_buff_wr) begin
			if (sd_buff_addr[0]) begin
				BSRAM_IO_D[15:8] <= sd_buff_dout;
				bsram_io_req <= ~bsram_io_req;
				BSRAM_IO_ADDR <= BSRAM_IO_ADDR + 1'd1;
			end else
				BSRAM_IO_D[7:0] <= sd_buff_dout;
		end

		if (~sd_buff_addr[0]) bsram_io_q_save <= BSRAM_IO_Q;

		if (sd_buff_rd & sd_buff_addr[0]) begin
			bsram_io_req <= ~bsram_io_req;
			BSRAM_IO_ADDR <= BSRAM_IO_ADDR + 1'd1;
		end
	end
end

endmodule
