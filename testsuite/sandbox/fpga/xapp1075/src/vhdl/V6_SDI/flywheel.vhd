-------------------------------------------------------------------------------- 
-- Copyright (c) 2004 Xilinx, Inc. 
-- All Rights Reserved 
-------------------------------------------------------------------------------- 
--   ____  ____ 
--  /   /\/   / 
-- /___/  \  /   Vendor: Xilinx 
-- \   \   \/    Author: John F. Snow, Advanced Product Division, Xilinx, Inc.
--  \   \        Filename: $RCSfile: flywheel.vhd,rcs $
--  /   /        Date Last Modified:  $Date: 2006-07-12 08:16:42-06 $
-- /___/   /\    Date Created: March 11, 2002 
-- \   \  /  \ 
--  \___\/\___\ 
-- 
--
-- Revision History: 
-- $Log: flywheel.vhd,rcs $
-- Revision 1.1  2006-07-12 08:16:42-06  jsnow
-- Previously, the flywheel would tolerate video where the V bit
-- fell early, but would always correct this early falling V by
-- generating and inserting new TRS sequences with corrected V
-- timing. This caused any subsequent EDH processor to detect
-- EDH errors. The flywheel now will not correct the V bit timing
-- during those periods when V might fall early so that EDH errors
-- will not be introduced.
--
-- Revision 1.0  2004-12-15 16:12:43-07  jsnow
-- Header update.
--
-------------------------------------------------------------------------------- 
--   
--   XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" 
--   AS A COURTESY TO YOU, SOLELY FOR USE IN DEVELOPING PROGRAMS AND 
--   SOLUTIONS FOR XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE, 
--   OR INFORMATION AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE, 
--   APPLICATION OR STANDARD, XILINX IS MAKING NO REPRESENTATION 
--   THAT THIS IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT, 
--   AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE 
--   FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY 
--   WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE 
--   IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR 
--   REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF 
--   INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
--   FOR A PARTICULAR PURPOSE. 
--
-------------------------------------------------------------------------------- 
-- 
-- This module implements a video flywheel. Video flywheels are used to add
-- immunity to noise introduced into a video stream.
-- 
-- The flywheel synchronizes to the incoming video by examining the TRS symbols.
-- It then maintains internal horizontal and vertical counters to keep track of 
-- the current position. The flywheel generates its own TRS symbols and compares
-- them to the incoming video. If the position or contents of the TRS symbols in
-- the incoming video doesn't match the flywheel's generated TRS symbols for a 
-- certain period of time, the flywheel will resynchronize to the incoming 
-- video.
-- 
-- This module has the following inputs:
-- 
-- clk: clock input
-- 
-- ce: clock enable input
-- 
-- reset: asynchronous reset input
-- 
-- rx_xyz_in: Asserted when rx_vid_in contains the XYZ word of a TRS symbol.
-- 
-- rx_trs_in: Asserted when rx_vid_in contains the first word of a TRS symbol.
-- 
-- rx_eav_first_in: Asserted when rx_vid_in contains the first word of an EAV.
-- 
-- rx_f_in: This is the latched F bit from the trs_detect module
-- 
-- rx_h_in: This is the latched H bit from the trs_detect module.
-- 
-- std_locked: When this signal is asserted the std_in code is assumed to be 
-- valid.
-- 
-- std_in: A three bit code indicating the video standard of the input video 
-- stream.
-- 
-- rx_xyz_err_in: This input indicates an error in the XYZ word. It is only
-- considered to be valid when rx_xyz_in is asserted.
-- 
-- rx_vid_in: This is the input port for the input video stream.
-- 
-- rx_s4444_in: This input is the S bit from the XYZ word of a 4:4:4:4 video 
-- stream.
-- 
-- rx_anc_in:  Asserted when rx_vid_in contains the first word of an ANC packet.
-- 
-- rx_edh_in: Asserted when rx_vid_in contains the first word of an EDH packet.
-- 
-- en_sync_switch: When this input is asserted, the flywheel will allow
-- synchronous switching.
-- 
-- en_trs_blank: When this input is asserted, the TRS blanking feature is 
-- enabled. When this is enabled, TRS symbols from the input video stream are 
-- replaced with  black level video values if that TRS symbol does not occur 
-- when the flywheel expects a TRS to occur.
-- 
-- This module has the following outputs:
-- 
-- trs: Asserted during all four words of a TRS symbol generated by the 
-- flywheel.
-- 
-- vid_out: This is the output video port.
-- 
-- field: This is the field indicator bit.
-- 
-- v_blank: Vertical blanking interval indicator.
-- 
-- h_blank: Horizontal blanking interval indicator.
-- 
-- horz_count: Current horizontal position of the video stream.
-- 
-- vert_count: Current vertical position of the video stream.
-- 
-- sync_switch: Asserted on lines when synchronous switching is allowed. This 
-- output should be used to disable TRS filtering in the framer of an SDI 
-- receiver during the synchronous switching lines.
-- 
-- locked: This output is asserted when the flywheel is locked to the incoming
-- video stream.
-- 
-- eav_next: This output is asserted the clock cycle before the first word of an
-- EAV appears on vid_out.
-- 
-- sav_next: This output is asserted the clock cycle before the first word of an
-- SAV appears on vid_out.
-- 
-- xyz_word: This output is asserted clock cycle when vid_out contains the XYZ
-- word of a TRS symbol.
-- 
-- anc_next: This output is asserted the clock cycle before the first word of an
-- ancillary data packet appears on vid_out.
-- 
-- edh_next: This output is asserted the clock cycle before the first word of an
-- EDH packet appears on vid_out.
--
-------------------------------------------------------------------------------- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

