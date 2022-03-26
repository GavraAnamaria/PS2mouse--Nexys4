library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity MouseCtrl is
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
end MouseCtrl;

architecture Behavioral of MouseCtrl is

------------------------------------------------------------------------
-- CONSTANTS
------------------------------------------------------------------------
constant CHECK_PERIOD_MS     : integer := 500; -- Period in miliseconds to check if the mouse is present
constant TIMEOUT_PERIOD_MS   : integer := 100; -- Timeout period in miliseconds when the mouse presence is checked
-- constants defining commands to send or received from the mouse
constant FA: std_logic_vector(7 downto 0) := "11111010"; -- 0xFA(ACK)
constant FF: std_logic_vector(7 downto 0) := "11111111"; -- 0xFF(RESET)
constant AA: std_logic_vector(7 downto 0) := "10101010"; -- 0xAA(START)
constant OO: std_logic_vector(7 downto 0) := "00000000"; -- 0x00(=>ID)

constant READ_ID          : std_logic_vector(7 downto 0) := x"F2";
constant ENABLE_REPORTING : std_logic_vector(7 downto 0) := x"F4";
constant SET_RESOLUTION   : std_logic_vector(7 downto 0) := x"E8";
constant RESOLUTION       : std_logic_vector(7 downto 0) := x"03"; -- (8 counts/mm)
constant SET_SAMPLE_RATE  : std_logic_vector(7 downto 0) := x"F3";
constant SAMPLE_RATE      : std_logic_vector(7 downto 0) := x"28"; -- (40 samples/s)
constant MAX_X : std_logic_vector(11 downto 0) := x"4FF"; -- 1279
constant MAX_Y : std_logic_vector(11 downto 0) := x"3FF";-- 1023

------------------------------------------------------------------------
-- SIGNALS
------------------------------------------------------------------------

-- after doing the enable scroll mouse procedure, if the ID returned by
-- the mouse is 03 (scroll mouse enabled) the2n this register will be set
 signal haswheel: std_logic := '0';

-- origin of axes is upper-left corner
-- the origin of axes the mouse uses is the lower-left corner
-- The y-axis is inverted, by making negative the y movement received from the mouse 
signal x_pos, y_pos: std_logic_vector(11 downto 0) := (others => '0');
-- active when an overflow occurred on the x and y axis(bits 6 and 7) 
signal x_overflow, y_overflow: std_logic := '0';
-- active when the x,y movement is negative(bits 4 and 5) 
signal x_sign, y_sign: std_logic := '0';

-- states that begin with "reset" are part of the reset procedure.
-- states that end in "_wait_ack" are states in which ack is waited.
type fsm_state is
(
   reset, reset_wait_ack, start, wait_id,
   Sread_id, read_id_wait_ack, read_id_wait_id,
   Sset_resolution, set_resolution_wait_ack,
   send_resolution, send_resolution_wait_ack,
   set_rate, set_rate_wait_ack, send_rate, send_rate_wait_ack,
   en_reporting, en_reporting_wait_ack,   
   read_byte_1,read_byte_2,read_byte_3,read_byte_4,
   check_id, check_id_wait_ack, check_id_wait_id,
   Snew_event
);
signal state: fsm_state := reset;
-- The periodic checking counter acts as a watchdog, periodically reading the Mouse ID, therefore checking if the mouse is present
-- If there is no answer, after the timeout period passed, then the state machine is reinitialized
constant CHECK_PERIOD_CLOCKS   : integer := ((CHECK_PERIOD_MS*SYSCLK_FREQUENCY_HZ)/(1000));
signal periodic_check_cnt        : integer := 0;
signal reset_periodic_check_cnt  : STD_LOGIC := '0';
constant TIMEOUT_PERIOD_CLOCKS : integer := ((TIMEOUT_PERIOD_MS*SYSCLK_FREQUENCY_HZ)/(1000));
signal timeout_cnt        : integer range 0 to (TIMEOUT_PERIOD_CLOCKS - 1) := 0;
signal reset_timeout_cnt  : STD_LOGIC := '0';

