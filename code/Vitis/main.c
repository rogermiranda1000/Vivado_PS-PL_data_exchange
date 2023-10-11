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