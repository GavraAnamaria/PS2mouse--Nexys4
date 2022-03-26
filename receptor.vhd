library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity receptor is
    Port ( clk : in STD_LOGIC;
           rst: in STD_LOGIC;
           start : in STD_LOGIC;
           ps2_clk : in STD_LOGIC; --deb
           ps2_data : in STD_LOGIC;
           rxData : out STD_LOGIC_VECTOR(7 downto 0);
           busy : out STD_LOGIC;
           err : out std_logic);
end receptor;

architecture Behavioral of receptor is
    type TIP_STARE is (ready, startB, waitBit, dataB, stop);
    signal  StarePrez, StareUrm : TIP_STARE;
    signal CntBit:INTEGER:=0;
    signal DataS:STD_LOGIC_VECTOR(8 DOWNTO 0):= (others => '0');
begin


proc1: process (Clk)
 begin
     if RISING_EDGE (Clk) then
         if (Rst = '1') then
            StarePrez <= ready;
         else
            StarePrez <= StareUrm;
         end if;
      end if;
 end process proc1;

 proc2: process (StarePrez, ps2_data,ps2_clk, start, clk)
  begin
      case StarePrez is
          when ready =>
              CntBit <= 0;
              if (Start = '1' and ps2_data = '0') then
                 StareUrm <= WaitBit;
              end if;
              
           when WaitBit=>
            if falling_edge(ps2_clk) then
                  if cntBit = 0 then
                      if ps2_Data /= '0' then
                             StareUrm <= ready;
                      else
                             StareUrm <= startB;
                     end if;
                  elsif cntBit <= 9 then
                      StareUrm <= dataB;
                      DataS(9-CntBit) <= ps2_Data ;
                  elsif cntBit = 10 then
                      StareUrm <= stop;
                  end if;
              end if;  
              
            when startB =>
                 if rising_edge(ps2_clk) then
                      cntBit <= cntBit + 1;
                      StareUrm <= waitBit;
                 end if;
          
          when dataB =>
               if rising_edge(ps2_clk) then
                  CntBit <= CntBit + 1;
                  StareUrm <= WaitBit;
               end if;
               
          when stop=>
               if rising_edge(ps2_clk) then
                  StareUrm <= ready;
               end if;
               
          when others =>
              stareUrm <= ready;
      end case;
  end process;

proc3: process (StarePrez, ps2_data)
 begin
     case StarePrez is
         when ready => busy <= '0'; err<= '0';
         when startB => busy <= '1'; err <= ps2_data;
         when waitBit => busy <= '1'; err <= '0';
         when dataB => busy <= '1';  err <= '0';
         when stop => busy <= '1'; err <= not(ps2_data);
         when others => busy <= '1'; err <= '1';
     end case;
 end process proc3;
 
RxData <= dataS(8 downto 1);
end Behavioral;