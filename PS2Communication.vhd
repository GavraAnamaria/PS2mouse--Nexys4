library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ps2Communication is
  PORT(
      ps2_clk        : inout std_logic;
      ps2_data       : inout std_logic;
      clk            : in std_logic;
      rst            : in std_logic;
      tx_data        : in std_logic_vector(7 downto 0);
      write_data     : in std_logic;
      rx_data        : out std_logic_vector(7 downto 0);
      read_data      : out std_logic;
      err            : out std_logic);                         
end ps2Communication;

architecture Behavioral of ps2Communication is

component  transmitator is
    Port ( clk : in STD_LOGIC;
           rst: in STD_LOGIC;
           start : in STD_LOGIC;
           txData : in STD_LOGIC_VECTOR(7 downto 0);
           PS2_CLK : in STD_LOGIC; --deb
           PS2_DATA : in STD_LOGIC;
           PS2cen : out STD_LOGIC;
           PS2den : out STD_LOGIC;
           busy : out STD_LOGIC;
           err : out STD_LOGIC);
end component; 

component debounce is
Generic (DELAY : std_logic_vector(3 downto 0)  := "1111");
    Port ( Clk : in STD_LOGIC;
           Rst : in STD_LOGIC;
           Din : in STD_LOGIC;
           Qout : out STD_LOGIC);
end component;

component receptor is
    Port ( clk : in STD_LOGIC;
           rst: in STD_LOGIC;
           start : in STD_LOGIC;
           ps2_clk : in STD_LOGIC; --deb
           ps2_data : in STD_LOGIC;
           rxData : out STD_LOGIC_VECTOR(7 downto 0);
           busy : out STD_LOGIC;
           err : out std_logic);
end component;

signal tx : std_logic := '1';
signal tx_rdy : std_logic := '0';
signal rx_start : std_logic := '1';
signal b1, b2 : std_logic := '0';
signal err1, err2 : std_logic := '0';
signal ps2clk_deb, ps2data_deb : std_logic := '0';
signal cen, den : std_logic := '1';

begin

d1: debounce port map (clk, rst, ps2_clk, ps2clk_deb);

d2: debounce port map (clk, rst, ps2_data, ps2data_deb);

   
tr:transmitator Port map (clk, rst, write_data, tx_Data, ps2clk_deb, PS2data_deb, cen, den, b1, err1);

--rec:receptor port map ( clk, rst, rx_start, ps2clk_deb, ps2data_deb, rx_data, b2, err2);

ps2_clk <= 'Z' when cen = '1' else '0';
ps2_data <= 'Z' when den = '1' else '0';
read_data <= not(b2);
ps2_data <= ps2_data and tx;

rx_start <= not( b1 or b2);
err <= err1 or err2;
end Behavioral;
