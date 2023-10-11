library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity usart_broadcaster is
  Port (
    clock : in std_logic;
    resetn : in std_logic;

    usart_data : out std_logic_vector(7 downto 0);
    usart_data_valid : out std_logic;
    
		
    usart_print : out std_logic_vector(7 downto 0);
    usart_print_valid : out std_logic;
    usart_print_done : in std_logic;
    usart_read : in std_logic_vector(7 downto 0);
    usart_read_valid : in std_logic;
    usart_read_request : out std_logic
  );
end usart_broadcaster;

architecture behavioral of usart_broadcaster is
    type t_State is (DATA_REQUEST, DATA_SEND);
    signal state : t_State;
begin
    process(clock) is
    begin
        if rising_edge(clock) then
            if resetn = '0' then
                state <= DATA_REQUEST;
            else
                case state is
                    -- request a read
                    when DATA_REQUEST =>
                        usart_print_valid <= '0'; -- done printing
                        usart_data_valid <= '0'; -- out data invalid

                        usart_read_request <= '1';
                        
                        if (usart_read_valid = '1' and usart_print_done = '0') then
                            -- done reading and ready to print; prepare printing
                            usart_data <= usart_read;
                            usart_print <= usart_read;

                            state <= DATA_SEND;
                        end if;

                    -- print request
                    when DATA_SEND =>
                        usart_read_request <= '0'; -- done reading
                        usart_data_valid <= '1'; -- out data valid

                        -- data already loaded on the last state
                        usart_print_valid <= '1';
                        
                        if (usart_print_done = '1' and usart_read_valid = '0') then
                            -- done printing and ready to read
                            state <= DATA_REQUEST;
                        end if;
                end case;
            end if;
        end if;
    end process;
end behavioral;
