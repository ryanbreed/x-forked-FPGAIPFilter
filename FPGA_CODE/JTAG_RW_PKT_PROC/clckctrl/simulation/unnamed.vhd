-- unnamed.vhd

-- Generated using ACDS version 16.1 200

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity unnamed is
	port (
		inclk  : in  std_logic := '0'; --  altclkctrl_input.inclk
		ena    : in  std_logic := '0'; --                  .ena
		outclk : out std_logic         -- altclkctrl_output.outclk
	);
end entity unnamed;

architecture rtl of unnamed is
	component unnamed_altclkctrl_0 is
		port (
			inclk  : in  std_logic := 'X'; -- inclk
			ena    : in  std_logic := 'X'; -- ena
			outclk : out std_logic         -- outclk
		);
	end component unnamed_altclkctrl_0;

begin

	altclkctrl_0 : component unnamed_altclkctrl_0
		port map (
			inclk  => inclk,  --  altclkctrl_input.inclk
			ena    => ena,    --                  .ena
			outclk => outclk  -- altclkctrl_output.outclk
		);

end architecture rtl; -- of unnamed