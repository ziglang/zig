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
#ifndef _UAPI_LINUX_CYCLADES_H
#define _UAPI_LINUX_CYCLADES_H
#include <linux/types.h>
struct cyclades_monitor {
  unsigned long int_count;
  unsigned long char_count;
  unsigned long char_max;
  unsigned long char_last;
};
struct cyclades_idle_stats {
  __kernel_old_time_t in_use;
  __kernel_old_time_t recv_idle;
  __kernel_old_time_t xmit_idle;
  unsigned long recv_bytes;
  unsigned long xmit_bytes;
  unsigned long overruns;
  unsigned long frame_errs;
  unsigned long parity_errs;
};
#define CYCLADES_MAGIC 0x4359
#define CYGETMON 0x435901
#define CYGETTHRESH 0x435902
#define CYSETTHRESH 0x435903
#define CYGETDEFTHRESH 0x435904
#define CYSETDEFTHRESH 0x435905
#define CYGETTIMEOUT 0x435906
#define CYSETTIMEOUT 0x435907
#define CYGETDEFTIMEOUT 0x435908
#define CYSETDEFTIMEOUT 0x435909
#define CYSETRFLOW 0x43590a
#define CYGETRFLOW 0x43590b
#define CYSETRTSDTR_INV 0x43590c
#define CYGETRTSDTR_INV 0x43590d
#define CYZSETPOLLCYCLE 0x43590e
#define CYZGETPOLLCYCLE 0x43590f
#define CYGETCD1400VER 0x435910
#define CYSETWAIT 0x435912
#define CYGETWAIT 0x435913
#define CZIOC ('M' << 8)
#define CZ_NBOARDS (CZIOC | 0xfa)
#define CZ_BOOT_START (CZIOC | 0xfb)
#define CZ_BOOT_DATA (CZIOC | 0xfc)
#define CZ_BOOT_END (CZIOC | 0xfd)
#define CZ_TEST (CZIOC | 0xfe)
#define CZ_DEF_POLL (HZ / 25)
#define MAX_BOARD 4
#define MAX_DEV 256
#define CYZ_MAX_SPEED 921600
#define CYZ_FIFO_SIZE 16
#define CYZ_BOOT_NWORDS 0x100
struct CYZ_BOOT_CTRL {
  unsigned short nboard;
  int status[MAX_BOARD];
  int nchannel[MAX_BOARD];
  int fw_rev[MAX_BOARD];
  unsigned long offset;
  unsigned long data[CYZ_BOOT_NWORDS];
};
#ifndef DP_WINDOW_SIZE
#define DP_WINDOW_SIZE (0x00080000)
#define ZE_DP_WINDOW_SIZE (0x00100000)
#define CTRL_WINDOW_SIZE (0x00000080)
struct CUSTOM_REG {
  __u32 fpga_id;
  __u32 fpga_version;
  __u32 cpu_start;
  __u32 cpu_stop;
  __u32 misc_reg;
  __u32 idt_mode;
  __u32 uart_irq_status;
  __u32 clear_timer0_irq;
  __u32 clear_timer1_irq;
  __u32 clear_timer2_irq;
  __u32 test_register;
  __u32 test_count;
  __u32 timer_select;
  __u32 pr_uart_irq_status;
  __u32 ram_wait_state;
  __u32 uart_wait_state;
  __u32 timer_wait_state;
  __u32 ack_wait_state;
};
struct RUNTIME_9060 {
  __u32 loc_addr_range;
  __u32 loc_addr_base;
  __u32 loc_arbitr;
  __u32 endian_descr;
  __u32 loc_rom_range;
  __u32 loc_rom_base;
  __u32 loc_bus_descr;
  __u32 loc_range_mst;
  __u32 loc_base_mst;
  __u32 loc_range_io;
  __u32 pci_base_mst;
  __u32 pci_conf_io;
  __u32 filler1;
  __u32 filler2;
  __u32 filler3;
  __u32 filler4;
  __u32 mail_box_0;
  __u32 mail_box_1;
  __u32 mail_box_2;
  __u32 mail_box_3;
  __u32 filler5;
  __u32 filler6;
  __u32 filler7;
  __u32 filler8;
  __u32 pci_doorbell;
  __u32 loc_doorbell;
  __u32 intr_ctrl_stat;
  __u32 init_ctrl;
};
#define WIN_RAM 0x00000001L
#define WIN_CREG 0x14000001L
#define TIMER_BY_1M 0x00
#define TIMER_BY_256K 0x01
#define TIMER_BY_128K 0x02
#define TIMER_BY_32K 0x03
#endif
#ifndef ZFIRM_ID
#define MAX_CHAN 64
#define ID_ADDRESS 0x00000180L
#define ZFIRM_ID 0x5557465AL
#define ZFIRM_HLT 0x59505B5CL
#define ZFIRM_RST 0x56040674L
#define ZF_TINACT_DEF 1000
#define ZF_TINACT ZF_TINACT_DEF
struct FIRM_ID {
  __u32 signature;
  __u32 zfwctrl_addr;
};
#define C_OS_LINUX 0x00000030
#define C_CH_DISABLE 0x00000000
#define C_CH_TXENABLE 0x00000001
#define C_CH_RXENABLE 0x00000002
#define C_CH_ENABLE 0x00000003
#define C_CH_LOOPBACK 0x00000004
#define C_PR_NONE 0x00000000
#define C_PR_ODD 0x00000001
#define C_PR_EVEN 0x00000002
#define C_PR_MARK 0x00000004
#define C_PR_SPACE 0x00000008
#define C_PR_PARITY 0x000000ff
#define C_PR_DISCARD 0x00000100
#define C_PR_IGNORE 0x00000200
#define C_DL_CS5 0x00000001
#define C_DL_CS6 0x00000002
#define C_DL_CS7 0x00000004
#define C_DL_CS8 0x00000008
#define C_DL_CS 0x0000000f
#define C_DL_1STOP 0x00000010
#define C_DL_15STOP 0x00000020
#define C_DL_2STOP 0x00000040
#define C_DL_STOP 0x000000f0
#define C_IN_DISABLE 0x00000000
#define C_IN_TXBEMPTY 0x00000001
#define C_IN_TXLOWWM 0x00000002
#define C_IN_RXHIWM 0x00000010
#define C_IN_RXNNDT 0x00000020
#define C_IN_MDCD 0x00000100
#define C_IN_MDSR 0x00000200
#define C_IN_MRI 0x00000400
#define C_IN_MCTS 0x00000800
#define C_IN_RXBRK 0x00001000
#define C_IN_PR_ERROR 0x00002000
#define C_IN_FR_ERROR 0x00004000
#define C_IN_OVR_ERROR 0x00008000
#define C_IN_RXOFL 0x00010000
#define C_IN_IOCTLW 0x00020000
#define C_IN_MRTS 0x00040000
#define C_IN_ICHAR 0x00080000
#define C_FL_OXX 0x00000001
#define C_FL_IXX 0x00000002
#define C_FL_OIXANY 0x00000004
#define C_FL_SWFLOW 0x0000000f
#define C_FS_TXIDLE 0x00000000
#define C_FS_SENDING 0x00000001
#define C_FS_SWFLOW 0x00000002
#define C_RS_PARAM 0x80000000
#define C_RS_RTS 0x00000001
#define C_RS_DTR 0x00000004
#define C_RS_DCD 0x00000100
#define C_RS_DSR 0x00000200
#define C_RS_RI 0x00000400
#define C_RS_CTS 0x00000800
#define C_CM_RESET 0x01
#define C_CM_IOCTL 0x02
#define C_CM_IOCTLW 0x03
#define C_CM_IOCTLM 0x04
#define C_CM_SENDXOFF 0x10
#define C_CM_SENDXON 0x11
#define C_CM_CLFLOW 0x12
#define C_CM_SENDBRK 0x41
#define C_CM_INTBACK 0x42
#define C_CM_SET_BREAK 0x43
#define C_CM_CLR_BREAK 0x44
#define C_CM_CMD_DONE 0x45
#define C_CM_INTBACK2 0x46
#define C_CM_TINACT 0x51
#define C_CM_IRQ_ENBL 0x52
#define C_CM_IRQ_DSBL 0x53
#define C_CM_ACK_ENBL 0x54
#define C_CM_ACK_DSBL 0x55
#define C_CM_FLUSH_RX 0x56
#define C_CM_FLUSH_TX 0x57
#define C_CM_Q_ENABLE 0x58
#define C_CM_Q_DISABLE 0x59
#define C_CM_TXBEMPTY 0x60
#define C_CM_TXLOWWM 0x61
#define C_CM_RXHIWM 0x62
#define C_CM_RXNNDT 0x63
#define C_CM_TXFEMPTY 0x64
#define C_CM_ICHAR 0x65
#define C_CM_MDCD 0x70
#define C_CM_MDSR 0x71
#define C_CM_MRI 0x72
#define C_CM_MCTS 0x73
#define C_CM_MRTS 0x74
#define C_CM_RXBRK 0x84
#define C_CM_PR_ERROR 0x85
#define C_CM_FR_ERROR 0x86
#define C_CM_OVR_ERROR 0x87
#define C_CM_RXOFL 0x88
#define C_CM_CMDERROR 0x90
#define C_CM_FATAL 0x91
#define C_CM_HW_RESET 0x92
struct CH_CTRL {
  __u32 op_mode;
  __u32 intr_enable;
  __u32 sw_flow;
  __u32 flow_status;
  __u32 comm_baud;
  __u32 comm_parity;
  __u32 comm_data_l;
  __u32 comm_flags;
  __u32 hw_flow;
  __u32 rs_control;
  __u32 rs_status;
  __u32 flow_xon;
  __u32 flow_xoff;
  __u32 hw_overflow;
  __u32 sw_overflow;
  __u32 comm_error;
  __u32 ichar;
  __u32 filler[7];
};
struct BUF_CTRL {
  __u32 flag_dma;
  __u32 tx_bufaddr;
  __u32 tx_bufsize;
  __u32 tx_threshold;
  __u32 tx_get;
  __u32 tx_put;
  __u32 rx_bufaddr;
  __u32 rx_bufsize;
  __u32 rx_threshold;
  __u32 rx_get;
  __u32 rx_put;
  __u32 filler[5];
};
struct BOARD_CTRL {
  __u32 n_channel;
  __u32 fw_version;
  __u32 op_system;
  __u32 dr_version;
  __u32 inactivity;
  __u32 hcmd_channel;
  __u32 hcmd_param;
  __u32 fwcmd_channel;
  __u32 fwcmd_param;
  __u32 zf_int_queue_addr;
  __u32 filler[6];
};
#define QUEUE_SIZE (10 * MAX_CHAN)
struct INT_QUEUE {
  unsigned char intr_code[QUEUE_SIZE];
  unsigned long channel[QUEUE_SIZE];
  unsigned long param[QUEUE_SIZE];
  unsigned long put;
  unsigned long get;
};
struct ZFW_CTRL {
  struct BOARD_CTRL board_ctrl;
  struct CH_CTRL ch_ctrl[MAX_CHAN];
  struct BUF_CTRL buf_ctrl[MAX_CHAN];
};
#endif
#endif