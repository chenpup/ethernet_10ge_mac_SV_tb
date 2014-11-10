program testcase (  interface tcif  );

  reg [7:0]     tx_buffer[0:10000];
  integer       tx_length;
  integer       tx_count;
  integer       rx_count;

 
  initial begin
    tx_count = 0;
    rx_count = 0;
    
    tcif.cb.wb_adr_i    <= 8'b0;
    tcif.cb.wb_clk_i    <= 1'b0;
    tcif.cb.wb_cyc_i    <= 1'b0;
    tcif.cb.wb_dat_i    <= 32'b0;
    tcif.cb.wb_rst_i    <= 1'b1;
    tcif.cb.wb_stb_i    <= 1'b0;
    tcif.cb.wb_we_i     <= 1'b0;
  end

  // Reset generation
  initial begin
    tcif.cb.reset_156m25_n <= 1'b0;
    tcif.cb.reset_xgmii_rx_n <= 1'b0;
    tcif.cb.reset_xgmii_tx_n <= 1'b0;
    WaitNS(20);
    tcif.cb.reset_156m25_n <= 1'b1;
    tcif.cb.reset_xgmii_rx_n <= 1'b1;
    tcif.cb.reset_xgmii_tx_n <= 1'b1;
  end

  // Init signals
  initial begin
    for (tx_length = 0; tx_length <= 1000; tx_length = tx_length + 1) begin
      tx_buffer[tx_length] = 0;
    end
    tcif.cb.pkt_rx_ren <= 1'b0;
    tcif.cb.pkt_tx_data <= 64'b0;
    tcif.cb.pkt_tx_val <= 1'b0;
    tcif.cb.pkt_tx_sop <= 1'b0;
    tcif.cb.pkt_tx_eop <= 1'b0;
    tcif.cb.pkt_tx_mod <= 3'b0;
  end

  initial begin
    WaitNS(5000);
    ProcessCmdFile();
  end

  initial begin
    forever begin
      if (tcif.cb.pkt_rx_avail) begin
        RxPacket();
        if (rx_count == tx_count) begin
          $display("All packets received. Sumulation done!!!\n");
        end
      end
      @(posedge tcif.clk_156m25);
    end
  end


  // Other tasks
  task WaitNS(input [31:0] delay);
    begin
      #(1000*delay);
    end
  endtask : WaitNS


  task TxPacket;
    integer     i;
    begin
      $display("Transmit packet with length: %d", tx_length);
      @(posedge tcif.clk_156m25);
      WaitNS(1);
      tcif.cb.pkt_tx_val <= 1'b1;
      for (i = 0; i < tx_length; i = i + 8) begin
        tcif.cb.pkt_tx_sop <= 1'b0;
        tcif.cb.pkt_tx_eop <= 1'b0;
        tcif.cb.pkt_tx_mod <= 2'b0;
        if (i == 0) tcif.cb.pkt_tx_sop <= 1'b1;
        if (i + 8 >= tx_length) begin
          tcif.cb.pkt_tx_eop <= 1'b1;
          tcif.cb.pkt_tx_mod <= tx_length % 8;
        end
        tcif.cb.pkt_tx_data[`LANE7] <= tx_buffer[i];
        tcif.cb.pkt_tx_data[`LANE6] <= tx_buffer[i+1];
        tcif.cb.pkt_tx_data[`LANE5] <= tx_buffer[i+2];
        tcif.cb.pkt_tx_data[`LANE4] <= tx_buffer[i+3];
        tcif.cb.pkt_tx_data[`LANE3] <= tx_buffer[i+4];
        tcif.cb.pkt_tx_data[`LANE2] <= tx_buffer[i+5];
        tcif.cb.pkt_tx_data[`LANE1] <= tx_buffer[i+6];
        tcif.cb.pkt_tx_data[`LANE0] <= tx_buffer[i+7];
        @(posedge tcif.clk_156m25);
        WaitNS(1);
      end
      tcif.cb.pkt_tx_val <= 1'b0;
      tcif.cb.pkt_tx_eop <= 1'b0;
      tcif.cb.pkt_tx_mod <= 3'b0;
      tx_count = tx_count + 1;
    end
  endtask : TxPacket

  task CmdTxPacket(input [31:0] file);
    integer     count;
    integer     data;
    integer     i;
    begin
      count = $fscanf(file, "%2d", tx_length);
      if (count == 1) begin
        for (i = 0; i < tx_length; i = i + 1) begin
          count = $fscanf(file, "%2X", data);
          if (count) begin
            tx_buffer[i] = data;
          end
        end
        TxPacket();
      end
    end
  endtask : CmdTxPacket
  
  task ProcessCmdFile;
    integer         file_cmd;
    integer         count;
    reg [8*8-1:0]   str;
    begin
      file_cmd = $fopen("../testbench/verilog/packets_tx.txt", "r");
      if (!file_cmd) $stop;
      while (!$feof(file_cmd)) begin
        count = $fscanf(file_cmd, "%s", str);
        if (count != 1) continue;
        $display("CMD %s", str);
        case (str)
          "SEND_PKT": begin
                        CmdTxPacket(file_cmd);
                      end  
        endcase
      end
      $fclose(file_cmd);
      WaitNS(50000);
      $finish;
    end
  endtask : ProcessCmdFile

  // Task to read a single packet from receive interface and display
  task RxPacket;
    reg     done;
    begin
      done = 0;
      tcif.cb.pkt_rx_ren <= 1'b1;
      @(posedge tcif.clk_156m25);
      while (!done) begin
        if (tcif.cb.pkt_rx_val) begin
          if (tcif.cb.pkt_rx_sop) begin
            $display("\n\n------------------------");
            $display("Received Packet");
            $display("------------------------");
          end
          $display("%x", tcif.cb.pkt_rx_data);
          if (tcif.cb.pkt_rx_eop) begin
            done <= 1;
            tcif.cb.pkt_rx_ren <= 1'b0;
          end
          if (tcif.cb.pkt_rx_eop) begin
            $display("------------------------\n\n");
          end
        end
        @(posedge tcif.clk_156m25);
      end
      rx_count = rx_count + 1;
    end
  endtask : RxPacket

endprogram
