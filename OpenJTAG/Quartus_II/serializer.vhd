-- Created by Ruben H. Mileca - May-16-2010

--Module version 1.4


library ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;

entity serializer is

		port (

-- Internal

		wcks:	in std_logic;						-- From clock divisor

-- FT245BM

		txe:	in std_logic;						-- From FT245BM TXE# pin
		rxf:	in std_logic;						-- From FT245BM RXF pin
		wr:		out std_logic := '0';				-- To FT245BM WR pin
		rd:		out std_logic := '1';				-- To FT245BM RD# pin
		db:		inout std_logic_vector(7 downto 0);	-- From/To FT245BM data bus
		rst:	in std_logic;						-- From FT245BM RESET# pin

-- Clock divisor

		cd:		out std_logic_vector(2 downto 0);	-- Clock divisor

-- JTAG pins

		tck:	out std_logic := '0';
		tms:	out std_logic := '0';
		tdi:	out std_logic := '0';
		trst:	out std_logic := '1';
		tdo:	in std_logic;

-- LEDS

		led1:	out std_logic := '1';
		led2:	out std_logic := '1';

		test:	out std_logic := '1';

-- Target power state

		pwr:	in std_logic
	);

end serializer;

architecture behavioural of serializer is

	signal ft_byte:		std_logic_vector(7 downto 0);
	signal tdo_in:		std_logic_vector(7 downto 0);
	signal ft_state:	integer range 0 to 4 := 0;
	signal sm_state:	integer range 0 to 30 := 0;
	signal ft_2nd:		integer range 0 to 1 := 0;
	signal ad_clock:	std_logic;
	signal sm_msb:		std_logic := '0';
	signal sm_tms:		std_logic := '0';
	signal byte_count:	integer range 0 to 255 := 0;

-- TAP SM

	signal tap_state:	integer range 0 to 15 := 0;
	signal tap_nstate:	integer range 0 to 15 := 0;
	signal tap_pos:		integer range 0 to 1  := 0;
	signal tap_ok:		std_logic := '1';

begin

	
rd_wr: process(wcks, rxf, txe, rst)

begin

	if (rst = '1') then
		tms <= '0';
		tck <= '0';
		tdi <= '0';
		trst <= '1';
		cd <= "111";
		sm_state <= 0;
		ft_state <= 0;
	elsif (rising_edge(wcks)) then

----------------------------------------------------------------
-- TAP STATE MACHINE
----------------------------------------------------------------

		if (tap_state /= tap_nstate) then
			tap_ok <= '0';
			if (tap_pos = 0) then
				tck <= '0';
			else
				tck <= '1';
			end if;
--	Test-Logic Reset
			if (tap_state = 0) then
				if (tap_pos = 0) then
					tms <= '0';
					tap_pos <= 1;
				else
					tap_pos <= 0;
					tap_state <= tap_state + 1;
				end if;
-- Run Test Iddle, Shift DR, Pause DR, Shift IR, Pause IR
			elsif (tap_state = 1 or tap_state = 4 or tap_state = 6 or tap_state = 11 or tap_state = 13) then
				if (tap_pos = 0) then
					tms <= '1';		-- Low TMS to exit state
					tap_pos <= 1;	-- Next clock state
				else
					tap_pos <= 0;
					tap_state <= tap_state + 1;
				end if;
-- Select DR Scan
			elsif (tap_state = 2) then
				if (tap_pos = 0) then
					if (tap_nstate < 9 and tap_nstate > 2) then
						tms <= '0';
					else 
						tms <= '1';
					end if;
					tap_pos <= 1;	-- Next clock state
				else
					if (tap_nstate < 9 and tap_nstate > 2) then
						tap_state <= tap_state + 1;
					else 
						tap_state <= 9;
					end if;
					tap_pos <= 0;
				end if;
			elsif (tap_state = 9) then
				if (tap_pos = 0) then
					if (tap_nstate < 16 and tap_nstate > 9) then
						tms <= '0';
					else 
						tms <= '1';
					end if;
					tap_pos <= 1;	-- Next clock state
				else
					if (tap_nstate < 16 and tap_nstate > 9) then
						tap_state <= tap_state + 1;
					else 
						tap_state <= 0;
					end if;
					tap_pos <= 0;
				end if;
-- Capture DR, Capture IR
			elsif (tap_state = 3 or tap_state = 10) then
				if (tap_pos = 0) then
					if ((tap_state + 1) = tap_nstate) then
						tms <= '0';
					else 
						tms <= '1';
					end if;
					tap_pos <= 1;	-- Next clock state
				else
					if ((tap_state + 1) = tap_nstate) then
						tap_state <= tap_state + 1;
					else 
						tap_state <= tap_state + 2;
					end if;
					tap_pos <= 0;
				end if;
