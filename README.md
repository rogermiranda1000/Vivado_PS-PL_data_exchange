# Creating a Custom IP for PS-PL data exchange in Vivado

In this tutorial you'll learn how to exchange information between the PS and PL, effectively allowing to read and write to the default USART from the PL.

## The results

In this example the USART data will be sent to the PL, and then the PL will send back the same data to the PL to be print in the terminal, and also (if it's a number) it will light their corresponding binary value using the on-board LEDs.

![steps](./images/steps.gif "steps")

![results](./images/results.jpg "results")

## Requirements

- Vivado & Vitis 2023.1 (you can check how to install them [here](https://digilent.com/reference/programmable-logic/guides/installing-vivado-and-vitis))
- A ZYBO Z7-10, or 20
- Your board XDC file (you should be able to find it [here](https://github.com/Digilent/digilent-xdc/archive/master.zip))

## Steps

### Creating a new Vivado project

17:

```vhdl
-- Users to add ports here
		
usart_print : in std_logic_vector(7 downto 0);
usart_print_valid : in std_logic;
usart_print_done : out std_logic;

usart_read : out std_logic_vector(7 downto 0);
usart_read_valid : out std_logic;
usart_read_request : in std_logic;
```


```vhdl
-- Add user logic here

usart_read <= slv_reg0(7 downto 0);
usart_read_valid <= slv_reg0(8);
usart_print_done <= slv_reg1(0);
```


```vhdl
-- Implement memory mapped register select and read logic generation
-- Slave register read enable is asserted when valid address is available
-- and the slave is ready to accept the read address.
slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

process (slv_reg0, slv_reg1, usart_print_valid, usart_print, usart_read_request, axi_araddr, S_AXI_ARESETN, slv_reg_rden)
variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
begin
  -- Address decoding for reading registers
  loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
  case loc_addr is
    when b"00" =>
      reg_data_out <= slv_reg0;
    when b"01" =>
      reg_data_out <= slv_reg1;
    when b"10" =>
      reg_data_out <= (C_S_AXI_DATA_WIDTH-1 downto 9 => '0') & usart_print_valid & usart_print; -- 8 LSB is the data, and the followed by the "is valid" bit. The rest is all 0
    when b"11" =>
      reg_data_out <= (C_S_AXI_DATA_WIDTH-1 downto 1 => '0') & usart_read_request;
    when others =>
      reg_data_out  <= (others => '0');
  end case;
end process; 
```



18:
```vhdl
-- Users to add ports here

usart_print : in std_logic_vector(7 downto 0);
usart_print_valid : in std_logic;
usart_print_done : out std_logic;

usart_read : out std_logic_vector(7 downto 0);
usart_read_valid : out std_logic;
usart_read_request : in std_logic;
```

```vhdl
architecture arch_imp of usart_to_pl_v1_0 is
-- component declaration
  component usart_to_pl_v1_0_S00_AXI is
    generic (
      C_S_AXI_DATA_WIDTH	: integer	:= 32;
      C_S_AXI_ADDR_WIDTH	: integer	:= 4
    );
    port (
      usart_print : in std_logic_vector(7 downto 0);
      usart_print_valid : in std_logic;
      usart_print_done : out std_logic;
      usart_read : out std_logic_vector(7 downto 0);
      usart_read_valid : out std_logic;
      usart_read_request : in std_logic;

      S_AXI_ACLK	: in std_logic;
      ...
```

```vhdl
-- Instantiation of Axi Bus Interface S00_AXI
usart_to_pl_v1_0_S00_AXI_inst : usart_to_pl_v1_0_S00_AXI
  generic map (
    C_S_AXI_DATA_WIDTH	=> C_S00_AXI_DATA_WIDTH,
    C_S_AXI_ADDR_WIDTH	=> C_S00_AXI_ADDR_WIDTH
  )
  port map (
    usart_print => usart_print,
    usart_print_valid => usart_print_valid,
    usart_print_done => usart_print_done,
    usart_read => usart_read,
    usart_read_valid => usart_read_valid,
    usart_read_request => usart_read_request,

    S_AXI_ACLK	=> s00_axi_aclk,
    ...
```



24 [bug](https://support.xilinx.com/s/question/0D52E00006iHq5pSAC/board-images-not-set-and-xpfm-file-deleted-automatically):
change:
```
INCLUDEFILES=*.h
LIBSOURCES=*.c
OUTS = *.o
```

to:
```
INCLUDEFILES=$(wildcard *.h)
LIBSOURCES=$(wildcard *.c)
OUTS=$(wildcard *.o)
```


46 - ascii_to_number:
```vhdl
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
```



47 - usart_broadcaster:
```vhdl
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
```

48 - drag&drop `usart_broadcaster`, then connect the ports with their respective ports on `usart_to_pl`. Connect `clock` to `s00_axi_aclk`, and `resetn` to `s00_axi_resetn`. For convenience, I've rotated the usart_to_pl block in the diagram.

49 - drag&drop `ascii_to_number`, then connect the ports with the broadcaster.


57 - uncomment the LEDs constraints
```
##LEDs
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; #IO_L23P_T3_35 Sch=led[0]
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; #IO_L23N_T3_35 Sch=led[1]
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; #IO_0_35 Sch=led[2]
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; #IO_L3N_T0_DQS_AD1N_35 Sch=led[3]
```


81 - open `helloworld.c` and paste the following code:
```c
#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xbasic_types.h"
#include "xparameters.h"
#include "xuartps_hw.h" // XUARTPS_FIFO_OFFSET

#define is_valid(data) ((data & (1<<8)) > 0)

Xuint8 unwaited_read(unsigned char *valid) {
	*valid = XUartPs_IsReceiveData(STDIN_BASEADDRESS);
	if (!(*valid)) return 0;

	return (Xuint8) XUartPs_ReadReg(STDIN_BASEADDRESS, XUARTPS_FIFO_OFFSET);
}

int main() {
	Xuint32 data;
	Xuint8 inp, valid;
	Xuint8 last_send_request = 0;
	Xuint8 send_request, print_request;
    volatile Xuint32 *slaveaddr_p = (Xuint32 *) XPAR_USART_TO_PL_0_S00_AXI_BASEADDR;

    xil_printf("\r\nWrite something:\r\n");

    while (1) {
    	send_request = (*(slaveaddr_p+3)) & 0x01;
		if (send_request > 0) {
	    	if (send_request != last_send_request) {
				// send chars from usart to PL
				inp=unwaited_read(&valid);
				if (valid) {
					data = (Xuint32)inp;
					data |= (1<<8); // mark as valid
					*slaveaddr_p = data; // send data

					last_send_request = send_request;
				}
	    	}
		}
		else {
			*slaveaddr_p = 0; // invalid
    		last_send_request = send_request;
		}

		// print data from PL to usart
		data = *(slaveaddr_p+2);
		print_request = is_valid(data);
		if (print_request) {
			xil_printf("%c", data&0xFFFF);
			*(slaveaddr_p+1) = 1; // print ok
		}
		else {
			*(slaveaddr_p+1) = 0; // done printing
		}
    }

    return 0;
}
```


## References

- To create a project, refer to the ["Getting Started with Vivado and Vitis for Baremetal Software Projects" guide](https://digilent.com/reference/programmable-logic/guides/getting-started-with-ipi)
- All the boards XDC files are on the [Digilent XDC GitHub repo](https://github.com/Digilent/digilent-xdc)
- To create a slave AXI custom IP, refer to ["Creating a Custom IP core using the IP Integrator"](https://digilent.com/reference/learn/programmable-logic/tutorials/zybo-creating-custom-ip-cores/start)
- For the PS-PL exchange I used part of the code found on the ["Creating a Custom AXI4 Master in Vivado" tutorial](https://github.com/k0nze/zedboard_axi4_master_burst_example)
- The bug about the Makefile was discussed on the xilinx forum ["Board Images not set and .xpfm file deleted automatically"](https://support.xilinx.com/s/question/0D52E00006iHq5pSAC/board-images-not-set-and-xpfm-file-deleted-automatically)