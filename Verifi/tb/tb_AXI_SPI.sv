`timescale 1ns/1ps   
`include "uvm_macros.svh"
import uvm_pkg::*;



interface spi_if(input logic clk, input logic reset_n);

    // AXI4-Lite Signals
    logic [3:0]  awaddr;
    logic [2:0]  awprot;
    logic        awvalid;
    logic        awready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;
    logic [3:0]  araddr;
    logic [2:0]  arprot;
    logic        arvalid;
    logic        arready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    // Physical SPI Signals
    logic        sclk;
    logic        mosi;
    logic        miso;
    logic        cs_n;

    // --- AXI Write Task ---
    task axi_write(input [3:0] addr, input [31:0] data);
        @(posedge clk);
        awaddr <= addr;
        awvalid <= 1'b1;
        wdata <= data;
        wstrb <= 4'hF;
        wvalid <= 1'b1;
        bready <= 1'b1;

        wait(awready && wready);
        @(posedge clk);
        awvalid <= 1'b0;
        wvalid <= 1'b0;

        wait(bvalid);
        @(posedge clk);
        bready <= 1'b0;
    endtask

    // --- AXI Read Task ---
    task axi_read(input [3:0] addr, output [31:0] data);
        @(posedge clk);
        araddr <= addr;
        arvalid <= 1'b1;
        rready <= 1'b1;

        wait(arready);
        @(posedge clk);
        arvalid <= 1'b0;

        wait(rvalid);
        data = rdata;
        @(posedge clk);
        rready <= 1'b0;
    endtask

endinterface


class spi_seq_item extends uvm_sequence_item;
    
    rand bit [7:0] m_tx_data;

    bit [7:0] m_rx_data;
    bit [7:0] s_rx_data;

    `uvm_object_utils_begin(spi_seq_item)
        `uvm_field_int(m_tx_data, UVM_ALL_ON)
        `uvm_field_int(m_rx_data, UVM_ALL_ON)
        `uvm_field_int(s_rx_data, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_m_tx_data{
        m_tx_data dist{
            8'h00 :/ 1,  //ALL ZERO
            8'hFF :/ 1,  //ALL one
            8'h55 :/ 1, //01010101
            8'hAA :/ 1, //10101010
            [8'h01:8'hFE] :/ 5 //Left Rand 
        };
    }

function new(string name = "spi_seq_item");
    super.new(name);
endfunction


    function string convert2string();
        return $sformatf( "M_TX=0x%h | M_RX=0x%h | S_RX=0x%h", 
                        m_tx_data, m_rx_data, s_rx_data);
    endfunction
endclass //className

class spi_rand_sequence extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_rand_sequence)


    function new(string name = "spi_rand_sequence");
        super.new(name);
    endfunction  //new()

    virtual task body();
        spi_seq_item req;

        `uvm_info("SEQ", "SPI Basic Sequence Started", UVM_LOW)

        for (int i = 0; i < 10000; i++) begin
            req = spi_seq_item::type_id::create("req");


            start_item(req);
            if (!req.randomize()) begin
                `uvm_error("SEQ", "Randomization Failed")
            end

            finish_item(req);
        end
        `uvm_info("SEQ", "SPI Basic Sequence Finished ", UVM_LOW)
    endtask
endclass  //className





class spi_coverage extends uvm_subscriber #(spi_seq_item);
    `uvm_component_utils(spi_coverage)

    spi_seq_item item;


    covergroup spi_data_cg;
        cp_m_tx_data: coverpoint item.m_tx_data {
            bins all_zero = {8'h00};
            bins all_one = {8'hFF};
            bins alternating = {8'h55, 8'hAA};
            bins walking_ones  = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
            bins walking_zeros = {8'hFE, 8'hFD, 8'hFB, 8'hF7, 8'hEF, 8'hDF, 8'hBF, 8'h7F};
            bins random_others = default;
        }

    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        spi_data_cg = new();
    endfunction  //new()

    virtual function void write(spi_seq_item s);
        item = s;
        spi_data_cg.sample();
        `uvm_info(get_type_name(), $sformatf(
                  "Coverage Sample: %0h", item.m_tx_data), UVM_HIGH)

    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "====== Coverage Summary =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  " Overall: %.1f%%", spi_data_cg.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  " m_tx_data: %.1f%%", spi_data_cg.cp_m_tx_data.get_coverage()
                  ), UVM_LOW)
        `uvm_info(get_type_name(), " ====== Coverage Summary ===== \n\n",
                  UVM_LOW);

    endfunction



endclass  //className


class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)
    virtual spi_if s_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "s_if", s_if)) begin
            `uvm_fatal(get_type_name(), "Cannot get spi_if from config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        logic [31:0] rdata;
        
        // Clear
        s_if.awvalid <= 0; s_if.wvalid <= 0; s_if.bready <= 0;
        s_if.arvalid <= 0; s_if.rready <= 0;
        wait(s_if.reset_n == 1'b1);

        forever begin
            seq_item_port.get_next_item(req);

            // 1. tx_data write (slv_reg1 : offset 0x04)
            s_if.axi_write(4'h4, {24'b0, req.m_tx_data});

            // 2. Control write start pulse (slv_reg0 : offset 0x00)
            s_if.axi_write(4'h0, 32'h8000_0400); 
             //start bit clear
            s_if.axi_write(4'h0, 32'h0000_0400); 

            // 3. done (slv_reg2 : offset 0x08) -> {30'b0, busy, done}
            do begin
                s_if.axi_read(4'h8, rdata);
            end while ((rdata & 32'h2) != 0); // bit[0] wait busy 1

            // 4. rx_data Read (slv_reg3 : offset 0x0C)
            s_if.axi_read(4'hC, rdata);
            req.m_rx_data = rdata[7:0];
            
            //  s_rx_data Scoreboard 
            req.s_rx_data = rdata[7:0]; 

            `uvm_info(get_type_name(), req.convert2string(), UVM_MEDIUM)
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
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "s_if", s_if)) begin
            `uvm_fatal(get_type_name(), "Cannot get spi_if from config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        spi_seq_item item;
        logic [7:0] temp_tx;
        
        forever begin
            @(posedge s_if.clk);
            
            // Write Channel-> tx_data  (offset 0x04)
            if (s_if.wvalid && s_if.wready && s_if.awaddr == 4'h4) begin
                temp_tx = s_if.wdata[7:0];
            end

            // Read Channel -> rx_data  (offset 0x0C)
            if (s_if.rvalid && s_if.rready) begin
                if(s_if.araddr == 4'hC)begin
                item = spi_seq_item::type_id::create("item");
                item.m_tx_data = temp_tx;
                item.m_rx_data = s_if.rdata[7:0];
                item.s_rx_data = s_if.rdata[7:0]; // Loopback 
                
                `uvm_info("MON", $sformatf("Captured AXI! m_tx: %0h, m_rx: %0h", 
                          item.m_tx_data, item.m_rx_data), UVM_LOW)
                ap.write(item);
                end
            end
        end
    endtask