begin

---------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------->  CHECK CNT  <-----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
 
Count_periodic_check: process (clk, periodic_check_cnt, reset_periodic_check_cnt)
begin
   if clk'EVENT AND clk = '1' then
      if reset_periodic_check_cnt = '1' then
         periodic_check_cnt <= 0;
      elsif periodic_check_cnt < (CHECK_PERIOD_CLOCKS - 1) then  
         periodic_check_cnt <= periodic_check_cnt + 1;
      end if;
   end if;
end process Count_periodic_check;

---------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------->  TIMEOUT CNT  <-----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

Count_timeout: process (clk, timeout_cnt, reset_timeout_cnt)
begin
   if clk'EVENT AND clk = '1' then
      if reset_timeout_cnt = '1' then
         timeout_cnt <= 0;
      elsif timeout_cnt < (TIMEOUT_PERIOD_CLOCKS - 1) then   
         timeout_cnt <= timeout_cnt + 1;
      end if;
   end if;
end process Count_timeout;


   xpos <= x_pos when rising_edge(clk);
   ypos <= y_pos when rising_edge(clk);
    
   
---------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------->  SET X  <-----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

   --  computes the new x_pos from the old position when new x movement detected by 
   -- adding the delta movement in x_inc, or by adding 256 or -256 when overflow occurs.
  set_x: process(clk)
   variable x_inter: std_logic_vector(11 downto 0);
  begin
      if(rising_edge(clk)) then
         if(state = read_byte_2) then
            -- if negative movement on x axis
            if(x_sign = '1') then
               -- if overflow occurred
               if(x_overflow = '1') then
                  x_inter := x_pos + "111000000000";-- inc is -256
               else
                  x_inter := x_pos + ("1111" & rx_data);-- inc is sign extended x_inc
               end if;
               -- first bit of x_inter is 1 => negative overflow => new x position=0
               if(x_inter(11) = '1') then
                  x_pos <= (others => '0');
               else
                  x_pos <= x_inter;
               end if;
            -- if positive movement on x axis
            else
               -- if overflow occurred
               if(x_overflow = '1') then
                  x_inter := x_pos + "000100000000"; -- inc is 256
               else
                  x_inter := x_pos + ("0000" & rx_data);
               end if;
               -- x_inter > x_max => OVERFLOW => new x position is x_max.
               if(x_inter > ('0' & MAX_X)) then
                  x_pos <= MAX_X;
               else
                  x_pos <= x_inter;
               end if;
            end if;
         end if;
      end if;
   end process set_x;

---------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------->  SET Y  <-----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

   set_y: process(clk)
   variable y_inter: std_logic_vector(11 downto 0);
   begin
      if(rising_edge(clk)) then
         if(state = read_byte_3) then
            -- if negative movement on y axis
            if(y_sign = '1') then
               -- if overflow occurred
               if(y_overflow = '1') then
                  y_inter := y_pos + "111100000000"; -- inc is -256
               else
                  y_inter := y_pos + ("1111" & ((not rx_data) + "00000001"));
               end if;
               -- if first bit of y_inter is 1=>negative overflow =>new y position is 0.
               if(y_inter(11) = '1') then
                  y_pos <= (others => '0');
               else
                  y_pos <= y_inter;
               end if;
            -- deplasare pozitiva
            else
               -- overflow
                if(y_overflow = '1') then
                  y_inter := y_pos + "000100000000"; -- inc is 256
               else
                    if(rx_data /= X"00") then
                          y_inter := y_pos + ("0000" & ((not rx_data) + "00000001"));
                    end if;
               end if;
               -- if y_inter is greater than y_max => overflow => new y position = y_max.
               if (y_inter > (MAX_Y)) then
                  y_pos <= MAX_Y;
               else
                  y_pos <= y_inter;
               end if;
            end if;
         end if;
      end if;
   end process set_y;
   
