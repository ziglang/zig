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
#ifndef X25_KERNEL_H
#define X25_KERNEL_H
#include <linux/types.h>
#include <linux/socket.h>
#define SIOCX25GSUBSCRIP (SIOCPROTOPRIVATE + 0)
#define SIOCX25SSUBSCRIP (SIOCPROTOPRIVATE + 1)
#define SIOCX25GFACILITIES (SIOCPROTOPRIVATE + 2)
#define SIOCX25SFACILITIES (SIOCPROTOPRIVATE + 3)
#define SIOCX25GCALLUSERDATA (SIOCPROTOPRIVATE + 4)
#define SIOCX25SCALLUSERDATA (SIOCPROTOPRIVATE + 5)
#define SIOCX25GCAUSEDIAG (SIOCPROTOPRIVATE + 6)
#define SIOCX25SCUDMATCHLEN (SIOCPROTOPRIVATE + 7)
#define SIOCX25CALLACCPTAPPRV (SIOCPROTOPRIVATE + 8)
#define SIOCX25SENDCALLACCPT (SIOCPROTOPRIVATE + 9)
#define SIOCX25GDTEFACILITIES (SIOCPROTOPRIVATE + 10)
#define SIOCX25SDTEFACILITIES (SIOCPROTOPRIVATE + 11)
#define SIOCX25SCAUSEDIAG (SIOCPROTOPRIVATE + 12)
#define X25_QBITINCL 1
#define X25_PS16 4
#define X25_PS32 5
#define X25_PS64 6
#define X25_PS128 7
#define X25_PS256 8
#define X25_PS512 9
#define X25_PS1024 10
#define X25_PS2048 11
#define X25_PS4096 12
struct x25_address {
  char x25_addr[16];
};
struct sockaddr_x25 {
  __kernel_sa_family_t sx25_family;
  struct x25_address sx25_addr;
};
struct x25_subscrip_struct {
  char device[200 - sizeof(unsigned long)];
  unsigned long global_facil_mask;
  unsigned int extended;
};
#define X25_MASK_REVERSE 0x01
#define X25_MASK_THROUGHPUT 0x02
#define X25_MASK_PACKET_SIZE 0x04
#define X25_MASK_WINDOW_SIZE 0x08
#define X25_MASK_CALLING_AE 0x10
#define X25_MASK_CALLED_AE 0x20
struct x25_route_struct {
  struct x25_address address;
  unsigned int sigdigits;
  char device[200];
};
struct x25_facilities {
  unsigned int winsize_in, winsize_out;
  unsigned int pacsize_in, pacsize_out;
  unsigned int throughput;
  unsigned int reverse;
};
struct x25_dte_facilities {
  __u16 delay_cumul;
  __u16 delay_target;
  __u16 delay_max;
  __u8 min_throughput;
  __u8 expedited;
  __u8 calling_len;
  __u8 called_len;
  __u8 calling_ae[20];
  __u8 called_ae[20];
};
struct x25_calluserdata {
  unsigned int cudlength;
  unsigned char cuddata[128];
};
struct x25_causediag {
  unsigned char cause;
  unsigned char diagnostic;
};
struct x25_subaddr {
  unsigned int cudmatchlength;
};
#endif