entity flywheel is
    generic (
        HCNT_WIDTH : integer := 12;
        VCNT_WIDTH : integer := 10);
    port (
        clk:            in    std_ulogic;                   -- clock input
        ce:             in    std_ulogic;                   -- clock enable
        rst:            in    std_ulogic;                   -- async reset input
        rx_xyz_in:      in    std_ulogic;                   -- asserted during XYZ word of received TRS
        rx_trs_in:      in    std_ulogic;                   -- asserted during first word of received TRS
        rx_eav_first_in:in    std_ulogic;                   -- asserted during first word of received EAV
        rx_f_in:        in    std_ulogic;                   -- decoded F bit from received video
        rx_v_in:        in    std_ulogic;                   -- decoded V bit from received video
        rx_h_in:        in    std_ulogic;                   -- decoded H bit from received video
        std_locked:     in    std_ulogic;                   -- asserted by autodetect when std_in is valid
        std_in:         in    std_ulogic_vector(2 downto 0);-- code for current video standard
        rx_xyz_err_in:  in    std_ulogic;                   -- asserted on error in XYZ word
        rx_vid_in:      in    std_ulogic_vector(9 downto 0);-- input video stream
        rx_s4444_in:    in    std_ulogic;                   -- S bit for 4444 video
        rx_anc_in:      in    std_ulogic;                   -- asserted on first word of received ANC
        rx_edh_in:      in    std_ulogic;                   -- asserted on first word of received EDH
        en_sync_switch: in    std_ulogic;                   -- enables synchronous switching
        en_trs_blank:   in    std_ulogic;                   -- enables TRS blanking
        trs:            out   std_ulogic;                   -- asserted during flywheel generated TRS
        vid_out:        out   std_ulogic_vector(9 downto 0);-- video output
        field:          out   std_ulogic;                   -- field indicator
        v_blank:        out   std_ulogic;                   -- vertical blanking interval
        h_blank:        out   std_ulogic;                   -- horizontal blanking interval
        horz_count:     out   
            std_logic_vector(HCNT_WIDTH-1 downto 0);        -- current horizontal count
        vert_count:     out   
            std_logic_vector(VCNT_WIDTH-1 downto 0);        -- current vertical count
        sync_switch:    out   std_ulogic;                   -- asserted on lines when sync switching is permitted
        locked:         out   std_ulogic;                   -- asserted when flywheel is synchronized to video
        eav_next:       out   std_ulogic;                   -- next word is first word of EAV
        sav_next:       out   std_ulogic;                   -- next word is first word of SAV
        xyz_word:       out   std_ulogic;                   -- current word is XYZ word
        anc_next:       out   std_ulogic;                   -- next word is first word of ANC packet
        edh_next:       out   std_ulogic);                  -- next word is first word of EDH packet
