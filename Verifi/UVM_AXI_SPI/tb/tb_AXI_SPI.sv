`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;


// ============================================================
// Interface
// ============================================================
interface spi_if (
    input logic clk,
    input logic reset_n
);
    // AXI 버스 신호
    logic [3:0] awaddr;
    logic [2:0] awprot;
    logic awvalid;
    logic awready;
    logic [31:0] wdata;
    logic [3:0] wstrb;
    logic wvalid;
    logic wready;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;
    logic [3:0] araddr;
    logic [2:0] arprot;
    logic arvalid;
    logic arready;
    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;

    // 물리적 SPI 신호
    logic sclk;
    logic mosi;
    logic miso;
    logic cs_n;


    logic [7:0] s_tx_data;
    logic [7:0] s_rx_data;
endinterface



class spi_seq_item extends uvm_sequence_item;
    rand bit [31:0] m_tx_data;
    rand bit [7:0] s_tx_data;

    bit [7:0] m_rx_data;
    bit [7:0] s_rx_data;

    `uvm_object_utils_begin(spi_seq_item)
        `uvm_field_int(m_tx_data, UVM_ALL_ON)
        `uvm_field_int(s_tx_data, UVM_ALL_ON)
        `uvm_field_int(m_rx_data, UVM_ALL_ON)
        `uvm_field_int(s_rx_data, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "M_TX=0x%08h | M_RX=0x%02h | S_TX=0x%02h | S_RX=0x%02h",
            m_tx_data,
            m_rx_data,
            s_tx_data,
            s_rx_data
        );
    endfunction
endclass



