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
#ifndef _UAPISDLA_H
#define _UAPISDLA_H
#define SDLA_TYPES
#define SDLA_S502A 5020
#define SDLA_S502E 5021
#define SDLA_S503 5030
#define SDLA_S507 5070
#define SDLA_S508 5080
#define SDLA_S509 5090
#define SDLA_UNKNOWN - 1
#define SDLA_S508_PORT_V35 0x00
#define SDLA_S508_PORT_RS232 0x02
#define SDLA_CPU_3M 0x00
#define SDLA_CPU_5M 0x01
#define SDLA_CPU_7M 0x02
#define SDLA_CPU_8M 0x03
#define SDLA_CPU_10M 0x04
#define SDLA_CPU_16M 0x05
#define SDLA_CPU_12M 0x06
#define SDLA_IDENTIFY (FRAD_LAST_IOCTL + 1)
#define SDLA_CPUSPEED (FRAD_LAST_IOCTL + 2)
#define SDLA_PROTOCOL (FRAD_LAST_IOCTL + 3)
#define SDLA_CLEARMEM (FRAD_LAST_IOCTL + 4)
#define SDLA_WRITEMEM (FRAD_LAST_IOCTL + 5)
#define SDLA_READMEM (FRAD_LAST_IOCTL + 6)
struct sdla_mem {
  int addr;
  int len;
  void __user * data;
};
#define SDLA_START (FRAD_LAST_IOCTL + 7)
#define SDLA_STOP (FRAD_LAST_IOCTL + 8)
#define SDLA_NMIADDR 0x0000
#define SDLA_CONF_ADDR 0x0010
#define SDLA_S502A_NMIADDR 0x0066
#define SDLA_CODE_BASEADDR 0x0100
#define SDLA_WINDOW_SIZE 0x2000
#define SDLA_ADDR_MASK 0x1FFF
#define SDLA_MAX_DATA 4080
#define SDLA_MAX_MTU 4072
#define SDLA_MAX_DLCI 24
struct sdla_conf {
  short station;
  short config;
  short kbaud;
  short clocking;
  short max_frm;
  short T391;
  short T392;
  short N391;
  short N392;
  short N393;
  short CIR_fwd;
  short Bc_fwd;
  short Be_fwd;
  short CIR_bwd;
  short Bc_bwd;
  short Be_bwd;
};
struct sdla_dlci_conf {
  short config;
  short CIR_fwd;
  short Bc_fwd;
  short Be_fwd;
  short CIR_bwd;
  short Bc_bwd;
  short Be_bwd;
  short Tc_fwd;
  short Tc_bwd;
  short Tf_max;
  short Tb_max;
};
#endif