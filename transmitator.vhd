library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity transmitator is
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
end transmitator;
 
architecture Behavioral of transmitator is

 type TIP_STARE is (ready, PS2Clk0, PS2Data0, relclk, down_edge, clk_low, up_edge, clk_h, stop_bit, wait_ack, ack);
   signal  StarePrez, StareUrm : TIP_STARE;
   signal LdEn : std_logic := '0';
   signal ShEn : std_logic := '0';
   signal TSR : std_logic_vector(10 downto 0) := (others => '0');
   signal cntBit : integer := 0;
   signal cnt,cnt20 : integer := 0;
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
 
 
 ps2cen <= '0' when StarePrez = PS2Clk0 or  StarePrez = PS2Data0  else '1';
 ps2den <= '0' when StarePrez = PS2Data0 or  StarePrez = relCLK or  StarePrez = down_edge  else TSR(0) when StarePrez = clk_low or StarePrez = clk_h or (StarePrez = up_edge and cntBit /= 10) else'1';
 err <= ps2_data when starePrez = wait_ack;
 busy <= '0' when StarePrez = ready else '1';
 shEn <= '1' when StarePrez = clk_low else '0';
 ldEn <= '1' when StarePrez = Ps2clk0 else '0';
 
 proc_control: process (StarePrez, start,cnt, cnt20, ps2_clk, TSR, ps2_data, cntBit, clk)
 begin 
        

     case StarePrez is
         when ready =>
             Cnt <= 0;
             Cnt20 <= 0;
             CntBit <= 0;
             if (Start = '1') then
                StareUrm <= PS2Clk0;
             end if;
             
         when PS2Clk0 =>
             if(cnt = 2000) then
                 StareUrm <= PS2Data0;
                 cnt <= 0;
             elsif(rising_edge(clk)) then 
                    cnt <= cnt+1;
                end if;
            
         when ps2Data0 => 
             if(cnt20 = 400) then
                  stareUrm <= relclk;
                  cnt20 <= 0;
              elsif(rising_edge(clk)) then 
                  cnt20 <= cnt20 + 1;
              end if;

         when relclk =>
              stareUrm <= down_edge;
            
            --clk nu este restabilit imediat => asteptam 
         when down_edge =>  
              if(ps2_clk = '0') then
                   stareUrm <= clk_low;
              end if;
              
         when clk_low =>
              if rising_edge(clk) then
                  cntbit <= cntbit + 1; 
              end if;
              stareUrm <= up_edge;
              
         -- this is the edge on which the device reads the data on ps2_data.
         when up_edge =>
              if(cntBit =  10) then
                 stareUrm <= stop_bit;
              elsif(ps2_clk = '1') then
                 stareUrm <= clk_h;
              end if;
         
            -- ps2_clk is released, wait for down edge
          when clk_h =>
             if(ps2_clk = '0') then
                stareUrm <= clk_low;
             end if;
             
          when stop_bit =>
             if(ps2_clk = '1') then
                stareUrm <= wait_ack;
             end if;    
       
          when wait_ack =>
             if(ps2_clk = '0') then
                stareUrm <= ack;
             end if;
             
          when ack =>
             if(ps2_clk = '1' and ps2_data = '1') then
                stareUrm  <= ready;
             end if;

         when others =>
             StareUrm <= ready;
     end case;
 end process proc_control;

reg: process(Clk)
  begin 
   if(rising_edge(Clk)) then
       if (rst = '1') then
            TSR <= (others => '0');
       else
           if (ldEn = '1') then
               TSR(8 downto 1) <= txData;           
               TSR(0) <= '0';                    
               TSR(10) <= '1';                  
               TSR(9) <= txData(0) xor txData(1) xor txData(2) xor txData(3) xor txData(4) xor txData(5) xor txData(6) xor txData(7);
           else
               if ( shEn = '1') then
                  TSR <= '1' & TSR(10 downto 1);
               end if;
            end if;
       end if;    
   end if;
 end process;
 
end Behavioral;