end;

architecture synth of flywheel is

subtype video     is std_ulogic_vector(9 downto 0);
subtype hposition is std_logic_vector(HCNT_WIDTH - 1 downto 0);
subtype vposition is std_logic_vector(VCNT_WIDTH - 1 downto 0);
subtype stdcode   is std_ulogic_vector(2 downto 0);

-------------------------------------------------------------------------------
-- Constant definitions
--

--
-- This group of constants defines the bit widths of various fields in the
-- module. 
--
constant HCNT_MSB :     integer := HCNT_WIDTH - 1;       -- MS bit # of hcnt
constant VCNT_MSB :     integer := VCNT_WIDTH - 1;       -- MS bit # of vcnt

--
-- This group of constants defines the encoding for the video standards output
-- code.
--
constant NTSC_422:          stdcode := "000";
constant NTSC_INVALID:      stdcode := "001";
constant NTSC_422_WIDE:     stdcode := "010";
constant NTSC_4444:         stdcode := "011";
constant PAL_422:           stdcode := "100";
constant PAL_INVALID:       stdcode := "101";
constant PAL_422_WIDE:      stdcode := "110";
constant PAL_4444:          stdcode := "111";


--
-- This group of constants defines the component video values that will be
-- used to blank TRS symbols when TRS blanking.
--
constant YCBCR_4444_BLANK_Y :  video := std_ulogic_vector(TO_UNSIGNED(64, 10));
constant YCBCR_4444_BLANK_CB : video := std_ulogic_vector(TO_UNSIGNED(512, 10));
constant YCBCR_4444_BLANK_CR : video := std_ulogic_vector(TO_UNSIGNED(512, 10));
constant YCBCR_4444_BLANK_A :  video := std_ulogic_vector(TO_UNSIGNED(64, 10));

constant RGB_4444_BLANK_R :    video := std_ulogic_vector(TO_UNSIGNED(64, 10));
constant RGB_4444_BLANK_G :    video := std_ulogic_vector(TO_UNSIGNED(64, 10));
constant RGB_4444_BLANK_B :    video := std_ulogic_vector(TO_UNSIGNED(64, 10));
constant RGB_4444_BLANK_A :    video := std_ulogic_vector(TO_UNSIGNED(64, 10));

constant YCBCR_422_BLANK_Y :   video := std_ulogic_vector(TO_UNSIGNED(64, 10));
constant YCBCR_422_BLANK_C :   video := std_ulogic_vector(TO_UNSIGNED(512, 10));
        
-------------------------------------------------------------------------------
-- Signal definitions
--

-- internal signals
signal rx_xyz :         std_ulogic;      -- input reg for rx_xyz_in
signal rx_trs :         std_ulogic;      -- input reg for rx_trs_in
signal rx_eav_first :   std_ulogic;      -- input reg for rx_eav_first_in
signal rx_xyz_err :     std_ulogic;      -- input reg for rx_xyz_err_in
signal rx_s4444 :       std_ulogic;      -- input reg for rx_s4444_in
signal rx_vid :         video;           -- input reg for rx_vid_in
signal rx_f :           std_ulogic;      -- input reg for rx_f_in
signal rx_v :           std_ulogic;      -- input reg for rx_v_in
signal rx_h :           std_ulogic;      -- input reg for rx_h_in
signal rx_anc :         std_ulogic;      -- input reg for rx_anc_in
signal rx_edh :         std_ulogic;      -- input reg for rx_edh_in
signal hcnt :           hposition;       -- horizontal counter
signal vcnt :           vposition;       -- vertical counter
signal fly_eav_next :   std_ulogic;      -- EAV symbol starts on next count
signal fly_sav_next :   std_ulogic;      -- SAV symbol starts on next count
signal trs_word :       
    std_logic_vector(1 downto 0);        -- counts length of TRS symbol