endclass

class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)
    
    spi_driver drv;
    spi_monitor mon;
    uvm_sequencer#(spi_seq_item) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction //new()

    ///build
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = spi_driver::type_id::create("drv",this);
        mon = spi_monitor::type_id::create("mon",this);
        sqr = uvm_sequencer#(spi_seq_item)::type_id::create("sqr",this);
    endfunction

    //connect
    virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);                
    endfunction

    ///run
    virtual task run_phase(uvm_phase phase );

    endtask //automatic
endclass //className

class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)

    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) ap_imp;

    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    ///build
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    virtual function void write(spi_seq_item item);
        bit is_pass = 1'b1;

        `uvm_info(get_type_name(), "---Scoreboard Start ---", UVM_LOW)


        if (item.m_tx_data !== item.s_rx_data) begin
            `uvm_error(get_type_name(),
                       $sformatf(
                           "Mismatch Master send: %0h, Slave received: %0h ",
                           item.m_tx_data, item.s_rx_data))
            is_pass = 1'b0;
        end

        if (is_pass) begin
            pass_cnt++;
            `uvm_info(get_type_name(), $sformatf("MATCH M_tx: %0h, S_rx:%0h  ",
                                                 item.m_tx_data,
                                                 item.s_rx_data), UVM_LOW)
        end else begin
            fail_cnt++;
        end

        `uvm_info(get_type_name(), "-------------------", UVM_LOW)
    endfunction


    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), " ===== Scoreboard Summary ===== ", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  " Total transaction: %0d", pass_cnt + fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" Matches:%0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Error: %d", fail_cnt), UVM_LOW)

        if (fail_cnt > 0) begin
            `uvm_info(get_type_name(),
                      $sformatf("Test faild: %0d mismatches detected!",
                                fail_cnt), UVM_LOW)

        end else begin
            `uvm_info(get_type_name(), $sformatf(
                      "Test Passed: %0d all matches detected", pass_cnt),
                      UVM_LOW)
        end
    endfunction

endclass  //className

class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)
    
    spi_agent agt;
    spi_scoreboard scb;
    spi_coverage cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction //new()

    ///build
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = spi_agent::type_id::create("agt",this);
        scb = spi_scoreboard::type_id::create("scb",this);
        cov = spi_coverage::type_id::create("cov",this);
    endfunction

    //connect
    virtual function void connect_phase(uvm_phase phase);
         super.connect_phase(phase);
         agt.mon.ap.connect(scb.ap_imp);
         agt.mon.ap.connect(cov.analysis_export);       
    endfunction


endclass //className





class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    spi_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        env = spi_env::type_id::create("env",this);
    endfunction  //new()

    ///build
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction


    /////run
    //virtual task run_phase(uvm_phase phase);
    //    phase.raise_objection(this);
    //
    //    run_test_seq();
    //    phase.drop_objection(this);
    //    `uvm_info("TEST", "spi test 완료", UVM_NONE)
    //
    //endtask  //automatic



endclass  //className


class spi_rand_test extends base_test;
    `uvm_component_utils(spi_rand_test)


    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()
    ///build
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual task run_phase(uvm_phase phase);
        spi_rand_sequence seq;
        `uvm_info(get_type_name(), "SPI RANDOM test start", UVM_LOW)


        phase.raise_objection(this);

        `uvm_info("TEST", "Starting test....", UVM_LOW)
        seq = spi_rand_sequence::type_id::create("seq");

        seq.start(env.agt.sqr);

        `uvm_info(get_type_name(), "Complete", UVM_LOW)


        phase.drop_objection(this);
        `uvm_info("TEST", "spi test 완료", UVM_NONE)


    endtask



endclass  //className

module tb_spi ();
    bit clk;
    bit reset_n;

    spi_if s_if(
        .clk(clk),
        .reset_n(reset_n)
    );

    // MISO를 MOSI에 연결하여 루프백(Loopback) 검증 수행
    assign s_if.miso = s_if.mosi;

    AXI_SPI_v1_0 #(
        .C_S00_AXI_DATA_WIDTH(32),
        .C_S00_AXI_ADDR_WIDTH(4)
    ) dut (
        .sclk(s_if.sclk),
        .mosi(s_if.mosi),
        .miso(s_if.miso),
        .cs_n(s_if.cs_n),

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