	component vga is
		port (
			beat_pulse_beat_pulse     : in  std_logic_vector(1 downto 0) := (others => 'X'); -- beat_pulse
			bpm_estimate_bpm_estimate : in  std_logic_vector(8 downto 0) := (others => 'X'); -- bpm_estimate
			clk_clk                   : in  std_logic                    := 'X';             -- clk
			reset_reset_n             : in  std_logic                    := 'X';             -- reset_n
			vga_CLK                   : out std_logic;                                       -- CLK
			vga_HS                    : out std_logic;                                       -- HS
			vga_VS                    : out std_logic;                                       -- VS
			vga_BLANK                 : out std_logic;                                       -- BLANK
			vga_SYNC                  : out std_logic;                                       -- SYNC
			vga_R                     : out std_logic_vector(7 downto 0);                    -- R
			vga_G                     : out std_logic_vector(7 downto 0);                    -- G
			vga_B                     : out std_logic_vector(7 downto 0)                     -- B
		);
	end component vga;

	u0 : component vga
		port map (
			beat_pulse_beat_pulse     => CONNECTED_TO_beat_pulse_beat_pulse,     --   beat_pulse.beat_pulse
			bpm_estimate_bpm_estimate => CONNECTED_TO_bpm_estimate_bpm_estimate, -- bpm_estimate.bpm_estimate
			clk_clk                   => CONNECTED_TO_clk_clk,                   --          clk.clk
			reset_reset_n             => CONNECTED_TO_reset_reset_n,             --        reset.reset_n
			vga_CLK                   => CONNECTED_TO_vga_CLK,                   --          vga.CLK
			vga_HS                    => CONNECTED_TO_vga_HS,                    --             .HS
			vga_VS                    => CONNECTED_TO_vga_VS,                    --             .VS
			vga_BLANK                 => CONNECTED_TO_vga_BLANK,                 --             .BLANK
			vga_SYNC                  => CONNECTED_TO_vga_SYNC,                  --             .SYNC
			vga_R                     => CONNECTED_TO_vga_R,                     --             .R
			vga_G                     => CONNECTED_TO_vga_G,                     --             .G
			vga_B                     => CONNECTED_TO_vga_B                      --             .B
		);

