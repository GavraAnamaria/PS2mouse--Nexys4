library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_tx is
 generic( fr: integer := 100_000_000;
          bRate: integer := 8680_555);
  port( clk            : in  std_logic;
        rst          : in  std_logic;
        start       : in  std_logic;
        txData     : in  std_logic_vector (7 downto 0);
        tx    : out std_logic;
        TxRdy : out STD_LOGIC);
end UART_tx;

architecture Behavioral of uart_tx is
 type TIP_STARE is (ready, load, send, waitBit, shift);
 signal StarePrez, StareUrm : TIP_STARE;
 signal LdData : std_logic := '0';
 signal ShData : std_logic := '0';
 signal TxEn : std_logic := '0';
 signal TSR : std_logic_vector(9 downto 0) := (others => '0');
 signal cntBit : integer := 0;
 signal cntRate : integer := 0;
 constant T_BIT : integer := fr/bRate;
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
 
proc2: process (StarePrez, start, clk, cntRate, cntBit)
 begin
     case StarePrez is
         when ready =>
             CntRate <= 0;
             CntBit <= 0;
             if (Start = '1') then
                 StareUrm<= load;
             end if;
         when load =>
             StareUrm<= send;
         when send =>
             if RISING_EDGE (Clk) then
                 CntBit <= CntBit + 1;
             end if;
             StareUrm<= waitbit;
         when waitbit =>
             if RISING_EDGE (Clk) then
                 CntRate <= CntRate + 1;
             end if;
             if (CntRate = T_BIT-3) then
                 CntRate <= 0;
                 StareUrm<= shift;
             end if;
         when shift =>
             if (CntBit = 10) then
                 StareUrm<= ready;
             else
                 StareUrm<= send;
             end if;
         when others =>
             StareUrm <= ready;
     end case;
 end process proc2;
 
proc3: process (StarePrez, TSR)
 begin
     case StarePrez is
         when ready => LdData <= '0'; ShData <= '0'; TxEn <= '0'; Tx <= '1'; TxRdy <= '1';
         when load => LdData <= '1'; ShData <= '0'; TxEn <= '0'; Tx <= '1'; TxRdy <= '0';
         when send => LdData <= '0'; ShData <= '0'; TxEn <= '1'; Tx <= TSR(0); TxRdy <= '0';
         when waitBit => LdData <= '0'; ShData <= '0'; TxEn <= '1'; Tx <= TSR(0); TxRdy <= '0';
         when shift => LdData <= '0'; ShData <= '1'; TxEn <= '1'; Tx <= TSR(0); TxRdy <= '0';
     end case;
 end process proc3;
 
reg: process(Clk)
 begin
     if(rising_edge(Clk)) then
         if (rst = '1') then
             TSR <= (others => '0');
         else
             if (ldData = '1') then
                 TSR(8 downto 1) <= txData;
                 TSR(0) <= '0';
                 TSR(9) <= '1';
             else
                 if (shData = '1') then
                     TSR <= '0' & TSR(9 downto 1);
                 end if;
             end if;
         end if;
     end if;
end process reg;
end Behavioral;