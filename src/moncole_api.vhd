library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity monocle_api is
  port (
    signal reset : in std_ulogic;
    signal clk : in std_ulogic;
    signal p_ext_api_start : in std_ulogic;
    signal p_ext_api_strobe : in std_ulogic;
    signal p_ext_api_next : in std_ulogic;
    signal p_ext_api_din : in std_ulogic_vector(7 downto 0);
    signal p_ext_api_dout : out std_ulogic_vector(7 downto 0);
    signal p_ext_api_oe : out std_ulogic;
    signal p_system_status_val_o_u_t : in std_ulogic_vector(31 downto 0);
    signal p_system_ID_val_o_u_t : in std_ulogic_vector(15 downto 0);
    signal p_system_version_val_o_u_t : in std_ulogic_vector(23 downto 0);
    signal p_capture_status_val_o_u_t : in std_ulogic_vector(15 downto 0);
    signal p_capture_memout_read_rdy : in std_ulogic;
    signal p_capture_memout_read_req : out std_ulogic;
    signal p_capture_memout_val_o_u_t : in std_ulogic_vector(7 downto 0);
    signal p_capture_apisig_write_rdy : in std_ulogic;
    signal p_capture_apisig_write_req : out std_ulogic;
    signal p_capture_apisig_val : out std_ulogic_vector(7 downto 0);
    signal p_graphics_base_val : out std_ulogic_vector(31 downto 0);
    signal p_graphics_memin_write_rdy : out std_ulogic;
    signal p_graphics_memin_write_req : in std_ulogic;
    signal p_graphics_memin_val : out std_ulogic_vector(7 downto 0);
    signal p_graphics_apisig_write_rdy : in std_ulogic;
    signal p_graphics_apisig_write_req : out std_ulogic;
    signal p_graphics_apisig_val : out std_ulogic_vector(7 downto 0);
    signal p_camera_status_val_o_u_t : in std_ulogic_vector(7 downto 0);
    signal p_camera_frame_val_o_u_t : in std_ulogic_vector(31 downto 0);
    signal p_camera_zoom_val : out std_ulogic_vector(7 downto 0);
    signal p_camera_histogram_read_rdy : in std_ulogic;
    signal p_camera_histogram_read_req : out std_ulogic;
    signal p_camera_histogram_val_o_u_t : in std_ulogic_vector(7 downto 0);
    signal p_camera_config_write_rdy : out std_ulogic;
    signal p_camera_config_write_req : in std_ulogic;
    signal p_camera_config_val : out std_ulogic_vector(7 downto 0);
    signal p_camera_apisig_write_rdy : in std_ulogic;
    signal p_camera_apisig_write_req : out std_ulogic;
    signal p_camera_apisig_val : out std_ulogic_vector(7 downto 0);
    signal p_video_status_val_o_u_t : in std_ulogic_vector(7 downto 0);
    signal p_video_speed_val : out std_ulogic_vector(7 downto 0);
    signal p_video_apisig_write_rdy : in std_ulogic;
    signal p_video_apisig_write_req : out std_ulogic;
    signal p_video_apisig_val : out std_ulogic_vector(7 downto 0);
    signal p_display_status_val_o_u_t : in std_ulogic_vector(7 downto 0);
    signal p_display_apisig_write_rdy : in std_ulogic;
    signal p_display_apisig_write_req : out std_ulogic;
    signal p_display_apisig_val : out std_ulogic_vector(7 downto 0));
end entity;

architecture rtl of monocle_api is

  function as_bit(L: BOOLEAN) return std_ulogic is
  begin
    if L then
      return('1');
    else
      return('0');
    end if;
  end function as_bit;

  signal reg_we : std_ulogic;
  signal reg_cap : std_ulogic;
  signal datain_we : std_ulogic;
  signal datain_we_d : std_ulogic;
  signal datain_vld : std_ulogic_vector(3 downto 0);
  signal datain_reg : std_ulogic_vector(31 downto 0);
  signal device_match : std_ulogic_vector(5 downto 0);
  signal device : std_ulogic_vector(5 downto 0);
  signal system_status_data_reg : std_ulogic_vector(31 downto 0);
  signal system_status_sel : std_ulogic;
  signal system_ID_data_reg : std_ulogic_vector(15 downto 0);
  signal system_ID_sel : std_ulogic;
  signal system_version_data_reg : std_ulogic_vector(23 downto 0);
  signal system_version_sel : std_ulogic;
  signal capture_status_data_reg : std_ulogic_vector(15 downto 0);
  signal capture_status_sel : std_ulogic;
  signal capture_memout_sel : std_ulogic;
  signal graphics_base_reg : std_ulogic_vector(31 downto 0);
  signal graphics_base_en : std_ulogic;
  signal graphics_base_sel : std_ulogic;
  signal graphics_memin_sel : std_ulogic;
  signal graphics_memin_wr : std_ulogic;
  signal graphics_memin_reg : std_ulogic_vector(7 downto 0);
  signal camera_status_data_reg : std_ulogic_vector(7 downto 0);
  signal camera_status_sel : std_ulogic;
  signal camera_frame_data_reg : std_ulogic_vector(31 downto 0);
  signal camera_frame_sel : std_ulogic;
  signal camera_zoom_reg : std_ulogic_vector(7 downto 0);
  signal camera_zoom_en : std_ulogic;
  signal camera_zoom_sel : std_ulogic;
  signal camera_histogram_sel : std_ulogic;
  signal camera_config_sel : std_ulogic;
  signal camera_config_wr : std_ulogic;
  signal camera_config_reg : std_ulogic_vector(7 downto 0);
  signal video_status_data_reg : std_ulogic_vector(7 downto 0);
  signal video_status_sel : std_ulogic;
  signal video_speed_reg : std_ulogic_vector(7 downto 0);
  signal video_speed_en : std_ulogic;
  signal video_speed_sel : std_ulogic;
  signal display_status_data_reg : std_ulogic_vector(7 downto 0);
  signal display_status_sel : std_ulogic;
