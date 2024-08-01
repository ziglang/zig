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
#ifndef _LINUX_FIREWIRE_CONSTANTS_H
#define _LINUX_FIREWIRE_CONSTANTS_H
#define TCODE_WRITE_QUADLET_REQUEST 0x0
#define TCODE_WRITE_BLOCK_REQUEST 0x1
#define TCODE_WRITE_RESPONSE 0x2
#define TCODE_READ_QUADLET_REQUEST 0x4
#define TCODE_READ_BLOCK_REQUEST 0x5
#define TCODE_READ_QUADLET_RESPONSE 0x6
#define TCODE_READ_BLOCK_RESPONSE 0x7
#define TCODE_CYCLE_START 0x8
#define TCODE_LOCK_REQUEST 0x9
#define TCODE_STREAM_DATA 0xa
#define TCODE_LOCK_RESPONSE 0xb
#define EXTCODE_MASK_SWAP 0x1
#define EXTCODE_COMPARE_SWAP 0x2
#define EXTCODE_FETCH_ADD 0x3
#define EXTCODE_LITTLE_ADD 0x4
#define EXTCODE_BOUNDED_ADD 0x5
#define EXTCODE_WRAP_ADD 0x6
#define EXTCODE_VENDOR_DEPENDENT 0x7
#define TCODE_LOCK_MASK_SWAP (0x10 | EXTCODE_MASK_SWAP)
#define TCODE_LOCK_COMPARE_SWAP (0x10 | EXTCODE_COMPARE_SWAP)
#define TCODE_LOCK_FETCH_ADD (0x10 | EXTCODE_FETCH_ADD)
#define TCODE_LOCK_LITTLE_ADD (0x10 | EXTCODE_LITTLE_ADD)
#define TCODE_LOCK_BOUNDED_ADD (0x10 | EXTCODE_BOUNDED_ADD)
#define TCODE_LOCK_WRAP_ADD (0x10 | EXTCODE_WRAP_ADD)
#define TCODE_LOCK_VENDOR_DEPENDENT (0x10 | EXTCODE_VENDOR_DEPENDENT)
#define RCODE_COMPLETE 0x0
#define RCODE_CONFLICT_ERROR 0x4
#define RCODE_DATA_ERROR 0x5
#define RCODE_TYPE_ERROR 0x6
#define RCODE_ADDRESS_ERROR 0x7
#define RCODE_SEND_ERROR 0x10
#define RCODE_CANCELLED 0x11
#define RCODE_BUSY 0x12
#define RCODE_GENERATION 0x13
#define RCODE_NO_ACK 0x14
#define SCODE_100 0x0
#define SCODE_200 0x1
#define SCODE_400 0x2
#define SCODE_800 0x3
#define SCODE_1600 0x4
#define SCODE_3200 0x5
#define SCODE_BETA 0x3
#define ACK_COMPLETE 0x1
#define ACK_PENDING 0x2
#define ACK_BUSY_X 0x4
#define ACK_BUSY_A 0x5
#define ACK_BUSY_B 0x6
#define ACK_DATA_ERROR 0xd
#define ACK_TYPE_ERROR 0xe
#define RETRY_1 0x00
#define RETRY_X 0x01
#define RETRY_A 0x02
#define RETRY_B 0x03
#endif