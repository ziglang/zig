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
#ifndef _UAPI_PARPORT_H_
#define _UAPI_PARPORT_H_
#define PARPORT_MAX 16
#define PARPORT_IRQ_NONE - 1
#define PARPORT_DMA_NONE - 1
#define PARPORT_IRQ_AUTO - 2
#define PARPORT_DMA_AUTO - 2
#define PARPORT_DMA_NOFIFO - 3
#define PARPORT_DISABLE - 2
#define PARPORT_IRQ_PROBEONLY - 3
#define PARPORT_IOHI_AUTO - 1
#define PARPORT_CONTROL_STROBE 0x1
#define PARPORT_CONTROL_AUTOFD 0x2
#define PARPORT_CONTROL_INIT 0x4
#define PARPORT_CONTROL_SELECT 0x8
#define PARPORT_STATUS_ERROR 0x8
#define PARPORT_STATUS_SELECT 0x10
#define PARPORT_STATUS_PAPEROUT 0x20
#define PARPORT_STATUS_ACK 0x40
#define PARPORT_STATUS_BUSY 0x80
typedef enum {
  PARPORT_CLASS_LEGACY = 0,
  PARPORT_CLASS_PRINTER,
  PARPORT_CLASS_MODEM,
  PARPORT_CLASS_NET,
  PARPORT_CLASS_HDC,
  PARPORT_CLASS_PCMCIA,
  PARPORT_CLASS_MEDIA,
  PARPORT_CLASS_FDC,
  PARPORT_CLASS_PORTS,
  PARPORT_CLASS_SCANNER,
  PARPORT_CLASS_DIGCAM,
  PARPORT_CLASS_OTHER,
  PARPORT_CLASS_UNSPEC,
  PARPORT_CLASS_SCSIADAPTER
} parport_device_class;
#define PARPORT_MODE_PCSPP (1 << 0)
#define PARPORT_MODE_TRISTATE (1 << 1)
#define PARPORT_MODE_EPP (1 << 2)
#define PARPORT_MODE_ECP (1 << 3)
#define PARPORT_MODE_COMPAT (1 << 4)
#define PARPORT_MODE_DMA (1 << 5)
#define PARPORT_MODE_SAFEININT (1 << 6)
#define IEEE1284_MODE_NIBBLE 0
#define IEEE1284_MODE_BYTE (1 << 0)
#define IEEE1284_MODE_COMPAT (1 << 8)
#define IEEE1284_MODE_BECP (1 << 9)
#define IEEE1284_MODE_ECP (1 << 4)
#define IEEE1284_MODE_ECPRLE (IEEE1284_MODE_ECP | (1 << 5))
#define IEEE1284_MODE_ECPSWE (1 << 10)
#define IEEE1284_MODE_EPP (1 << 6)
#define IEEE1284_MODE_EPPSL (1 << 11)
#define IEEE1284_MODE_EPPSWE (1 << 12)
#define IEEE1284_DEVICEID (1 << 2)
#define IEEE1284_EXT_LINK (1 << 14)
#define IEEE1284_ADDR (1 << 13)
#define IEEE1284_DATA 0
#define PARPORT_EPP_FAST (1 << 0)
#define PARPORT_W91284PIC (1 << 1)
#endif