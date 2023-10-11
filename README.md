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

1. Create a new Vivado project

![create project](./images/00-create_project.jpg "create project")

Select "RTL Project" as the Project Type.

![create project - project type](./images/01-create_project_2.jpg "create project - project type")

2. Under the "Boards" section, select your board. If you don't have it installed, hit the "download" button next to it

![select board](./images/02-select_board.jpg "select board")

3. Select "Finish"

![create project summary](./images/03-create_project_summary.jpg "create project summary")

4. As this tutorial will use VHDL as language, enter the Settings menu (top left, the cogwheel icon), and switch "Target language" to VHDL. Then hit "Apply", and "OK"

![target language](./images/04-vhdl_language.jpg "target language")

### Creating a custom AXI IP

To interact with the AXI interface we'll need a custom IP.

1. Under "Tools", click "Create and Package New IP..."

![create ip](./images/10-create_ip.jpg "create ip")

2. Hit "Next", select "Create a new AXI4 peripheral", then "Next"

![create ip homepage](./images/11-create_ip_2.jpg "create ip homepage")

![create AXI4 ip](./images/12-create_axi4_ip.jpg "create AXI4 ip")

3. Set the IP name `usart_to_pl`. You can also set a description

![ip name](./images/13-ip_details.jpg "ip name")

4. Leave the ports as default

![ip ports](./images/14-ip_ports.jpg "ip ports")

5. Select "Edit IP", then "Finish"

![edit ip](./images/15-edit_ip.jpg "edit ip")

### Editing the custom IP

Once you've created the IP a new Vivado window will open. On Sources > Design Sources you'll find the `usart_to_pl` wrapper, and the instance.

#### Editing the custom IP instance

1. First we'll edit the `usart_to_pl` instance. Double click on `usart_to_pl_v_1_0_S00_AXI_inst`

![edit instance](./images/16-edit_inst.jpg "edit instance")

2. Add the following ports:

```vhdl
-- Users to add ports here
		
usart_print : in std_logic_vector(7 downto 0);
usart_print_valid : in std_logic;
usart_print_done : out std_logic;

usart_read : out std_logic_vector(7 downto 0);
usart_read_valid : out std_logic;
usart_read_request : in std_logic;
```

They will be used to request read and prints from the USART.

3. On the "user logic" section, link the out ports with the register 0 and 1:

```vhdl
-- Add user logic here

usart_read <= slv_reg0(7 downto 0);
usart_read_valid <= slv_reg0(8);
usart_print_done <= slv_reg1(0);
```

4. To send data, we'll need to modify the "Implement memory mapped register" section. Find it, and then change the sensitivity list and `loc_addr` `10` and `11` output:

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

#### Editing the custom IP wrapper

5. Now open the wrapper (`usart_to_pl_v_1_0`)

6. Add the ports we've added earlier:

```vhdl
-- Users to add ports here

usart_print : in std_logic_vector(7 downto 0);
usart_print_valid : in std_logic;
usart_print_done : out std_logic;

usart_read : out std_logic_vector(7 downto 0);
usart_read_valid : out std_logic;
usart_read_request : in std_logic;
```

7. In the `usart_to_pl_v1_0_S00_AXI` port definition, you'll have to add the ports again:

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

8. On the part of the code the instance is made, connect the ports:

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

#### Finishing the custom IP

9. On the "Package IP" tab, go to "Customization Parameters", then hit "Merge changes from Customization Parameters Wizard"

![apply parameters changes](./images/19-apply_changes.jpg "apply parameters changes")

10. On "Compatibility", make sure "zynq" is there. Otherwise, hit the "+" button, "Add Family Explicitly...", and select "zynq". Life-cycles are irrelevant in this tutorial

![check compatibility](./images/20-check_board.jpg "check compatibility")

<details>
  <summary>Not there? Check: how to add a compatible board</summary>

  ![add compatibility board](./images/21-add_board.jpg "add compatibility board")

  ![select compatibility board](./images/22-select_board_to_add.jpg "select compatibility board")
</details>

11. On Vivado version 2023.1 there's a bug with the generated Makefile on custom IPs (you can check for more information [here](https://support.xilinx.com/s/question/0D52E00006iHq5pSAC/board-images-not-set-and-xpfm-file-deleted-automatically?language=en_US)). To solve it you'll have to go to the IP path you've selected, go to `drivers/usart_to_pl_v1_0/src`, and change the Makefile from:

```
INCLUDEFILES=*.h
LIBSOURCES=*.c
OUTS = *.o
```

To:

```
INCLUDEFILES=$(wildcard *.h)
LIBSOURCES=$(wildcard *.c)
OUTS=$(wildcard *.o)
```

12. Go to "Review and Package", and hit "Re-Package IP"

![package ip](./images/25-package_ip.jpg "package ip")

13. Close the project

![close custom ip project](./images/26-close_project.jpg "close custom ip project")

