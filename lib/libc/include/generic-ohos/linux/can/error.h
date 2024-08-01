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
#ifndef _UAPI_CAN_ERROR_H
#define _UAPI_CAN_ERROR_H
#define CAN_ERR_DLC 8
#define CAN_ERR_TX_TIMEOUT 0x00000001U
#define CAN_ERR_LOSTARB 0x00000002U
#define CAN_ERR_CRTL 0x00000004U
#define CAN_ERR_PROT 0x00000008U
#define CAN_ERR_TRX 0x00000010U
#define CAN_ERR_ACK 0x00000020U
#define CAN_ERR_BUSOFF 0x00000040U
#define CAN_ERR_BUSERROR 0x00000080U
#define CAN_ERR_RESTARTED 0x00000100U
#define CAN_ERR_LOSTARB_UNSPEC 0x00
#define CAN_ERR_CRTL_UNSPEC 0x00
#define CAN_ERR_CRTL_RX_OVERFLOW 0x01
#define CAN_ERR_CRTL_TX_OVERFLOW 0x02
#define CAN_ERR_CRTL_RX_WARNING 0x04
#define CAN_ERR_CRTL_TX_WARNING 0x08
#define CAN_ERR_CRTL_RX_PASSIVE 0x10
#define CAN_ERR_CRTL_TX_PASSIVE 0x20
#define CAN_ERR_CRTL_ACTIVE 0x40
#define CAN_ERR_PROT_UNSPEC 0x00
#define CAN_ERR_PROT_BIT 0x01
#define CAN_ERR_PROT_FORM 0x02
#define CAN_ERR_PROT_STUFF 0x04
#define CAN_ERR_PROT_BIT0 0x08
#define CAN_ERR_PROT_BIT1 0x10
#define CAN_ERR_PROT_OVERLOAD 0x20
#define CAN_ERR_PROT_ACTIVE 0x40
#define CAN_ERR_PROT_TX 0x80
#define CAN_ERR_PROT_LOC_UNSPEC 0x00
#define CAN_ERR_PROT_LOC_SOF 0x03
#define CAN_ERR_PROT_LOC_ID28_21 0x02
#define CAN_ERR_PROT_LOC_ID20_18 0x06
#define CAN_ERR_PROT_LOC_SRTR 0x04
#define CAN_ERR_PROT_LOC_IDE 0x05
#define CAN_ERR_PROT_LOC_ID17_13 0x07
#define CAN_ERR_PROT_LOC_ID12_05 0x0F
#define CAN_ERR_PROT_LOC_ID04_00 0x0E
#define CAN_ERR_PROT_LOC_RTR 0x0C
#define CAN_ERR_PROT_LOC_RES1 0x0D
#define CAN_ERR_PROT_LOC_RES0 0x09
#define CAN_ERR_PROT_LOC_DLC 0x0B
#define CAN_ERR_PROT_LOC_DATA 0x0A
#define CAN_ERR_PROT_LOC_CRC_SEQ 0x08
#define CAN_ERR_PROT_LOC_CRC_DEL 0x18
#define CAN_ERR_PROT_LOC_ACK 0x19
#define CAN_ERR_PROT_LOC_ACK_DEL 0x1B
#define CAN_ERR_PROT_LOC_EOF 0x1A
#define CAN_ERR_PROT_LOC_INTERM 0x12
#define CAN_ERR_TRX_UNSPEC 0x00
#define CAN_ERR_TRX_CANH_NO_WIRE 0x04
#define CAN_ERR_TRX_CANH_SHORT_TO_BAT 0x05
#define CAN_ERR_TRX_CANH_SHORT_TO_VCC 0x06
#define CAN_ERR_TRX_CANH_SHORT_TO_GND 0x07
#define CAN_ERR_TRX_CANL_NO_WIRE 0x40
#define CAN_ERR_TRX_CANL_SHORT_TO_BAT 0x50
#define CAN_ERR_TRX_CANL_SHORT_TO_VCC 0x60
#define CAN_ERR_TRX_CANL_SHORT_TO_GND 0x70
#define CAN_ERR_TRX_CANL_SHORT_TO_CANH 0x80
#endif