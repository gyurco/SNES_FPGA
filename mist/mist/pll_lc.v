// PLL for SNES_MIST_LC (Cyclone III, 27 MHz in, VCO 945 MHz)
//   c0  85.91 MHz  SDRAM_CLK pin, -2910 ps (about -90 degrees, as the Calypso
//                  port), moved at run time by pll_phase.sv (132.3 ps steps)
//   c1  85.91 MHz  clk_mem (4 x clk_sys)
//   c2  21.48 MHz  clk_sys (NTSC master clock)
// Shaeon (Carlos Palmero), 2026

module pll_lc (
	inclk0,
	c0,
	c1,
	c2,
	locked,
	scanclk,
	phasecounterselect,
	phaseupdown,
	phasestep,
	phasedone);

	input	  inclk0;
	output	  c0;
	output	  c1;
	output	  c2;
	output	  locked;
	input	  scanclk;
	input	  [2:0] phasecounterselect;
	input	  phaseupdown;
	input	  phasestep;
	output	  phasedone;

	wire [4:0] sub_wire0;
	wire  sub_wire4;
	wire [0:0] sub_wire7 = 1'h0;
	wire  c0 = sub_wire0[0];
	wire  c1 = sub_wire0[1];
	wire  c2 = sub_wire0[2];
	wire  locked = sub_wire4;
	wire  sub_wire5 = inclk0;
	wire [1:0] sub_wire6 = {sub_wire7, sub_wire5};

	altpll	altpll_component (
				.inclk (sub_wire6),
				.clk (sub_wire0),
				.locked (sub_wire4),
				.activeclock (),
				.areset (1'b0),
				.clkbad (),
				.clkena ({6{1'b1}}),
				.clkloss (),
				.clkswitch (1'b0),
				.configupdate (1'b0),
				.enable0 (),
				.enable1 (),
				.extclk (),
				.extclkena ({4{1'b1}}),
				.fbin (1'b1),
				.fbmimicbidir (),
				.fbout (),
				.fref (),
				.icdrclk (),
				.pfdena (1'b1),
				.phasecounterselect (phasecounterselect),
				.phasedone (phasedone),
				.phasestep (phasestep),
				.phaseupdown (phaseupdown),
				.pllena (1'b1),
				.scanaclr (1'b0),
				.scanclk (scanclk),
				.scanclkena (1'b1),
				.scandata (1'b0),
				.scandataout (),
				.scandone (),
				.scanread (1'b0),
				.scanwrite (1'b0),
				.sclkout0 (),
				.sclkout1 (),
				.vcooverrange (),
				.vcounderrange ());
	defparam
		altpll_component.bandwidth_type = "AUTO",
		altpll_component.clk0_divide_by = 11,
		altpll_component.clk0_duty_cycle = 50,
		altpll_component.clk0_multiply_by = 35,
		altpll_component.clk0_phase_shift = "-2910",
		altpll_component.clk1_divide_by = 11,
		altpll_component.clk1_duty_cycle = 50,
		altpll_component.clk1_multiply_by = 35,
		altpll_component.clk1_phase_shift = "0",
		altpll_component.clk2_divide_by = 44,
		altpll_component.clk2_duty_cycle = 50,
		altpll_component.clk2_multiply_by = 35,
		altpll_component.clk2_phase_shift = "0",
		altpll_component.compensate_clock = "CLK0",
		altpll_component.inclk0_input_frequency = 37037,
		altpll_component.intended_device_family = "Cyclone III",
		altpll_component.lpm_hint = "CBX_MODULE_PREFIX=pll_lc",
		altpll_component.lpm_type = "altpll",
		altpll_component.operation_mode = "NORMAL",
		altpll_component.pll_type = "AUTO",
		altpll_component.port_activeclock = "PORT_UNUSED",
		altpll_component.port_areset = "PORT_UNUSED",
		altpll_component.port_clkbad0 = "PORT_UNUSED",
		altpll_component.port_clkbad1 = "PORT_UNUSED",
		altpll_component.port_clkloss = "PORT_UNUSED",
		altpll_component.port_clkswitch = "PORT_UNUSED",
		altpll_component.port_configupdate = "PORT_UNUSED",
		altpll_component.port_fbin = "PORT_UNUSED",
		altpll_component.port_inclk0 = "PORT_USED",
		altpll_component.port_inclk1 = "PORT_UNUSED",
		altpll_component.port_locked = "PORT_USED",
		altpll_component.port_pfdena = "PORT_UNUSED",
		altpll_component.port_phasecounterselect = "PORT_USED",
		altpll_component.port_phasedone = "PORT_USED",
		altpll_component.port_phasestep = "PORT_USED",
		altpll_component.port_phaseupdown = "PORT_USED",
		altpll_component.port_pllena = "PORT_UNUSED",
		altpll_component.port_scanaclr = "PORT_UNUSED",
		altpll_component.port_scanclk = "PORT_USED",
		altpll_component.port_scanclkena = "PORT_UNUSED",
		altpll_component.port_scandata = "PORT_UNUSED",
		altpll_component.port_scandataout = "PORT_UNUSED",
		altpll_component.port_scandone = "PORT_UNUSED",
		altpll_component.port_scanread = "PORT_UNUSED",
		altpll_component.port_scanwrite = "PORT_UNUSED",
		altpll_component.port_clk0 = "PORT_USED",
		altpll_component.port_clk1 = "PORT_USED",
		altpll_component.port_clk2 = "PORT_USED",
		altpll_component.port_clk3 = "PORT_UNUSED",
		altpll_component.port_clk4 = "PORT_UNUSED",
		altpll_component.port_clk5 = "PORT_UNUSED",
		altpll_component.port_clkena0 = "PORT_UNUSED",
		altpll_component.port_clkena1 = "PORT_UNUSED",
		altpll_component.port_clkena2 = "PORT_UNUSED",
		altpll_component.port_clkena3 = "PORT_UNUSED",
		altpll_component.port_clkena4 = "PORT_UNUSED",
		altpll_component.port_clkena5 = "PORT_UNUSED",
		altpll_component.port_extclk0 = "PORT_UNUSED",
		altpll_component.port_extclk1 = "PORT_UNUSED",
		altpll_component.port_extclk2 = "PORT_UNUSED",
		altpll_component.port_extclk3 = "PORT_UNUSED",
		altpll_component.self_reset_on_loss_lock = "OFF",
		altpll_component.width_clock = 5,
		altpll_component.width_phasecounterselect = 3;

endmodule