-- Exit-1 DR, Exit-1 IR
			elsif (tap_state = 5 or tap_state = 12) then
				if (tap_pos = 0) then
					if ((tap_state + 1) = tap_nstate) then
						tms <= '0';
					else 
						tms <= '1';
					end if;
					tap_pos <= 1;	-- Next clock state
				else
					if ((tap_state + 1) = tap_nstate) then
						tap_state <= tap_state + 1;
					else 
						tap_state <= tap_state + 3;
					end if;
					tap_pos <= 0;
				end if;
--	Exit-2 DR, Exit-2 IR
			elsif (tap_state = 7 or tap_state = 14) then
				if (tap_pos = 0) then
					if ((tap_state + 1) = tap_nstate) then
						tms <= '1';
					else 
						if (tap_nstate = 4 or tap_nstate = 11) then
							tms <= '0';
						else
							tms <= '1';
						end if;
					end if;
					tap_pos <= 1;	-- Next clock state
				else
					if ((tap_state + 1) = tap_nstate) then
						tap_state <= tap_state + 1;
					else 
						if (tap_nstate = 4 or tap_nstate = 11) then
							tap_state <= tap_state - 3;
						else
							tap_state <= tap_state + 1;
						end if;
					end if;
					tap_pos <= 0;
				end if;
-- Update DR, Update IR
			elsif (tap_state = 8 or tap_state = 15) then
				if (tap_pos = 0) then
					if (tap_nstate = 1) then
						tms <= '0';
					else 
						tms <= '1';
					end if;
					tap_pos <= 1;	-- Next clock state
				else
					if (tap_nstate = 1) then
						tap_state <= 1;
					else 
-- User joshcheng patch
						tap_state <= 2;
--						tap_state <= tap_state - 6;
					end if;
					tap_pos <= 0;
				end if;
			end if;
		else
			if (tap_ok = '0') then
				tck <= '0';
				tms <= '0';
				tap_ok <= '1';
			end if;
		end if;

----------------------------------------------------------------
-- FTDI and command process
----------------------------------------------------------------

		case sm_state is

----------------------------------------------------------------
--	FTDI read cycle
----------------------------------------------------------------

			when 0 =>
				case ft_state is
					when 0 =>	if (rxf = '0') then			-- Byte to read?
--									led1 <= '0';
									ft_state <= 1;			-- Next state
								end if;
					when 1 =>	rd <= '0';					-- Set rd to 0
								test <= '0';
								ft_state <= 2;				-- Next state
					when 2 =>	ft_byte <= db;				-- Read byte from FTDI
								ft_state <= 3;				-- Next state
					when 3 =>	rd <= '1';					-- Set rd to 1
								test <= '1';
								ft_state <= 0;				-- Next state
								ft_state <= 0;
								sm_state <= 1;
--								led1 <= '1';
					when others =>
				end case;

