library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ascii_to_number is
  Port (
    value : in std_logic_vector(7 downto 0);
    value_valid : in std_logic;
    
    o : out std_logic_vector(3 downto 0)
  );
end ascii_to_number;

architecture Behavioral of ascii_to_number is
begin
    process(value,value_valid)
        variable result : unsigned(7 downto 0);
    begin
        if (value_valid = '1' and (value >= x"30" and value <= x"39")) then -- got a number?
            result := unsigned(value) - to_unsigned(48, 8); -- equivalent for ASCII character '0'; remember that 0 to 9 are consecutive ASCII elements
        end if;
        
        o <= std_logic_vector(result(3 downto 0));
    end process;
    
end Behavioral;