---------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------->   FSM   <-----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

   -- mouse-ul este resetat  initializat dupa care transmite date
   manage_fsm: process(clk,rst)
   begin
   if(rising_edge(clk)) then
      if(rst = '1') then
         state <= reset;
         haswheel <= '0';
         x_overflow <= '0';
         y_overflow <= '0';
         x_sign <= '0';
         y_sign <= '0';
         new_event <= '0';
         left <= '0';
         middle <= '0';
         right <= '0';
         reset_periodic_check_cnt <= '1';
         reset_timeout_cnt <= '1';
      else
         write_data <= '0';
         case state is

            -- powered-up/reset/error then => RESET state. RESET command (FF) is sent to the mouse
            -- From here the FSM transitions to a series of states that perform the mouse initialization procedure. 

----------------------------------------------------------------->   RESET
            when reset =>
               haswheel <= '0';
               x_overflow <= '0';
               y_overflow <= '0';
               x_sign <= '0';
               y_sign <= '0';
               left <= '0';
               middle <= '0';
               right <= '0';
               tx_data <= FF;
               write_data <= '1';
               reset_periodic_check_cnt <= '1';
               reset_timeout_cnt <= '1';               
               state <= reset_wait_ack;

            when reset_wait_ack =>
               if(read_data = '1') then
                  if(rx_data = FA) then
                     state <= start;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= reset_wait_ack;
               end if;

----------------------------------------------------------------->   START
            when start =>
               if(read_data = '1') then
                  if(rx_data = AA) then
                     state <= wait_id;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= start;
               end if;

----------------------------------------------------------------->   WAIT ID 
            when wait_id =>
               if(read_data = '1') then
                  if(rx_data = OO) then
                     state <= Sread_id;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= wait_id;
               end if;

            -- The mouse id is requested and if the mouse id is 03, then mouse is
            -- in wheel mode and will send 4 byte packets when reporting is enabled.
            -- If the id is 00, the mouse does not have a wheel
            -- and will send 3 byte packets when reporting is enabled.
            when Sread_id =>
               tx_data <= READ_ID;
               write_data <= '1';
               state <= read_id_wait_ack;

            when read_id_wait_ack =>
               if(read_data = '1') then
                  if(rx_data = FA) then
                     state <= read_id_wait_id;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
           else
                  state <= read_id_wait_ack;
               end if;

            when read_id_wait_id =>
               if(read_data = '1') then
                  if(rx_data = x"00" or rx_data = x"03") then
                     haswheel <= rx_data(0);-- = 0 pt data = 0 \ =1 pt data = 3
                     state <= Sset_resolution;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= read_id_wait_id;
               end if;

----------------------------------------------------------------->   RESOLUTION  
            when Sset_resolution =>
               tx_data <= SET_RESOLUTION;
               write_data <= '1';
               state <= set_resolution_wait_ack;

            when set_resolution_wait_ack =>
               if(read_data = '1') then
                  if(rx_data = FA) then
                     state <= send_resolution;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= set_resolution_wait_ack;
               end if;

            when send_resolution =>
               tx_data <= RESOLUTION;
               write_data <= '1';
               state <= send_resolution_wait_ack;

            when send_resolution_wait_ack =>
               if(read_data = '1') then
                  if(rx_data = FA) then
                     state <= set_rate;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= send_resolution_wait_ack;
               end if;
               
----------------------------------------------------------------->   SET SAMPLE RATE  
            when set_rate =>
               tx_data <= SET_SAMPLE_RATE;
               write_data <= '1';
               state <= set_rate_wait_ack;

            when set_rate_wait_ack =>
               if(read_data = '1') then
                  if(rx_data = FA) then
                     state <= send_rate;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= set_rate_wait_ack;
               end if;

            when send_rate =>
               tx_data <= SAMPLE_RATE;
               write_data <= '1';
               state <= send_rate_wait_ack;

            when send_rate_wait_ack =>
               if(read_data = '1') then
                  if(rx_data = FA) then
                     state <= en_reporting;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= send_rate_wait_ack;
               end if;