signal fly_trs :        std_ulogic;      -- asserted during all words of flywheel TRS
signal trs_d :          std_ulogic;      -- input to trs output reg
signal v_blank_d :      std_ulogic;      -- input to v_blank output reg
signal h_blank_d :      std_ulogic;      -- input to h_blank output reg
signal fly_eav :        std_ulogic;      -- asserted on XYZ word of flywheel EAV
signal fly_sav :        std_ulogic;      -- asserted on XYZ word of flywheel SAV
signal rx_eav :         std_ulogic;      -- asserted on XYZ word of recevied EAV
signal rx_sav :         std_ulogic;      -- asserted on XYZ word of received SAV
signal f :              std_ulogic;      -- field bit
signal v :              std_ulogic;      -- horizontal blanking bit
signal h :              std_ulogic;      -- vertical blanking bit
signal xyz :            video;           -- flywheel generated XYZ word
signal new_rx_field :   std_ulogic;      -- asserted when received field changes
signal ld_vcnt :        std_ulogic;      -- loads vertical counter
signal inc_vcnt :       std_ulogic;      -- forces vertical counter to increment
signal clr_hcnt :       std_ulogic;      -- reloads hcnt
signal resync_hcnt :    std_ulogic;      -- resyncs hcnt during sync switch
signal ld_f :           std_ulogic;      -- loads field bit
signal inc_f :          std_ulogic;      -- toggles field bit
signal ntsc :           std_ulogic;      -- 1 = NTSC, 0 = PAL
signal lock :           std_ulogic;      -- internal version of locked output
signal std :            stdcode;         -- register for the std_in input
signal ld_std :         std_ulogic;      -- loads std register
signal switch_interval: std_ulogic;      -- asserted from SAV to EAV of sync switch line
signal sw_int :         std_ulogic;      -- qualified version of switch_interval
signal clr_switch :     std_ulogic;      -- clears the switch_interval signal
signal fly_vid :        video;           -- flywheel generated video
signal rx_trs_delay :   
    std_ulogic_vector(2 downto 0);       -- used to generated rx_trs_all4 signal
signal rx_trs_all4 :    std_ulogic;      -- asserted during all words of received TRS
signal rx_field :       std_ulogic;      -- the F bit from received XYZ word
signal use_rx :         std_ulogic;      -- use decoded rx video info when asserted
signal use_fly :        std_ulogic;      -- use flywheel generated video when asserted
signal sloppy_v :       std_ulogic;      -- when asserted, V bit is ingnored in XYZ compare
signal xyz_word_d :     std_ulogic;     -- used to create the xyz output
signal comp_sel :       
    std_ulogic_vector(1 downto 0);       -- LS two bits of hcnt

--
-- Component definitions
--
component fly_horz
    generic (
        HCNT_WIDTH: integer := 12);
    port (
        clk:          in    std_ulogic;                 -- clock input
        rst:          in    std_ulogic;                 -- async reset input
        ce:           in    std_ulogic;                 -- clock enable
        clr_hcnt:     in    std_ulogic;                 -- clears the horizontal counter
        resync_hcnt:  in    std_ulogic;                 -- resynchronizes the hcnt during sync switch
        std:          in    
            std_ulogic_vector(2 downto 0);              -- indicates current video standard
        hcnt:         out   
            std_logic_vector(HCNT_WIDTH - 1 downto 0);  -- horizontal counter
        eav_next:     inout std_ulogic;                 -- asserted when next word is first word of EAV
        sav_next:     inout std_ulogic;                 -- asserted when next word is first word of SAV
        h:            inout std_ulogic;                 -- horizontal blanking indicator
        trs_word:     inout 
            std_logic_vector(1 downto 0);               -- indicates word # of current TRS word
        fly_trs:      out   std_ulogic;                 -- asserted during first word of flywheel generated TRS
        fly_eav:      out   std_ulogic;                 -- asserted during xyz word of flywheel generated EAV
        fly_sav:      inout std_ulogic);                -- asserted during xyz word of flywheel generated SAV
end component;