----------------------------------------------------------------
--	Process byte cycle
----------------------------------------------------------------

			when 1 =>
				if (ft_2nd = 0) then						-- Command byte
					case ft_byte(3 downto 0) is				-- Decode command
						when "0000" =>						-- COMMAND: Set clock divisor
							ad_clock <= ft_byte(4);			-- Set adaptive clock
							cd <= ft_byte(7 downto 5);		-- Set clock divisor
							sm_state <= 0;					-- Done
							ft_state <= 0;					-- Read FTDI again
						when "0001" =>						-- COMMAND: Set TAP state
							tap_nstate <= to_integer(unsigned(ft_byte(7 downto 4)));		-- Set new TAP state
							sm_state <= 2;					-- Next SM state (wait TAP sm finish)
						when "0010" =>						-- COMMAND: Return TAP SM state
							ft_byte(3 downto 0) <= std_logic_vector(to_unsigned(tap_state, ft_byte(3 downto 0)'length));	-- Copy  state to byte to send
							ft_byte(4) <= sm_msb;			-- Return state MSB
							ft_byte(5) <= pwr;				-- Return target power state
							sm_state <= 5;					-- Start job
							ft_state <= 0;					-- Init FTDI state
						when "0011" =>						-- COMMAND: Software reset target�s TAP
							byte_count <= 4;				-- 5 TCK pulses with TMS = 1
							tms <= '1';						-- TMS must be high prevoiuos clock rissing edge
							sm_state <= 9;					-- Start job
						when "0100" =>						-- COMMAND: Hardware reset target TAP
							byte_count <= to_integer(unsigned(ft_byte(7 downto 4))) + 1;
							trst <= '0';					-- TRST = 0
							sm_state <= 11;					-- Start job
						when "0101" =>						-- COMMAND: Set LSB/MSB mode
							sm_msb <= ft_byte(4);			-- MSB first ON/OFF
							led1 <= ft_byte(5);				-- BLUE led ON/OFF
							led2 <= ft_byte(6);				-- TED led ON/OFF
							sm_state <= 0;
							ft_state <= 0;
						when "0110" =>						-- COMMAND: Shift out and Read n bits
							byte_count <= (to_integer(unsigned(ft_byte(7 downto 5))) + 1);
							sm_tms <= ft_byte(4);			-- TMS mode
							ft_2nd <= 1;					-- Wait for a second byte
							ft_state <= 0;
							sm_state <= 0;
						when "0111" =>						-- COMMAND: RTI loop
							if (tap_state = 1) then			-- Check if current state is RTI
								byte_count <= to_integer(unsigned(ft_byte(7 downto 4)));
								tms <= '0';					-- TMS mode
								ft_state <= 0;
								sm_state <= 25;				-- Start job
							else
								ft_state <= 0;
								sm_state <= 0;
							end if;
						when others =>
							ft_state <= 0;
							sm_state <= 0;
					end case;
				else										-- There is a second byte
					tdo_in <= "00000000";					-- Clean
					ft_state <= 0;
					sm_state <= 20;							-- Shift out the byte
					ft_2nd <= 0;
				end if;
----------------------------------------------------------------
--	Wait to the TAP SM  finish the work
----------------------------------------------------------------

			when 2 =>
				sm_state <= 3;
			when 3 =>
				sm_state <= 4;
			when 4 =>
				if (tap_ok = '1') then
					sm_state <= 0;
					ft_state <= 0;
				end if;

----------------------------------------------------------------
--	Write byte to FTDI
----------------------------------------------------------------

			when 5 =>
				if (txe = '0') then							-- If FTDI is ready to write
					db <= ft_byte;							-- Write to FTDI
					sm_state <= 6;
				end if;
			when 6 =>
				wr <= '1';
				sm_state <= 7;
			when 7 =>
				wr <= '0';
				sm_state <= 8;
			when 8 =>
				db <= "ZZZZZZZZ";
				sm_state <= 0;
				ft_state <= 0;							-- Init read cycle

----------------------------------------------------------------
--	Software reset target�s TAP
----------------------------------------------------------------

			when 9 =>
				tck <= '1';									-- TCK = 1
				sm_state <= 10;								-- Next SM state
			when 10 =>					
				tck <= '0';									-- TCK = 0;
				if (byte_count = 0) then					-- END
					tms <= '0';
					tap_state <= 0;
					tap_nstate <= 0;
					sm_state <= 0;
				else
					byte_count <= byte_count - 1;			-- Decrement count
					sm_state <= 9;							-- Loop to the previous state 9
				end if;

----------------------------------------------------------------
--	Hardware reset target TAP
----------------------------------------------------------------

			when 11 =>
				if (byte_count = 0) then
					trst <= '1';
					tap_state <= 0;
					tap_nstate <= 0;
					sm_state <= 0;
				else
					byte_count <= byte_count - 1;
				end if;

----------------------------------------------------------------
--	Shift out and Read n bits
----------------------------------------------------------------

			when 20 =>
				tck <= '0';
				if (sm_tms = '1' and byte_count = 1) then
					tms <= '1';
				end if;
				if (sm_msb = '0') then						-- MSB first
					tdi <= ft_byte(7);						-- Out TDI
					ft_byte(7 downto 1) <= ft_byte(6 downto 0);
					tdo_in(7 downto 1) <= tdo_in(6 downto 0);
					tdo_in(0) <= tdo;						-- Read TDO
				else 
					tdi <= ft_byte(0);
					ft_byte(6 downto 0) <= ft_byte(7 downto 1);
					tdo_in(6 downto 0) <= tdo_in(7 downto 1);
					tdo_in(7) <= tdo;
				end if;
				if (byte_count = 0) then
					if (sm_tms = '1') then
						tap_state <= tap_state + 1;
						tap_nstate <= tap_nstate + 1;
					end if;
					sm_state <= 22;
				else
					byte_count <= byte_count - 1;			-- Decrement count
					sm_state <= 21;
				end if;
			when 21 =>
				tck <= '1';
				sm_state <= 20;								-- Loop
			when 22 =>
				tck <= '0';
				tdi <= '0';
				tms <= '0';
				ft_byte <= tdo_in;
				sm_state <= 5;
				ft_state <= 0;
----------------------------------------------------------------
--	RTI Loop
----------------------------------------------------------------
			when 25 =>
				tck <= '1';									-- TCK = 1
				sm_state <= 26;								-- Next SM state
			when 26 =>					
				tck <= '0';									-- TCK = 0;
				if (byte_count = 0) then					-- END
					sm_state <= 0;
				else
					byte_count <= byte_count - 1;			-- Decrement count
					sm_state <= 25;							-- Loop to the previous state 9
				end if;
----------------------------------------------------------------
--	To future expansion
----------------------------------------------------------------

			when others =>

		end case;
	end if;
end process rd_wr;
end behavioural;
