
module dmac_src_mm_axi (
	input                           m_axi_aclk,
	input                           m_axi_aresetn,

	input                           req_valid,
	output                          req_ready,
	input [31:C_ADDR_ALIGN_BITS]    req_address,
	input [3:0]                     req_last_burst_length,
	input [2:0]                     req_last_beat_bytes,

	input                           enable,
	output                          enabled,
	input                           pause,
	input                           sync_id,
	output                          sync_id_ret,

	output                          response_valid,
	input                           response_ready,
	output [1:0]                    response_resp,

	input  [C_ID_WIDTH-1:0]         request_id,
	output [C_ID_WIDTH-1:0]         response_id,

	output [C_ID_WIDTH-1:0]         data_id,
	output [C_ID_WIDTH-1:0]         address_id,
	input                           data_eot,
	input                           address_eot,

	output                          fifo_valid,
	input                           fifo_ready,
	output [C_M_AXI_DATA_WIDTH-1:0] fifo_data,

	// Read address
	input                            m_axi_arready,
	output                           m_axi_arvalid,
	output [31:0]                    m_axi_araddr,
	output [ 7:0]                    m_axi_arlen,
	output [ 2:0]                    m_axi_arsize,
	output [ 1:0]                    m_axi_arburst,
	output [ 2:0]                    m_axi_arprot,
	output [ 3:0]                    m_axi_arcache,

	// Read data and response
	input  [C_M_AXI_DATA_WIDTH-1:0]  m_axi_rdata,
	output                           m_axi_rready,
	input                            m_axi_rvalid,
	input  [ 1:0]                    m_axi_rresp
);

parameter C_ID_WIDTH = 3;
parameter C_M_AXI_DATA_WIDTH = 64;
parameter C_ADDR_ALIGN_BITS = 3;
parameter C_DMA_LENGTH_WIDTH = 24;

wire [C_ID_WIDTH-1:0] data_id;
wire [C_ID_WIDTH-1:0] address_id;

wire address_enabled;

wire address_req_valid;
wire address_req_ready;
wire data_req_valid;
wire data_req_ready;

assign sync_id_ret = sync_id;
assign response_id = data_id;

splitter #(
	.C_NUM_M(2)
) i_req_splitter (
	.clk(m_axi_aclk),
	.resetn(m_axi_aresetn),
	.s_valid(req_valid),
	.s_ready(req_ready),
	.m_valid({
		address_req_valid,
		data_req_valid
	}),
	.m_ready({
		address_req_ready,
		data_req_ready
	})
);

dmac_address_generator #(
	.C_DMA_LENGTH_WIDTH(C_DMA_LENGTH_WIDTH),
	.C_ADDR_ALIGN_BITS(C_ADDR_ALIGN_BITS),
	.C_ID_WIDTH(C_ID_WIDTH)
) i_addr_gen (
	.clk(m_axi_aclk),
	.resetn(m_axi_aresetn),

	.enable(enable),
	.enabled(address_enabled),
	.sync_id(sync_id),

	.id(address_id),
	.wait_id(request_id),

	.req_valid(address_req_valid),
	.req_ready(address_req_ready),
	.req_address(req_address),
	.req_last_burst_length(req_last_burst_length),

	.eot(address_eot),

	.addr_ready(m_axi_arready),
	.addr_valid(m_axi_arvalid),
	.addr(m_axi_araddr),
	.len(m_axi_arlen),
	.size(m_axi_arsize),
	.burst(m_axi_arburst),
	.prot(m_axi_arprot),
	.cache(m_axi_arcache)
);

dmac_data_mover # (
	.C_ID_WIDTH(C_ID_WIDTH),
	.C_DATA_WIDTH(C_M_AXI_DATA_WIDTH)
) i_data_mover (
	.s_axi_aclk(m_axi_aclk),
	.s_axi_aresetn(m_axi_aresetn),

	.enable(address_enabled),
	.enabled(enabled),
	.sync_id(sync_id),

	.request_id(address_id),
	.response_id(data_id),
	.eot(data_eot),

	.req_valid(data_req_valid),
	.req_ready(data_req_ready),
	.req_last_burst_length(req_last_burst_length),

	.s_axi_valid(m_axi_rvalid),
	.s_axi_ready(m_axi_rready),
	.s_axi_data(m_axi_rdata),
	.m_axi_valid(fifo_valid),
	.m_axi_ready(fifo_ready),
	.m_axi_data(fifo_data)
);

reg [1:0] rresp;

always @(posedge m_axi_aclk)
begin
	if (m_axi_rvalid && m_axi_rready) begin
		if (m_axi_rresp != 2'b0)
			rresp <= m_axi_rresp;
	end
end

endmodule