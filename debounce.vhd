library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL; 
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity debounce is
Generic (DELAY : std_logic_vector(3 downto 0)  := "1111");
    Port ( Clk : in STD_LOGIC;
           Rst : in STD_LOGIC;
           Din : in STD_LOGIC;
           Qout : out STD_LOGIC);
end debounce;

architecture Behavioral of debounce is

signal  inter : std_logic := '1';
signal count: std_logic_vector(3 downto 0) := (others => '0');

begin

  process(clk)
   begin
      if(rising_edge(clk)) then
      if rst = '1' then 
         count <= (others => '0');
         inter <= '1';
         Qout <= '1';
      else
         if(Din /= inter) then --intrarea se modifica
            inter <= Din;
            count <= (others => '0');
         elsif(count = DELAY) then
            Qout <= inter;
         else
            count <= count + 1;
         end if;
        end if;
      end if;
   end process;

end Behavioral;