begin
  reg_we <= p_ext_api_next and reg_cap;
  datain_we <= (p_ext_api_next and (not reg_cap)) and (not p_ext_api_start);
  device_match(0) <= as_bit(p_ext_api_din = X"00");
  device_match(1) <= as_bit(p_ext_api_din = X"50");
  p_capture_memout_read_req <= capture_memout_sel and p_ext_api_strobe;
  p_capture_apisig_write_req <= (device(1) and reg_we) and as_bit(p_ext_api_din = X"04");
  p_capture_apisig_val <= p_ext_api_din;
  device_match(2) <= as_bit(p_ext_api_din = X"44");
  graphics_base_en <= (graphics_base_sel and datain_we_d) and datain_vld(3);
  p_graphics_base_val <= graphics_base_reg;
  p_graphics_memin_val <= graphics_memin_reg;
  p_graphics_memin_write_rdy <= graphics_memin_wr;
  p_graphics_apisig_write_req <= (device(2) and reg_we) and as_bit((p_ext_api_din = X"04") or (p_ext_api_din = X"05"));
  p_graphics_apisig_val <= p_ext_api_din;
  device_match(3) <= as_bit(p_ext_api_din = X"10");
  camera_zoom_en <= (camera_zoom_sel and datain_we_d) and datain_vld(0);
  p_camera_zoom_val <= camera_zoom_reg;
  p_camera_histogram_read_req <= camera_histogram_sel and p_ext_api_strobe;
  p_camera_config_val <= camera_config_reg;
  p_camera_config_write_rdy <= camera_config_wr;
  p_camera_apisig_write_req <= (device(3) and reg_we) and as_bit(((((p_ext_api_din = X"04") or (p_ext_api_din = X"05")) or (p_ext_api_din = X"06")) or (p_ext_api_din = X"09")) or (p_ext_api_din = X"08"));
  p_camera_apisig_val <= p_ext_api_din;
  device_match(4) <= as_bit(p_ext_api_din = X"30");
  video_speed_en <= (video_speed_sel and datain_we_d) and datain_vld(0);
  p_video_speed_val <= video_speed_reg;
  p_video_apisig_write_req <= (device(4) and reg_we) and as_bit((((p_ext_api_din = X"04") or (p_ext_api_din = X"05")) or (p_ext_api_din = X"06")) or (p_ext_api_din = X"07"));
  p_video_apisig_val <= p_ext_api_din;
  device_match(5) <= as_bit(p_ext_api_din = X"40");
  p_display_apisig_write_req <= (device(5) and reg_we) and as_bit((p_ext_api_din = X"05") or (p_ext_api_din = X"04"));
  p_display_apisig_val <= p_ext_api_din;
  p_ext_api_oe <= ((((((((system_status_sel or system_ID_sel) or system_version_sel) or capture_status_sel) or capture_memout_sel) or camera_status_sel) or camera_frame_sel) or camera_histogram_sel) or video_status_sel) or display_status_sel;
  p_ext_api_dout <=
    system_status_data_reg(31 downto 24) when system_status_sel = '1' else
    system_ID_data_reg(15 downto 8) when system_ID_sel = '1' else
    system_version_data_reg(23 downto 16) when system_version_sel = '1' else
    capture_status_data_reg(15 downto 8) when capture_status_sel = '1' else
    p_capture_memout_val_o_u_t when capture_memout_sel = '1' else
    p_camera_status_val_o_u_t when camera_status_sel = '1' else
    camera_frame_data_reg(31 downto 24) when camera_frame_sel = '1' else
    p_camera_histogram_val_o_u_t when camera_histogram_sel = '1' else
    p_video_status_val_o_u_t when video_status_sel = '1' else
    p_display_status_val_o_u_t when display_status_sel = '1' else
    X"66";
  process (reset, clk)
  begin
    if (clk'event and clk='1') then
      if reset = '1' then
        reg_cap <= '0';
      elsif p_ext_api_next = '1' then
        reg_cap <= p_ext_api_start;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      datain_we_d <= datain_we;
    end if;
  end process;
  process (reset, clk)
  begin
    if (clk'event and clk='1') then
      if reset = '1' then
        datain_vld <= X"0";
      elsif (p_ext_api_start or reg_we) = '1' then
        datain_vld <= X"0";
      elsif datain_we = '1' then
        datain_vld <= datain_vld(2 downto 0) & "1";
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if datain_we = '1' then
        datain_reg <= datain_reg(23 downto 0) & p_ext_api_din;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        device <= device_match;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if (p_ext_api_next and device(0)) = '1' then
        if reg_cap = '1' then
          system_status_data_reg <= p_system_status_val_o_u_t;
        else
          system_status_data_reg <= std_ulogic_vector(shl(unsigned(system_status_data_reg),CONV_UNSIGNED(8,4)));
        end if;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        system_status_sel <= '0';
      elsif reg_we = '1' then
        system_status_sel <= device(0) and as_bit(p_ext_api_din = X"00");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if (p_ext_api_next and device(0)) = '1' then
        if reg_cap = '1' then
          system_ID_data_reg <= p_system_ID_val_o_u_t;
        else
          system_ID_data_reg <= std_ulogic_vector(shl(unsigned(system_ID_data_reg),CONV_UNSIGNED(8,4)));
        end if;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        system_ID_sel <= '0';
      elsif reg_we = '1' then
        system_ID_sel <= device(0) and as_bit(p_ext_api_din = X"01");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if (p_ext_api_next and device(0)) = '1' then
        if reg_cap = '1' then
          system_version_data_reg <= p_system_version_val_o_u_t;
        else
          system_version_data_reg <= std_ulogic_vector(shl(unsigned(system_version_data_reg),CONV_UNSIGNED(8,4)));
        end if;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        system_version_sel <= '0';
      elsif reg_we = '1' then
        system_version_sel <= device(0) and as_bit(p_ext_api_din = X"02");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if (p_ext_api_next and device(1)) = '1' then
        if reg_cap = '1' then
          capture_status_data_reg <= p_capture_status_val_o_u_t;
        else
          capture_status_data_reg <= std_ulogic_vector(shl(unsigned(capture_status_data_reg),CONV_UNSIGNED(8,4)));
        end if;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        capture_status_sel <= '0';
      elsif reg_we = '1' then
        capture_status_sel <= device(1) and as_bit(p_ext_api_din = X"00");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        capture_memout_sel <= '0';
      elsif reg_we = '1' then
        capture_memout_sel <= device(1) and as_bit(p_ext_api_din = X"10");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if graphics_base_en = '1' then
        graphics_base_reg <= datain_reg(31 downto 0);
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        graphics_base_sel <= '0';
      elsif reg_we = '1' then
        graphics_base_sel <= device(2) and as_bit(p_ext_api_din = X"10");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        graphics_memin_sel <= '0';
      elsif reg_we = '1' then
        graphics_memin_sel <= device(2) and as_bit(p_ext_api_din = X"11");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      graphics_memin_wr <= graphics_memin_sel and datain_we;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if datain_we = '1' then
        graphics_memin_reg <= p_ext_api_din;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        camera_status_sel <= '0';
      elsif reg_we = '1' then
        camera_status_sel <= device(3) and as_bit(p_ext_api_din = X"00");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if (p_ext_api_next and device(3)) = '1' then
        if reg_cap = '1' then
          camera_frame_data_reg <= p_camera_frame_val_o_u_t;
        else
          camera_frame_data_reg <= std_ulogic_vector(shl(unsigned(camera_frame_data_reg),CONV_UNSIGNED(8,4)));
        end if;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        camera_frame_sel <= '0';
      elsif reg_we = '1' then
        camera_frame_sel <= device(3) and as_bit(p_ext_api_din = X"01");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if camera_zoom_en = '1' then
        camera_zoom_reg <= datain_reg(7 downto 0);
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        camera_zoom_sel <= '0';
      elsif reg_we = '1' then
        camera_zoom_sel <= device(3) and as_bit(p_ext_api_din = X"02");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        camera_histogram_sel <= '0';
      elsif reg_we = '1' then
        camera_histogram_sel <= device(3) and as_bit(p_ext_api_din = X"20");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        camera_config_sel <= '0';
      elsif reg_we = '1' then
        camera_config_sel <= device(3) and as_bit(p_ext_api_din = X"28");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      camera_config_wr <= camera_config_sel and datain_we;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if datain_we = '1' then
        camera_config_reg <= p_ext_api_din;
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        video_status_sel <= '0';
      elsif reg_we = '1' then
        video_status_sel <= device(4) and as_bit(p_ext_api_din = X"00");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if video_speed_en = '1' then
        video_speed_reg <= datain_reg(7 downto 0);
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        video_speed_sel <= '0';
      elsif reg_we = '1' then
        video_speed_sel <= device(4) and as_bit(p_ext_api_din = X"03");
      end if;
    end if;
  end process;
  process (clk)
  begin
    if (clk'event and clk='1') then
      if p_ext_api_start = '1' then
        display_status_sel <= '0';
      elsif reg_we = '1' then
        display_status_sel <= device(5) and as_bit(p_ext_api_din = X"00");
      end if;
    end if;
  end process;
end architecture;