----------------------------------------------------------------->   ENABLE REPORTING 
            when en_reporting =>
               tx_data <= ENABLE_REPORTING;
               write_data <= '1';
               state <= en_reporting_wait_ack;

            when en_reporting_wait_ack =>
               if(read_data = '1') then
                  if(rx_data = FA) then
                     state <= read_byte_1;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= en_reporting_wait_ack;
               end if;

----------------------------------------------------------------->   BYTE 1  
            when read_byte_1 =>
               reset_periodic_check_cnt <= '0';
               new_event <= '0';
               zpos <= (others => '0');
               if(read_data = '1') then
                  left <= rx_data(0);
                  middle <= rx_data(2);
                  right <= rx_data(1);
                  x_sign <= rx_data(4);
                  y_sign <= not rx_data(5);
                  x_overflow <= rx_data(6);
                  y_overflow <= rx_data(7);
                  state <= read_byte_2;
               elsif periodic_check_cnt = (CHECK_PERIOD_CLOCKS - 1) then -- Check periodically if the mouse is present
                  state <= check_id;
               else
                  state <= read_byte_1;
               end if;
               

----------------------------------------------------------------->   BYTE2  
            when read_byte_2 =>
               if(read_data = '1') then
                  state <= read_byte_3;
               elsif periodic_check_cnt = (CHECK_PERIOD_CLOCKS - 1) then 
                  state <= check_id;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= read_byte_2;
               end if;
            
----------------------------------------------------------------->   BYTE3 
            when read_byte_3 =>
               if(read_data = '1') then
                  if(haswheel = '1') then
                     state <= read_byte_4;
                  else
                     state <= Snew_event;
                  end if;
               elsif periodic_check_cnt = (CHECK_PERIOD_CLOCKS - 1) then
                  state <= check_id;
               elsif(err = '1') then
                  state <= reset;
               else
                     state <= read_byte_3;
               end if;

----------------------------------------------------------------->   BYTE4  
            -- only reached when mouse is in scroll mode wait for the fourth byte to arrive
            when read_byte_4 =>
               if(read_data = '1') then
                  zpos <= rx_data(3 downto 0);
                  state <= Snew_event;
               elsif periodic_check_cnt = (CHECK_PERIOD_CLOCKS - 1) then
                  state <= check_id;
               elsif(err = '1') then
                  state <= reset;
               else
                  state <= read_byte_4;
               end if;
               
----------------------------------------------------------------->   CHECK 
            when check_id =>
               reset_timeout_cnt <= '0';
               tx_data <= READ_ID;
               write_data <= '1';
               state <= check_id_wait_ack;

            when check_id_wait_ack =>
               if(read_data = '1') then
                  if(rx_data = FA) then
                     state <= check_id_wait_id;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               elsif (timeout_cnt = (TIMEOUT_PERIOD_CLOCKS - 1)) then
                  state <= reset;
               else
                  state <= check_id_wait_ack;
               end if;

            when check_id_wait_id =>
               if(read_data = '1') then
                  if(rx_data = "000000000") or (rx_data = "00000011") then
                     reset_timeout_cnt <= '1';
                     state <= read_byte_1;
                  else
                     state <= reset;
                  end if;
               elsif(err = '1') then
                  state <= reset;
               elsif (timeout_cnt = (TIMEOUT_PERIOD_CLOCKS - 1)) then
                  state <= reset;
               else
                  state <= check_id_wait_id;
               end if;


----------------------------------------------------------------->   NEW EVENT
            when Snew_event =>
               new_event <= '1';
               state <= read_byte_1;

            when others =>
               state <= reset;
                  
         end case;
      end if;
    end if;
   end process manage_fsm;
   
end Behavioral;