component fly_vert
    generic (
        VCNT_WIDTH : integer := 10);
    port (
        clk:            in    std_ulogic;               -- clock input
        rst:            in    std_ulogic;               -- async reset input
        ce:             in    std_ulogic;               -- clock enable
        ntsc:           in    std_ulogic;               -- 1 = NTSC, 0 = PAL
        ld_vcnt:        in    std_ulogic;               -- causes vcnt to load
        fsm_inc_vcnt:   in    std_ulogic;               -- forces vcnt to increment during failed sync switch
        eav_next:       in    std_ulogic;               -- asserted when next word is first word of flywheel EAV
        clr_switch:     in    std_ulogic;               -- clears the switching_interval signal
        rx_f:           in    std_ulogic;               -- received F bit
        f:              in    std_ulogic;               -- flywheel generated F bit
        fly_sav:        in    std_ulogic;               -- asserted during first word of flywheel generated SAV
        fly_eav:        in    std_ulogic;               -- asserted during first word of flywheel generated EAV
        rx_eav_first:   in    std_ulogic;               -- asserted during first word of received EAV
        lock:           in    std_ulogic;               -- asserted when flywheel is locked
        vcnt:           inout 
            std_logic_vector(VCNT_WIDTH - 1 downto 0);  -- vertical counter
        v:              out   std_ulogic;               -- vertical blanking interval indicator
        sloppy_v:       out   std_ulogic;               -- asserted when FSM should ignore V bit in XYZ compare
        inc_f:          out   std_ulogic;               -- toggles the F bit when asserted
        switch_interval:inout std_ulogic);              -- asserted when current line is sync switch line
end component;

component fly_field
    port (
        clk:          in    std_ulogic;                 -- clock input
        rst:          in    std_ulogic;                 -- async reset input
        ce:           in    std_ulogic;                 -- clock enable
        ld_f:         in    std_ulogic;                 -- loads the F bit
        inc_f:        in    std_ulogic;                 -- toggles the F bit
        eav_next:     in    std_ulogic;                 -- asserted when next word is first word of EAV
        rx_field:     in    std_ulogic;                 -- F bit from received XYZ word
        rx_xyz:       in    std_ulogic;                 -- asserted during XYZ word of received TRS
        f:            inout std_ulogic;                 -- field bit
        new_rx_field: out   std_ulogic);                -- asserted when received field changes
end component;

component fly_fsm
    port (
        clk:            in    std_ulogic;               -- clock input
        ce:             in    std_ulogic;               -- clock enable
        rst:            in    std_ulogic;               -- async reset input
        vid_f:          in    std_ulogic;               -- video data F bit
        vid_v:          in    std_ulogic;               -- video data V bit
        vid_h:          in    std_ulogic;               -- video data H bit
        rx_xyz:         in    std_ulogic;               -- asserted during XYZ word of received TRS
        fly_eav:        in    std_ulogic;               -- asserted during XYZ word of flywheel EAV
        fly_sav:        in    std_ulogic;               -- asserted during XYZ word of flywheel SAV
        fly_eav_next:   in    std_ulogic;               -- indicates start of EAV with next word
        fly_sav_next:   in    std_ulogic;               -- indicates start of SAV with next word
        rx_eav:         in    std_ulogic;               -- asserted during XYZ word of received EAV
        rx_sav:         in    std_ulogic;               -- asserted during XYZ word of received SAV
        rx_eav_first:   in    std_ulogic;               -- asserted during first word of received EAV
        new_rx_field:   in    std_ulogic;               -- asserted when received field changes
        xyz_err:        in    std_ulogic;               -- asserted on error in XYZ word
        std_locked:     in    std_ulogic;               -- asserted when autodetect locked to standard
        switch_interval:in    std_ulogic;               -- asserted when in sync switching interval
        xyz_f:          in    std_ulogic;               -- flywheel generated F bit for XYZ word
        xyz_v:          in    std_ulogic;               -- flywheel generated V bit for XYZ word
        xyz_h:          in    std_ulogic;               -- flywheel generated H bit for XYZ word
        sloppy_v:       in    std_ulogic;               -- ignore V bit on XYZ comparison when asserted
        lock:           out   std_ulogic;               -- flywheel is locked to video when asserted
        ld_vcnt:        out   std_ulogic;               -- causes vcnt to load
        inc_vcnt:       out   std_ulogic;               -- forces vcnt to increment during sync switch
        clr_hcnt:       out   std_ulogic;               -- clears hcnt
        resync_hcnt:    out   std_ulogic;               -- reloads hcnt
        ld_std:         out   std_ulogic;               -- loads the int_std register
        ld_f:           out   std_ulogic;               -- loads the F bit
        clr_switch:     out   std_ulogic);              -- clears the switching_interval signal
end component;


