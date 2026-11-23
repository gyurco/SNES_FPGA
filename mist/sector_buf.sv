// 512 byte true dual port RAM (one M9K) used as SD sector buffer for the
// save RAM load/save, so the transfer does not depend on the memory latency
// or on the SPI speed of the firmware (from the Calypso port).

module sector_buf (
    input            clk,

    input      [8:0] addr_a,
    input      [7:0] din_a,
    input            we_a,
    output reg [7:0] q_a,

    input      [8:0] addr_b,
    input      [7:0] din_b,
    input            we_b,
    output reg [7:0] q_b
);

reg [7:0] mem[512];

always @(posedge clk) begin
    if (we_a) begin
        mem[addr_a] <= din_a;
        q_a <= din_a;
    end else
        q_a <= mem[addr_a];
end

always @(posedge clk) begin
    if (we_b) begin
        mem[addr_b] <= din_b;
        q_b <= din_b;
    end else
        q_b <= mem[addr_b];
end

endmodule
