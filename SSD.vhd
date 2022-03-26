library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SSD is
Port ( CLK  : in  STD_LOGIC;
           Rst  : in  STD_LOGIC;
           Data : in  STD_LOGIC_VECTOR (31 downto 0);  
           An   : out STD_LOGIC_VECTOR (7 downto 0); 
           Seg  : out STD_LOGIC_VECTOR (7 downto 0));   
end SSD;

architecture Behavioral of SSD is
   
signal Num        : STD_LOGIC_VECTOR (19 downto 0) := (others => '0');    
signal LedSel      : STD_LOGIC_VECTOR (2 downto 0) := (others => '0'); 
signal Hex         : STD_LOGIC_VECTOR (3 downto 0) := (others => '0');

begin

-- Divizor
divclk: process (Clk)
    begin
    if (Clk'event and Clk = '1') then
        if (Rst = '1') then
            Num <= (others =>'0');
        elsif (Num = x"FFFFF") then
            Num <= (others =>'0');
        else
            Num <= Num + 1;
        end if;
    end if;
    end process;

    LedSel <= Num (19 downto 17);

-- Selectia anodului activ
 An <= "11111110" when LedSel = "000" else
         "11111101" when LedSel = "001" else
         "11111011" when LedSel = "010" else
         "11110111" when LedSel = "011" else
         "11101111" when LedSel = "100" else
         "11011111" when LedSel = "101" else
         "10111111" when LedSel = "110" else
         "01111111" when LedSel = "111" else
         "11111111";

-- Selectia cifrei active
   Hex <= Data (3  downto  0) when LedSel = "000" else
          Data (7  downto  4) when LedSel = "001" else
          Data (11 downto  8) when LedSel = "010" else
          Data (15 downto 12) when LedSel = "011" else
          Data (19 downto 16) when LedSel = "100" else
          Data (23 downto 20) when LedSel = "101" else
          Data (27 downto 24) when LedSel = "110" else
          Data (31 downto 28) when LedSel = "111" else
          X"0";

-- Activarea/dezactivarea segmentelor cifrei active
   Seg <= "11111001" when Hex = "0001" else            
          "10100100" when Hex = "0010" else            
          "10110000" when Hex = "0011" else            
          "10011001" when Hex = "0100" else            
          "10010010" when Hex = "0101" else            
          "10000010" when Hex = "0110" else           
          "11111000" when Hex = "0111" else            
          "10000000" when Hex = "1000" else            
          "10010000" when Hex = "1001" else            
          "10001000" when Hex = "1010" else            
          "10000011" when Hex = "1011" else            
          "11000110" when Hex = "1100" else            
          "10100001" when Hex = "1101" else            
          "10000110" when Hex = "1110" else           
          "10001110" when Hex = "1111" else            
          "11000000";                                  

end Behavioral;