begin
    
    --
    -- input register for signals from trs_detect
    --
    --
    process(clk, rst)
    begin
        if (rst = '1') then
            rx_xyz <= '0';
            rx_trs <= '0';
            rx_eav_first <= '0';
            rx_xyz_err <= '0';
            rx_s4444 <= '0';
            rx_vid <= (others => '0');
            rx_f <= '0';
            rx_v <= '0';
            rx_h <= '0';
            rx_anc <= '0';
            rx_edh <= '0';
        elsif (clk'event and clk = '1') then
            if (ce = '1') then
                rx_xyz <= rx_xyz_in;
                rx_trs <= rx_trs_in;
                rx_eav_first <= rx_eav_first_in;
                rx_xyz_err <= rx_xyz_err_in;
                rx_s4444 <= rx_s4444_in;
                rx_vid <= rx_vid_in;
                rx_f <= rx_f_in;
                rx_v <= rx_v_in;
                rx_h <= rx_h_in;
                rx_anc <= rx_anc_in;
                rx_edh <= rx_edh_in;
            end if;
        end if;
    end process;

    -- 
    -- fly_horz instantiation
    --
    -- The fly_horz module contains the horizontal functions of the flywheel. It
    -- generates the horizontal count and the H bit.It also generates several
    -- TRS related signals indicating when a TRS is to be generated by the 
    -- flywheel and what type of TRS is to be generated.
    --
    horz: fly_horz
        generic map (
            HCNT_WIDTH => HCNT_WIDTH)
        port map (
            clk             => clk,
            rst             => rst,
            ce              => ce,
            clr_hcnt        => clr_hcnt,
            resync_hcnt     => resync_hcnt,
            std             => std,
            hcnt            => hcnt,
            eav_next        => fly_eav_next,
            sav_next        => fly_sav_next,
            h               => h,
            trs_word        => trs_word,
            fly_trs         => fly_trs,
            fly_eav         => fly_eav,
            fly_sav         => fly_sav);


    --
    -- fly_vert instantiation
    --
    -- The fly_vert module contains the vertical functions of the flywheel. It
    -- generates the vertical line count and the V bit. It generates the inc_f
    -- signal indicating when it is time to advance to the next field. It also
    -- generates the switch_interval signal indicating when the current line is
    -- a line when switching between two synchronous video sources is permitted.
    --
    vert: fly_vert
        generic map (
            VCNT_WIDTH => VCNT_WIDTH)
        port map (
            clk             => clk,
            rst             => rst,
            ce              => ce,
            ntsc            => ntsc,
            ld_vcnt         => ld_vcnt,
            fsm_inc_vcnt    => inc_vcnt,
            eav_next        => fly_eav_next,
            clr_switch      => clr_switch,
            rx_f            => rx_f,
            f               => f,
            fly_sav         => fly_sav,
            fly_eav         => fly_eav,
            rx_eav_first    => rx_eav_first,
            lock            => lock,
            vcnt            => vcnt,
            v               => v,
            sloppy_v        => sloppy_v,
            inc_f           => inc_f,
            switch_interval => switch_interval);

    sw_int <= switch_interval and en_sync_switch;

    --
    -- fly_fsm instantiation
    --
    -- The fly_fsm module contains the finite state machine that controls the
    -- operation of the flywheel.
    --
    fsm: fly_fsm
        port map (
            clk             => clk,
            ce              => ce,
            rst             => rst,
            vid_f           => rx_vid(8),
            vid_v           => rx_vid(7),
            vid_h           => rx_vid(6),
            rx_xyz          => rx_xyz,
            fly_eav         => fly_eav,
            fly_sav         => fly_sav,
            fly_eav_next    => fly_eav_next,
            fly_sav_next    => fly_sav_next,
            rx_eav          => rx_eav,
            rx_sav          => rx_sav,
            rx_eav_first    => rx_eav_first,
            new_rx_field    => new_rx_field,
            xyz_err         => rx_xyz_err,
            std_locked      => std_locked,
            switch_interval => sw_int,
            xyz_f           => xyz(8),
            xyz_v           => xyz(7),
            xyz_h           => xyz(6),
            sloppy_v        => sloppy_v,
            lock            => lock,
            ld_vcnt         => ld_vcnt,
            inc_vcnt        => inc_vcnt,
            clr_hcnt        => clr_hcnt,
            resync_hcnt     => resync_hcnt,
            ld_std          => ld_std,
            ld_f            => ld_f,
            clr_switch      => clr_switch);

    --
    -- fly_field instantiation
    --
    -- The fly_field module contains the field related functions of the 
    -- flywheel. It generates the F bit and also contains a logic to determine 
    -- when the received field changes.
    --
    fld: fly_field
        port map (
            clk             => clk,
            rst             => rst,
            ce              => ce,
            ld_f            => ld_f,
            inc_f           => inc_f,
            eav_next        => fly_eav_next,
            rx_field        => rx_field,
            rx_xyz          => rx_xyz,
            f               => f,
            new_rx_field    => new_rx_field);

    rx_field <= rx_vid(8);

    --
    -- rx_eav and rx_sav
    --
    -- This code decodes the H bit from the received video to generate the 
    -- rx_eav and rx_sav signals. These two signals are asserted during the XYZ 
    -- word only of a received TRS symbol to indicate whether a SAV or an EAV 
    -- symbol has been received.
    --
    rx_eav <= rx_xyz and rx_vid(6);
    rx_sav <= rx_xyz and not rx_vid(6);

    --
    -- rx_trs_delay and rx_trs_all4 generation
    --
    -- The trs_detect module only asserts the rx_trs signal during the first
    -- word of a received TRS symbol. This code stretches that signal so that
    -- it is asserted for all four words of the TRS symbol. The extended signal
    -- is called rx_trs_all4.
    --
    process(clk, rst)
    begin
        if (rst = '1') then
            rx_trs_delay <= (others => '0');
        elsif (clk'event and clk = '1') then
            if (ce = '1') then
                rx_trs_delay <= (rx_trs_delay(1 downto 0) & rx_trs);
            end if;
        end if;
    end process;

    rx_trs_all4 <= '1' when ((rx_trs_delay(0) = '1') or (rx_trs_delay(1) = '1') or
                             (rx_trs_delay(2) = '1') or (rx_trs = '1'))
                   else '0'; 

    --
    -- std register
    --
    -- This register holds the current video standard code being used by the
    -- flywheel. It loads from the std inputs whenever the state machine begins
    -- the synchronization process.
    --
    process(clk, rst)
    begin
        if (rst = '1') then
            std <= NTSC_422;
        elsif (clk'event and clk = '1') then
            if (ce = '1') then
                if (ld_std = '1') then
                    std <= std_in;
                end if;
            end if;
        end if;
    end process;


    --
    -- ntsc
    --
    -- This signal is asserted when the code in the std register indicates a
    -- NTSC standard and is negated for PAL standards.
    --
    process(std)
    begin
        if (std = NTSC_422 or std = NTSC_INVALID or
            std = NTSC_422_WIDE or std = NTSC_4444) then
            ntsc <= '1';
        else
            ntsc <= '0';
        end if;
    end process;

    --
    -- xyz generator
    --
    -- This logic generates the TRS XYZ word. The XYZ word is constructed
    -- differently for the 4:4:4:4 standards than for the 4:2:2 standards.
    --
    process(h, v, f, rx_s4444, std)
    begin
        xyz(9) <= '1';
        xyz(8) <= f;
        xyz(7) <= v;
        xyz(6) <= h;
        xyz(0) <= '0';

        if (std = NTSC_4444 or std = PAL_4444) then
            xyz(5) <= rx_s4444;
            xyz(4) <= f xor v xor h;
            xyz(3) <= f xor v xor rx_s4444;
            xyz(2) <= v xor h xor rx_s4444;
            xyz(1) <= f xor h xor rx_s4444;
        elsif (std = NTSC_422 or std = NTSC_422_WIDE or
               std = PAL_422 or std = PAL_422_WIDE) then
            xyz(5) <= v xor h;
            xyz(4) <= f xor h;
            xyz(3) <= f xor v;
            xyz(2) <= f xor v xor h;
            xyz(1) <= '0';
        else
            xyz <= (others => '0');
        end if;
    end process;


    --
    -- fly_vid generator
    --
    -- This code generates the flywheel TRS symbol. The first three words of the
    -- TRS symbol are 0x3ff, 0x000, 0x000. The fourth word is the XYZ word. If
    -- a TRS symbol is not begin generated, the fly_vid value is assigned to
    -- the blank level value appropriate to the component being generated.
    --

    comp_sel <= std_ulogic_vector(hcnt(1 downto 0));

    process(xyz, trs_word, trs_d, hcnt, std, rx_s4444, comp_sel)
    begin
        if (trs_d = '1') then
            case trs_word is
                when "00" =>   fly_vid <= (others => '1');
                when "01" =>   fly_vid <= (others => '0');
                when "10" =>   fly_vid <= (others => '0');
                when others => fly_vid <= xyz;
            end case;
        elsif (std = NTSC_4444 or std = PAL_4444) then
            if (rx_s4444 = '1') then
                case comp_sel is
                    when "00" =>   fly_vid <= YCBCR_4444_BLANK_CB;
                    when "01" =>   fly_vid <= YCBCR_4444_BLANK_Y;
                    when "10" =>   fly_vid <= YCBCR_4444_BLANK_CR;
                    when others => fly_vid <= YCBCR_4444_BLANK_A;
                end case;
            else
                case comp_sel is
                    when "00" =>   fly_vid <= RGB_4444_BLANK_B;
                    when "01" =>   fly_vid <= RGB_4444_BLANK_G;
                    when "10" =>   fly_vid <= RGB_4444_BLANK_R;
                    when others => fly_vid <= RGB_4444_BLANK_A;
                end case;
            end if;
        else
            if (hcnt(0) = '1') then
                fly_vid <= YCBCR_422_BLANK_Y;
            else
                fly_vid <= YCBCR_422_BLANK_C;
            end if;
        end if;
    end process;

    --
    -- output register
    --
    -- This is the output register for all the flywheel's output signals. The
    -- signals that can be derived internally or from the received video (trs,
    -- vid_out, and h_blank) use the use_rx signal to determine whether the 
    -- flywheel generated signals or the signals decoded from the received video
    --  should be used. The v_blank and field outputs are not affected by 
    -- use_rx.
    --
    -- Normally the output video stream (vid_out) is equal to the input video
    -- stream (vid_in). However, when the flywheel generates a TRS symbol, this
    -- internally generated TRS symbol is output instead of the input video
    -- stream. If the input video stream contains a TRS that does not line up
    -- with the flywheel's TRS symbol, then the TRS symbol in the input video
    -- stream is blanked by the flywheel. However, on the synchronous switching
    -- lines, the SAV symbol in the input video stream is always output and the 
    -- flywheel's SAV symbol is suppressed.
    --
    process(clk, rst)
    begin
        if rst = '1' then
            trs <= '0';
            field <= '0';
            v_blank <= '0';
            h_blank <= '0';
            horz_count <= (others => '0');
            vert_count <= std_logic_vector(TO_UNSIGNED(1, VCNT_WIDTH));
            locked <= '0';
            sync_switch <= '0';
            vid_out <= (others => '0');
            eav_next <= '0';
            sav_next <= '0';
            xyz_word <= '0';
        elsif clk'event and clk = '1' then
            if ce = '1' then
                trs <= trs_d;
                field <= f;
                v_blank <= v_blank_d;
                h_blank <= h_blank_d;
                horz_count <= hcnt;
                vert_count <= vcnt;
                locked <= lock;
                sync_switch <= sw_int;
                if (use_fly = '1') then
                    vid_out <= fly_vid;
                else
                    vid_out <= rx_vid;
                end if;
                eav_next <= fly_eav_next;
                sav_next <= fly_sav_next;
                xyz_word <= xyz_word_d;
            end if;
        end if;
    end process;
        
    use_rx <= (sw_int or sloppy_v) and lock;
    use_fly <= (trs_d and not use_rx) or ((not trs_d and rx_trs_all4) 
                and en_trs_blank);
    trs_d <= rx_trs_all4 when use_rx = '1' else fly_trs;
    h_blank_d <= (rx_h or rx_trs_all4) when use_rx = '1' else (h or trs_d);
    v_blank_d <= rx_v when use_rx = '1' else v;
    xyz_word_d <= trs_d and trs_word(1) and trs_word(0);
    anc_next <= rx_anc;
    edh_next <= rx_edh;
     
end synth;