### Creating a Block Design

1. On the left, select "IP Integrator > Create Block Design"

![create block design](./images/30-create_block_design.jpg "create block design")

2. You can set a name if you want, I'll leave it as default

![block design name](./images/31-block_design_name.jpg "block design name")

3. The design will open. Right click on it, "Add IP..."

![add ip on design](./images/32-add_ip.jpg "add ip on design")

4. Search for "ZYNQ7 Processing System", and add it

![add the ps](./images/33-add_ps.jpg "add the ps")

5. On the top, click "Run Block Automation". Leave it all as default, hit "OK"

![run block automation](./images/34-auto_block.jpg "run block automation")

![run block automation](./images/35-run_auto_block.jpg "run block automation")

6. Again, right click, "Add IP...", and add the custom IP

![add custom ip](./images/36-add_custom_ip.jpg "add custom ip")

7. On the top, click "Run Connection Automation". Leave it all as default, hit "OK"

![run connection automation](./images/37-auto_trace.jpg "run connection automation")

![run connection automation](./images/38-run_auto_trace.jpg "run connection automation")

8. You should see something like this:

![block diagram result](./images/39-add_ip_result.jpg "block diagram result")

### Adding extra sources

To broadcast the data and send it to the LEDs we'll need 3 files:
- `ascii_to_number`: will take the ASCII data and convert it to a binary output
- XDC file: will tell Vivado how to connect the external ports to the Zybo board
- `usart_broadcaster`: will request the data, and then send it back and to `ascii_to_number`, respecting the timings defined by the custom IP (we'll talk about it later)

1. Right click on "Design Sources", then "Add Sources..."

![add sources](./images/40-add_sources.jpg "add sources")

2. We'll add first two design sources

![add design sources](./images/41-add_design_sources.jpg "add design sources")

3. Hit "Create File", add an VHDL file `usart_broadcaster` and then `ascii_to_number`, and then hit "Finish"

![create design sources](./images/42-create_file.jpg "create design sources")

![create design source](./images/43-create_file_1.jpg "create design source")

![created design sources](./images/44-created_files.jpg "created design sources")

4. Leave everything as default, hit "OK"

![review design sources](./images/45-review_files.jpg "review design sources")

5. Open `ascii_to_number`, paste the following code:

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

6. Open `usart_broadcaster`, paste the following code:

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

The broadcaster has two states, one to request a data, and the other to print it (and forward it to the other PL blocks). That way we meet the following timing criteria:

![print request](./images/print_request.jpg "print request")

![scan request](./images/scan_request.jpg "scan request")

7. Drag&drop `usart_broadcaster`, then connect the ports with their respective ports on `usart_to_pl`. Connect `clock` to `s00_axi_aclk`, and `resetn` to `s00_axi_resetn`. For convenience, I've rotated the usart_to_pl block in the diagram

![broadcaster connection](./images/48-broadcaster.jpg "broadcaster connection")

8. Drag&drop `ascii_to_number`, then connect the ports to the broadcaster

9. Right click on `ascii_to_number`'s out port, "Make External"

![external pin](./images/50-external_pin.jpg "external pin")

10. Set the external pin name to "led"

![external pin name](./images/51-external_pin_name.jpg "external pin name")

11. Now we'll add the XDC file. Right click on "Design Sources", "Add Sources...", and this time select "Add or create constraints"

![add sources](./images/40-add_sources.jpg "add sources")

![add constraints source](./images/52-add_constraints.jpg "add constraints source")

12. Select "Add Files"

![add existant constraints source](./images/53-add_existant_constraint.jpg "add existant constraints source")

13. Search your board's XDC file (if you don't have it check how to get it on the [Requirements section](#requirements))

![add master constraint](./images/54-add_master_constraint.jpg "add master constraint")

14. Make sure "Copy constraints file into project" is checked, then hit "Finish"

![copy master constraint](./images/55-copy_constraint.jpg "copy master constraint")

15. The file is under the Constraints folder, double click to open it

![open constraint](./images/56-open_constraint.jpg "open constraint")

16. Uncomment the LEDs constraints:

```
##LEDs
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; #IO_L23P_T3_35 Sch=led[0]
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; #IO_L23N_T3_35 Sch=led[1]
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; #IO_0_35 Sch=led[2]
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; #IO_L3N_T0_DQS_AD1N_35 Sch=led[3]
```

### Exporting to Vitis

1. Right click on the created block design, "Create HDL Wrapper..."

![create hdl wrapper](./images/58-hdl_wrapper.jpg "create hdl wrapper")

2. Select "Let Vivado manage wrapper and auto update", and hit "OK"

![create hdl wrapper](./images/59-create_dhl_wrapper.jpg "create hdl wrapper")

If you get a `Parameter has negative value` warning ignore it.

![ignore warning](./images/60-ignore-warning.jpg "ignore warning")

3. On the top, select "Generate Bitstream"

![generate bitstream](./images/61-generate_bitstream.jpg "generate bitstream")

4. Launch as many jobs as you can, then hit "OK"

![start bitstream generation](./images/62-start_bistream_generation.jpg "start bitstream generation")

5. Wait for the bitstream generation (you'll see the loading process on the top right)

![wait bitstream generation](./images/63-bistream_generation_in_progress.jpg "wait bitstream generation")

6. Once it's done a window will pop, hit "Cancel"

![close window](./images/64-bistream_generation_done.jpg "close window")

7. Select "File > Export > Export Hardware..."

![export hardware](./images/65-export_hardware.jpg "export hardware")

8. Click "Next"

![export hardware homepage](./images/66-export_hardware_platform.jpg "export hardware homepage")

9. Make sure "Include bitstream" is selected, then hit "Next"

![export hardware with bitstream](./images/67-include_bitstream.jpg "export hardware with bitstream")

10. Click "Next", "Finish"

![xsa path](./images/68-xsa_path.jpg "xsa path")

![export hardware summary](./images/69-export_hardware_summary.jpg "export hardware summary")

### Creating a Vitis project

1. Launch Vitis (you can use "Tools > Launch Vitis IDE")

![launch Vitis](./images/70-launch_vitis.jpg "launch Vitis")

2. Go to "File > New > Application Project..."

![create application](./images/71-create_application.jpg "create application")

3. Hit "Next"

![create application homepage](./images/72-create_app_homepage.jpg "create application homepage")

4. Go to "Create a new platform from hardware (XSA)", select "Browse..." and select the XSA you've exported on Vivado

![create platform from xsa](./images/73-create_platform_from_xsa.jpg "create platform from xsa")

![select exported xsa](./images/74-select_exported_xsa.jpg "select exported xsa")

5. Make sure "Generate boot components" is checked, then hit "Next"

![create platform](./images/75-create_platform.jpg "create platform")

6. Set `usart_from_pl` as "Application project name", then hit "Next"

![application name](./images/76-app_name.jpg "application name")

7. Leave the domain as default, hit "Next"

![application domain](./images/77-app_domain.jpg "application domain")

8. Select "Empty Application (C)"

![empty application](./images/78-empty_app.jpg "empty application")

### Creating the Vitis main

1. Right click the `src` folder, "New > File"

![new file](./images/79-new_file.jpg "new file")

2. Set `main.c` as name, hit "Finish"

![new main](./images/80-new_main.jpg "new main")

3. Open `main.c` (double click) and paste the following code:

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

4. Build the project (top left hammer icon)

![build project](./images/82-build.jpg "build project")

### Uploading the code to the board

1. Connect your board to the computer

2. Right click `usart_from_pl`, then "Run As > Launch Hardware (Single Application Debug)"

![upload project](./images/83-upload.jpg "upload project")

### Interacting with the board

You'll need a serial terminal to interact with the code, in this section we'll use the one included in Vitis.

1. Go to "Window > Show view..."

![showing the Vitis serial terminal](./images/90-serial_terminal_1.jpg "showing the Vitis serial terminal")

2. Search for "Vitis Serial Terminal", then hit "Open"

![showing the Vitis serial terminal](./images/91-serial_terminal_2.jpg "showing the Vitis serial terminal")

3. Now you should have it on the bottom right corner. Click the plus (+) icon to connect to the board

![connecting to the board](./images/92-serial_terminal_add.jpg "connecting to the board")

4. Select the only port available, then hit "OK". Leave the Baud Rate as it is (115200)

![connecting to the board](./images/93-serial_terminal_add_2.jpg "connecting to the board")

5. Send a number, and see the LEDs change!

![sending data with the serial terminal](./images/94-send_serial_terminal.jpg "sending data with the serial terminal")

![results](./images/results.jpg "results")

### Thanks for following!

Remember to give me a star if it was useful! I'm also open for PR for code improvements.

## References

- To create a project, refer to the ["Getting Started with Vivado and Vitis for Baremetal Software Projects" guide](https://digilent.com/reference/programmable-logic/guides/getting-started-with-ipi)
- All the boards XDC files are on the [Digilent XDC GitHub repo](https://github.com/Digilent/digilent-xdc)
- To create a slave AXI custom IP, refer to ["Creating a Custom IP core using the IP Integrator"](https://digilent.com/reference/learn/programmable-logic/tutorials/zybo-creating-custom-ip-cores/start)
- For the PS-PL exchange I used part of the code found on the ["Creating a Custom AXI4 Master in Vivado" tutorial](https://github.com/k0nze/zedboard_axi4_master_burst_example)
- The bug about the Makefile was discussed on the xilinx forum ["Board Images not set and .xpfm file deleted automatically"](https://support.xilinx.com/s/question/0D52E00006iHq5pSAC/board-images-not-set-and-xpfm-file-deleted-automatically)