class spi_rand_sequence extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_rand_sequence)

    function new(string name = "spi_rand_sequence");
        super.new(name);
    endfunction

    virtual task body();
        spi_seq_item req;
        `uvm_info("SEQ", "SPI Random Sequence Started", UVM_LOW)

        for (int i = 0; i < 1000; i++) begin
            req = spi_seq_item::type_id::create("req");
            start_item(req);
            if (!req.randomize()) `uvm_error("SEQ", "Randomization Failed")
            finish_item(req);
        end

        `uvm_info("SEQ", "SPI Random Sequence Finished", UVM_LOW)
    endtask
endclass


class spi_coverage extends uvm_subscriber #(spi_seq_item);
    `uvm_component_utils(spi_coverage)

    spi_seq_item item;


    covergroup spi_data_cg;
        cp_m_tx_byte: coverpoint item.m_tx_data[7:0] {
            bins all_zero = {8'h00};
            bins all_one = {8'hFF};
            bins alternating = {8'h55, 8'hAA};
            bins walking_ones  = {8'h01, 8'h02, 8'h04, 8'h08,
                                  8'h10, 8'h20, 8'h40, 8'h80};
            bins walking_zeros = {8'hFE, 8'hFD, 8'hFB, 8'hF7,
                                  8'hEF, 8'hDF, 8'hBF, 8'h7F};
            bins random_others = default;
        }
        cp_s_tx_data: coverpoint item.s_tx_data {
            bins all_zero = {8'h00};
            bins all_one = {8'hFF};
            bins random_others = default;
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        spi_data_cg = new();
    endfunction

    virtual function void write(spi_seq_item s);
        item = s;
        spi_data_cg.sample();
        `uvm_info(
            get_type_name(), $sformatf(
            "Coverage Sample: m_tx=%0h s_tx=%0h", item.m_tx_data, item.s_tx_data
            ), UVM_HIGH)
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "====== Coverage Summary =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  " Overall     : %.1f%%", spi_data_cg.get_coverage()), UVM_LOW)
        `uvm_info(
            get_type_name(), $sformatf(
            " m_tx_byte   : %.1f%%", spi_data_cg.cp_m_tx_byte.get_coverage()),
            UVM_LOW)
        `uvm_info(
            get_type_name(), $sformatf(
            " s_tx_data   : %.1f%%", spi_data_cg.cp_s_tx_data.get_coverage()),
            UVM_LOW)
        `uvm_info(get_type_name(), "=============================\n", UVM_LOW)
    endfunction
endclass



class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)
    virtual spi_if s_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "s_if", s_if))
            `uvm_fatal("NO_VIF", "Cannot get spi_if")
    endfunction

    //Timeout
    task axi_write(input logic [3:0] addr, input logic [31:0] data);
        int timeout_aw, timeout_w, timeout_b;

        @(posedge s_if.clk);
        // AW + W 
        s_if.awaddr  <= addr;
        s_if.awvalid <= 1'b1;
        s_if.wdata   <= data;
        s_if.wstrb   <= 4'hF;
        s_if.wvalid  <= 1'b1;

        // AW / W  병렬 handshake
        fork
            begin  // AW Channel
                timeout_aw = 0;
                while (!s_if.awready) begin
                    @(posedge s_if.clk);
                    if (++timeout_aw > 200)
                        `uvm_fatal("AXI_TIMEOUT", $sformatf(
                                   "awready timeout addr=%0h", addr))
                end
                @(posedge s_if.clk);
                s_if.awvalid <= 1'b0;
            end
            begin  // W Channel
                timeout_w = 0;
                while (!s_if.wready) begin
                    @(posedge s_if.clk);
                    if (++timeout_w > 200)
                        `uvm_fatal("AXI_TIMEOUT", $sformatf(
                                   "wready timeout addr=%0h", addr))
                end
                @(posedge s_if.clk);
                s_if.wvalid <= 1'b0;
            end
        join

        // B Channel
        s_if.bready <= 1'b1;
        timeout_b = 0;
        while (!s_if.bvalid) begin
            @(posedge s_if.clk);
            if (++timeout_b > 200) `uvm_fatal("AXI_TIMEOUT", "bvalid timeout")
        end
        @(posedge s_if.clk);
        s_if.bready <= 1'b0;
    endtask

    // axi_read 
    task axi_read(input logic [3:0] addr, output logic [31:0] data);
        int timeout;

        @(posedge s_if.clk);
        s_if.araddr  <= addr;
        s_if.arvalid <= 1'b1;

        timeout = 0;
        while (!s_if.arready) begin
            @(posedge s_if.clk);
            if (++timeout > 200)
                `uvm_fatal("AXI_TIMEOUT", $sformatf(
                           "arready timeout at addr=%0h", addr))
        end
        @(posedge s_if.clk);
        s_if.arvalid <= 1'b0;

        s_if.rready  <= 1'b1;
        timeout = 0;
        while (!s_if.rvalid) begin
            @(posedge s_if.clk);
            if (++timeout > 200) `uvm_fatal("AXI_TIMEOUT", "rvalid timeout")
        end
        data = s_if.rdata;
        @(posedge s_if.clk);
        s_if.rready <= 1'b0;
    endtask


    virtual task run_phase(uvm_phase phase);
        logic [31:0] rdata;

        s_if.awvalid <= 0;
        s_if.wvalid <= 0;
        s_if.bready <= 0;
        s_if.arvalid <= 0;
        s_if.rready <= 0;
        s_if.s_tx_data <= 8'h00;

        wait (s_if.reset_n === 1'b1);
        repeat (10) @(posedge s_if.clk);

        forever begin
            seq_item_port.get_next_item(req);

            // Slave TX Data
            s_if.s_tx_data <= req.s_tx_data;
            @(posedge s_if.clk);

            // 1. TX Write data (0x04)
            axi_write(4'h4, req.m_tx_data);

            // 2. Start Pulse (0x00)
            axi_write(4'h0, 32'h8000_0400);
            axi_write(4'h0, 32'h0000_0400);

            // 3. Busy  (0x08)
            do begin
                axi_read(4'h8, rdata);
            end while ((rdata & 32'h0000_0002) != 0);

            // RX Read (0x0C)
            axi_read(4'hC, rdata);

            seq_item_port.item_done();
        end
    endtask
endclass


class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)
    virtual spi_if s_if;
    uvm_analysis_port #(spi_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "s_if", s_if))
            `uvm_fatal("NO_VIF", "Cannot get spi_if")
    endfunction

    virtual task run_phase(uvm_phase phase);
        spi_seq_item item;
        logic [7:0] temp_m_tx;
        logic [7:0] temp_s_tx;
        logic [3:0] cur_araddr;

        cur_araddr = 4'h0;

        forever begin
            @(posedge s_if.clk);

            //  Master->TX write(AXI Write addr=0x04)
            if (s_if.awvalid && s_if.awready && s_if.awaddr == 4'h4) begin
                temp_m_tx = s_if.wdata[7:0];
                temp_s_tx = s_if.s_tx_data;
            end

            // AXI Read ADDR
            if (s_if.arvalid && s_if.arready) begin
                cur_araddr = s_if.araddr;
            end

            //  Master RX Data (AXI Read addr=0x0C)
            if (s_if.rvalid && s_if.rready && cur_araddr == 4'hC) begin
                item = spi_seq_item::type_id::create("item");

                item.m_tx_data = {24'h0, temp_m_tx};
                item.s_tx_data = temp_s_tx;
                item.m_rx_data = s_if.rdata[7:0]; 
                item.s_rx_data = s_if.s_rx_data;  

                `uvm_info(
                    "MON",
                    $sformatf(
                        "TRXN: M_TX(%0h)->S_RX(%0h) | S_TX(%0h)->M_RX(%0h)",
                        item.m_tx_data, item.s_rx_data, item.s_tx_data,
                        item.m_rx_data), UVM_LOW)

                ap.write(item);
            end
        end
    endtask
endclass



class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)

    spi_driver drv;
    spi_monitor mon;
    uvm_sequencer #(spi_seq_item) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = spi_driver::type_id::create("drv", this);
        mon = spi_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(spi_seq_item)::type_id::create("sqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass



class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)

    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) ap_imp;

    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    virtual function void write(spi_seq_item item);
        bit is_pass = 1'b1;
        `uvm_info(get_type_name(), "--- Scoreboard Check ---", UVM_HIGH)

        // Check : Master TX → Slave RX 
        if (item.m_tx_data[7:0] !== item.s_rx_data) begin
            `uvm_error(get_type_name(),
                       $sformatf("[FAIL] M_TX(%0h) != S_RX(%0h)",
                                 item.m_tx_data[7:0], item.s_rx_data))
            is_pass = 1'b0;
        end

        // Check : Slave TX → Master RX 
        if (item.s_tx_data !== item.m_rx_data) begin
            `uvm_error(get_type_name(), $sformatf(
                                            "[FAIL] S_TX(%0h) != M_RX(%0h)",
                                            item.s_tx_data, item.m_rx_data))
            is_pass = 1'b0;
        end

        if (is_pass) begin
            pass_cnt++;
            `uvm_info(get_type_name(),
                      $sformatf("[PASS] M_TX=%0h S_RX=%0h | S_TX=%0h M_RX=%0h",
                                item.m_tx_data[7:0], item.s_rx_data,
                                item.s_tx_data, item.m_rx_data), UVM_LOW)
        end else begin
            fail_cnt++;
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "===== Scoreboard Summary =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" Total : %0d", pass_cnt + fail_cnt
                  ), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" Pass  : %0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" Fail  : %0d", fail_cnt), UVM_LOW)

        if (fail_cnt > 0)
            `uvm_error(get_type_name(), $sformatf(
                       "Test FAILED: %0d mismatches!", fail_cnt))
        else
            `uvm_info(get_type_name(), "Test PASSED: All transactions matched.",
                      UVM_LOW)

        `uvm_info(get_type_name(), "==============================\n", UVM_LOW)
    endfunction
endclass


class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)

    spi_agent      agt;
    spi_scoreboard scb;
    spi_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = spi_agent::type_id::create("agt", this);
        scb = spi_scoreboard::type_id::create("scb", this);
        cov = spi_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass



class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    spi_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = spi_env::type_id::create("env", this);
    endfunction
endclass



class spi_rand_test extends base_test;
    `uvm_component_utils(spi_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 필요 시 여기서 config_db 오버라이드 가능
    endfunction

    virtual task run_phase(uvm_phase phase);
        spi_rand_sequence seq;
        `uvm_info(get_type_name(), "SPI Random Test Start", UVM_LOW)

        phase.raise_objection(this);

        seq = spi_rand_sequence::type_id::create("seq");
        seq.start(env.agt.sqr);

        phase.drop_objection(this);
        `uvm_info(get_type_name(), "SPI Random Test Complete", UVM_NONE)
    endtask
endclass



module tb_spi ();
    bit clk;
    bit reset_n;

    spi_if s_if (
        .clk    (clk),
        .reset_n(reset_n)
    );


    AXI_SPI_v1_0 #(
        .C_S00_AXI_DATA_WIDTH(32),
        .C_S00_AXI_ADDR_WIDTH(4)
    ) dut (
        .sclk           (s_if.sclk),
        .mosi           (s_if.mosi),
        .miso           (s_if.miso),
        .cs_n           (s_if.cs_n),
        .s00_axi_aclk   (clk),
        .s00_axi_aresetn(reset_n),
        .s00_axi_awaddr (s_if.awaddr),
        .s00_axi_awprot (s_if.awprot),
        .s00_axi_awvalid(s_if.awvalid),
        .s00_axi_awready(s_if.awready),
        .s00_axi_wdata  (s_if.wdata),
        .s00_axi_wstrb  (s_if.wstrb),
        .s00_axi_wvalid (s_if.wvalid),
        .s00_axi_wready (s_if.wready),
        .s00_axi_bresp  (s_if.bresp),
        .s00_axi_bvalid (s_if.bvalid),
        .s00_axi_bready (s_if.bready),
        .s00_axi_araddr (s_if.araddr),
        .s00_axi_arprot (s_if.arprot),
        .s00_axi_arvalid(s_if.arvalid),
        .s00_axi_arready(s_if.arready),
        .s00_axi_rdata  (s_if.rdata),
        .s00_axi_rresp  (s_if.rresp),
        .s00_axi_rvalid (s_if.rvalid),
        .s00_axi_rready (s_if.rready)
    );
    logic s_reset;
    assign s_reset = ~reset_n;  

    logic cpol = 1'b0;
    logic cpha = 1'b0;
    logic s_done;
    logic s_busy;

    spi_slave U_SPI_SLAVE (
        .clk(clk),
        .reset(s_reset),  
        .sclk(s_if.sclk),  
        .mosi(s_if.mosi),  
        .cs_n(s_if.cs_n),  
        .miso(s_if.miso),  
        .tx_data (s_if.s_tx_data),   
        .rx_data (s_if.s_rx_data),   
        .cpol(cpol),
        .cpha(cpha),
        .done(s_done),
        .busy(s_busy)
    );

        initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset_n = 0;
        #20;
        reset_n = 1;
    end

    
    initial begin
        uvm_config_db#(virtual spi_if)::set(null, "*", "s_if", s_if);
        run_test("spi_rand_test");
    end

    
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_spi, "all");
    end

endmodule
