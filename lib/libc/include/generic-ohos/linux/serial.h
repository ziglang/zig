/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI_LINUX_SERIAL_H
#define _UAPI_LINUX_SERIAL_H
#include <linux/types.h>
#include <linux/tty_flags.h>
struct serial_struct {
  int type;
  int line;
  unsigned int port;
  int irq;
  int flags;
  int xmit_fifo_size;
  int custom_divisor;
  int baud_base;
  unsigned short close_delay;
  char io_type;
  char reserved_char[1];
  int hub6;
  unsigned short closing_wait;
  unsigned short closing_wait2;
  unsigned char * iomem_base;
  unsigned short iomem_reg_shift;
  unsigned int port_high;
  unsigned long iomap_base;
};
#define ASYNC_CLOSING_WAIT_INF 0
#define ASYNC_CLOSING_WAIT_NONE 65535
#define PORT_UNKNOWN 0
#define PORT_8250 1
#define PORT_16450 2
#define PORT_16550 3
#define PORT_16550A 4
#define PORT_CIRRUS 5
#define PORT_16650 6
#define PORT_16650V2 7
#define PORT_16750 8
#define PORT_STARTECH 9
#define PORT_16C950 10
#define PORT_16654 11
#define PORT_16850 12
#define PORT_RSA 13
#define PORT_MAX 13
#define SERIAL_IO_PORT 0
#define SERIAL_IO_HUB6 1
#define SERIAL_IO_MEM 2
#define SERIAL_IO_MEM32 3
#define SERIAL_IO_AU 4
#define SERIAL_IO_TSI 5
#define SERIAL_IO_MEM32BE 6
#define SERIAL_IO_MEM16 7
#define UART_CLEAR_FIFO 0x01
#define UART_USE_FIFO 0x02
#define UART_STARTECH 0x04
#define UART_NATSEMI 0x08
struct serial_multiport_struct {
  int irq;
  int port1;
  unsigned char mask1, match1;
  int port2;
  unsigned char mask2, match2;
  int port3;
  unsigned char mask3, match3;
  int port4;
  unsigned char mask4, match4;
  int port_monitor;
  int reserved[32];
};
struct serial_icounter_struct {
  int cts, dsr, rng, dcd;
  int rx, tx;
  int frame, overrun, parity, brk;
  int buf_overrun;
  int reserved[9];
};
struct serial_rs485 {
  __u32 flags;
#define SER_RS485_ENABLED (1 << 0)
#define SER_RS485_RTS_ON_SEND (1 << 1)
#define SER_RS485_RTS_AFTER_SEND (1 << 2)
#define SER_RS485_RX_DURING_TX (1 << 4)
#define SER_RS485_TERMINATE_BUS (1 << 5)
  __u32 delay_rts_before_send;
  __u32 delay_rts_after_send;
  __u32 padding[5];
};
struct serial_iso7816 {
  __u32 flags;
#define SER_ISO7816_ENABLED (1 << 0)
#define SER_ISO7816_T_PARAM (0x0f << 4)
#define SER_ISO7816_T(t) (((t) & 0x0f) << 4)
  __u32 tg;
  __u32 sc_fi;
  __u32 sc_di;
  __u32 clk;
  __u32 reserved[5];
};
#endif