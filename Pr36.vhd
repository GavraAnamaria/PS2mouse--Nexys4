library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Pr36 is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           PS2_CLK : inout STD_LOGIC;
           PS2_DATA : inout STD_LOGIC;
           tx : out STD_LOGIC;
           an : out STD_LOGIC_VECTOR (3 downto 0);   
           cat : out STD_LOGIC_VECTOR (7 downto 0)); 
end Pr36;

architecture Behavioral of Pr36 is
component SSD is
Port ( Clk  : in  STD_LOGIC;
           Rst  : in  STD_LOGIC;
           Data : in  STD_LOGIC_VECTOR (31 downto 0); 
           An   : out STD_LOGIC_VECTOR (7 downto 0);   
           Seg  : out STD_LOGIC_VECTOR (7 downto 0));   
end component;
component UART_tx is
 generic( fr: integer := 100_000_000;
          bRate: integer := 8680_555);
  port( clk            : in  std_logic;
        rst          : in  std_logic;
        start       : in  std_logic;
        txData     : in  std_logic_vector (7 downto 0);
        tx    : out std_logic;
        TxRdy : out STD_LOGIC);
    end component;
component ps2Communication is
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
end component;

component MouseCtrl is
generic
(
   SYSCLK_FREQUENCY_HZ : integer := 100000000
);
port(
   clk         : in std_logic;
   rst         : in std_logic;
   err         : in std_logic;
   rx_data     : in std_logic_vector(7 downto 0);
   read_data   : in std_logic;
   tx_data     : out std_logic_vector(7 downto 0);
   write_data  : out std_logic;
   xpos        : out std_logic_vector(11 downto 0);
   ypos        : out std_logic_vector(11 downto 0);
   zpos        : out std_logic_vector(3 downto 0);
   left        : out std_logic;
   middle      : out std_logic;
   right       : out std_logic;
   new_event   : out std_logic
   );
end component;

signal data: std_logic_vector(31 downto 0) := (others => '0');
signal tx_data: std_logic_vector(7 downto 0) := (others => '0');
signal write_data: std_logic:= '0';
signal rx_data: std_logic_vector(7 downto 0) := (others => '0');
signal read_data : std_logic := '0';
signal err : std_logic := '0';

begin
data(3) <= '0';
uar:UART_tx port map (clk, rst, '1', data(7 downto 0), tx, open);
U:  ps2Communication port map (ps2_clk, ps2_data, clk, rst, tx_data, write_data, rx_data, read_data , err);
ctrl: MouseCtrl Port map (clk, rst, err, rx_data, read_data, tx_data, write_data, data(31 downto 20), data(19 downto 8), data(7 downto 4),data(0), data(2) ,data(1), open);
s: ssd port map(clk, rst, data, an, cat);
end Behavioral;