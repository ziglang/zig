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
#ifndef _LINUX_SERIAL_REG_H
#define _LINUX_SERIAL_REG_H
#define UART_RX 0
#define UART_TX 0
#define UART_IER 1
#define UART_IER_MSI 0x08
#define UART_IER_RLSI 0x04
#define UART_IER_THRI 0x02
#define UART_IER_RDI 0x01
#define UART_IERX_SLEEP 0x10
#define UART_IIR 2
#define UART_IIR_NO_INT 0x01
#define UART_IIR_ID 0x0e
#define UART_IIR_MSI 0x00
#define UART_IIR_THRI 0x02
#define UART_IIR_RDI 0x04
#define UART_IIR_RLSI 0x06
#define UART_IIR_BUSY 0x07
#define UART_IIR_RX_TIMEOUT 0x0c
#define UART_IIR_XOFF 0x10
#define UART_IIR_CTS_RTS_DSR 0x20
#define UART_FCR 2
#define UART_FCR_ENABLE_FIFO 0x01
#define UART_FCR_CLEAR_RCVR 0x02
#define UART_FCR_CLEAR_XMIT 0x04
#define UART_FCR_DMA_SELECT 0x08
#define UART_FCR_R_TRIG_00 0x00
#define UART_FCR_R_TRIG_01 0x40
#define UART_FCR_R_TRIG_10 0x80
#define UART_FCR_R_TRIG_11 0xc0
#define UART_FCR_T_TRIG_00 0x00
#define UART_FCR_T_TRIG_01 0x10
#define UART_FCR_T_TRIG_10 0x20
#define UART_FCR_T_TRIG_11 0x30
#define UART_FCR_TRIGGER_MASK 0xC0
#define UART_FCR_TRIGGER_1 0x00
#define UART_FCR_TRIGGER_4 0x40
#define UART_FCR_TRIGGER_8 0x80
#define UART_FCR_TRIGGER_14 0xC0
#define UART_FCR6_R_TRIGGER_8 0x00
#define UART_FCR6_R_TRIGGER_16 0x40
#define UART_FCR6_R_TRIGGER_24 0x80
#define UART_FCR6_R_TRIGGER_28 0xC0
#define UART_FCR6_T_TRIGGER_16 0x00
#define UART_FCR6_T_TRIGGER_8 0x10
#define UART_FCR6_T_TRIGGER_24 0x20
#define UART_FCR6_T_TRIGGER_30 0x30
#define UART_FCR7_64BYTE 0x20
#define UART_FCR_R_TRIG_SHIFT 6
#define UART_FCR_R_TRIG_BITS(x) (((x) & UART_FCR_TRIGGER_MASK) >> UART_FCR_R_TRIG_SHIFT)
#define UART_FCR_R_TRIG_MAX_STATE 4
#define UART_LCR 3
#define UART_LCR_DLAB 0x80
#define UART_LCR_SBC 0x40
#define UART_LCR_SPAR 0x20
#define UART_LCR_EPAR 0x10
#define UART_LCR_PARITY 0x08
#define UART_LCR_STOP 0x04
#define UART_LCR_WLEN5 0x00
#define UART_LCR_WLEN6 0x01
#define UART_LCR_WLEN7 0x02
#define UART_LCR_WLEN8 0x03
#define UART_LCR_CONF_MODE_A UART_LCR_DLAB
#define UART_LCR_CONF_MODE_B 0xBF
#define UART_MCR 4
#define UART_MCR_CLKSEL 0x80
#define UART_MCR_TCRTLR 0x40
#define UART_MCR_XONANY 0x20
#define UART_MCR_AFE 0x20
#define UART_MCR_LOOP 0x10
#define UART_MCR_OUT2 0x08
#define UART_MCR_OUT1 0x04
#define UART_MCR_RTS 0x02
#define UART_MCR_DTR 0x01
#define UART_LSR 5
#define UART_LSR_FIFOE 0x80
#define UART_LSR_TEMT 0x40
#define UART_LSR_THRE 0x20
#define UART_LSR_BI 0x10
#define UART_LSR_FE 0x08
#define UART_LSR_PE 0x04
#define UART_LSR_OE 0x02
#define UART_LSR_DR 0x01
#define UART_LSR_BRK_ERROR_BITS 0x1E
#define UART_MSR 6
#define UART_MSR_DCD 0x80
#define UART_MSR_RI 0x40
#define UART_MSR_DSR 0x20
#define UART_MSR_CTS 0x10
#define UART_MSR_DDCD 0x08
#define UART_MSR_TERI 0x04
#define UART_MSR_DDSR 0x02
#define UART_MSR_DCTS 0x01
#define UART_MSR_ANY_DELTA 0x0F
#define UART_SCR 7
#define UART_DLL 0
#define UART_DLM 1
#define UART_DIV_MAX 0xFFFF
#define UART_EFR 2
#define UART_XR_EFR 9
#define UART_EFR_CTS 0x80
#define UART_EFR_RTS 0x40
#define UART_EFR_SCD 0x20
#define UART_EFR_ECB 0x10
#define UART_XON1 4
#define UART_XON2 5
#define UART_XOFF1 6
#define UART_XOFF2 7
#define UART_TI752_TCR 6
#define UART_TI752_TLR 7
#define UART_TRG 0
#define UART_TRG_1 0x01
#define UART_TRG_4 0x04
#define UART_TRG_8 0x08
#define UART_TRG_16 0x10
#define UART_TRG_32 0x20
#define UART_TRG_64 0x40
#define UART_TRG_96 0x60
#define UART_TRG_120 0x78
#define UART_TRG_128 0x80
#define UART_FCTR 1
#define UART_FCTR_RTS_NODELAY 0x00
#define UART_FCTR_RTS_4DELAY 0x01
#define UART_FCTR_RTS_6DELAY 0x02
#define UART_FCTR_RTS_8DELAY 0x03
#define UART_FCTR_IRDA 0x04
#define UART_FCTR_TX_INT 0x08
#define UART_FCTR_TRGA 0x00
#define UART_FCTR_TRGB 0x10
#define UART_FCTR_TRGC 0x20
#define UART_FCTR_TRGD 0x30
#define UART_FCTR_SCR_SWAP 0x40
#define UART_FCTR_RX 0x00
#define UART_FCTR_TX 0x80
#define UART_EMSR 7
#define UART_EMSR_FIFO_COUNT 0x01
#define UART_EMSR_ALT_COUNT 0x02
#define UART_IER_DMAE 0x80
#define UART_IER_UUE 0x40
#define UART_IER_NRZE 0x20
#define UART_IER_RTOIE 0x10
#define UART_IIR_TOD 0x08
#define UART_FCR_PXAR1 0x00
#define UART_FCR_PXAR8 0x40
#define UART_FCR_PXAR16 0x80
#define UART_FCR_PXAR32 0xc0
#define UART_ASR 0x01
#define UART_RFL 0x03
#define UART_TFL 0x04
#define UART_ICR 0x05
#define UART_ACR 0x00
#define UART_CPR 0x01
#define UART_TCR 0x02
#define UART_CKS 0x03
#define UART_TTL 0x04
#define UART_RTL 0x05
#define UART_FCL 0x06
#define UART_FCH 0x07
#define UART_ID1 0x08
#define UART_ID2 0x09
#define UART_ID3 0x0A
#define UART_REV 0x0B
#define UART_CSR 0x0C
#define UART_NMR 0x0D
#define UART_CTR 0xFF
#define UART_ACR_RXDIS 0x01
#define UART_ACR_TXDIS 0x02
#define UART_ACR_DSRFC 0x04
#define UART_ACR_TLENB 0x20
#define UART_ACR_ICRRD 0x40
#define UART_ACR_ASREN 0x80
#define UART_RSA_BASE (- 8)
#define UART_RSA_MSR ((UART_RSA_BASE) + 0)
#define UART_RSA_MSR_SWAP (1 << 0)
#define UART_RSA_MSR_FIFO (1 << 2)
#define UART_RSA_MSR_FLOW (1 << 3)
#define UART_RSA_MSR_ITYP (1 << 4)
#define UART_RSA_IER ((UART_RSA_BASE) + 1)
#define UART_RSA_IER_Rx_FIFO_H (1 << 0)
#define UART_RSA_IER_Tx_FIFO_H (1 << 1)
#define UART_RSA_IER_Tx_FIFO_E (1 << 2)
#define UART_RSA_IER_Rx_TOUT (1 << 3)
#define UART_RSA_IER_TIMER (1 << 4)
#define UART_RSA_SRR ((UART_RSA_BASE) + 2)
#define UART_RSA_SRR_Tx_FIFO_NEMP (1 << 0)
#define UART_RSA_SRR_Tx_FIFO_NHFL (1 << 1)
#define UART_RSA_SRR_Tx_FIFO_NFUL (1 << 2)
#define UART_RSA_SRR_Rx_FIFO_NEMP (1 << 3)
#define UART_RSA_SRR_Rx_FIFO_NHFL (1 << 4)
#define UART_RSA_SRR_Rx_FIFO_NFUL (1 << 5)
#define UART_RSA_SRR_Rx_TOUT (1 << 6)
#define UART_RSA_SRR_TIMER (1 << 7)
#define UART_RSA_FRR ((UART_RSA_BASE) + 2)
#define UART_RSA_TIVSR ((UART_RSA_BASE) + 3)
#define UART_RSA_TCR ((UART_RSA_BASE) + 4)
#define UART_RSA_TCR_SWITCH (1 << 0)
#define SERIAL_RSA_BAUD_BASE (921600)
#define SERIAL_RSA_BAUD_BASE_LO (SERIAL_RSA_BAUD_BASE / 8)
#define UART_DA830_PWREMU_MGMT 12
#define UART_DA830_PWREMU_MGMT_FREE (1 << 0)
#define UART_DA830_PWREMU_MGMT_URRST (1 << 13)
#define UART_DA830_PWREMU_MGMT_UTRST (1 << 14)
#define OMAP1_UART1_BASE 0xfffb0000
#define OMAP1_UART2_BASE 0xfffb0800
#define OMAP1_UART3_BASE 0xfffb9800
#define UART_OMAP_MDR1 0x08
#define UART_OMAP_MDR2 0x09
#define UART_OMAP_SCR 0x10
#define UART_OMAP_SSR 0x11
#define UART_OMAP_EBLR 0x12
#define UART_OMAP_OSC_12M_SEL 0x13
#define UART_OMAP_MVER 0x14
#define UART_OMAP_SYSC 0x15
#define UART_OMAP_SYSS 0x16
#define UART_OMAP_WER 0x17
#define UART_OMAP_TX_LVL 0x1a
#define UART_OMAP_MDR1_16X_MODE 0x00
#define UART_OMAP_MDR1_SIR_MODE 0x01
#define UART_OMAP_MDR1_16X_ABAUD_MODE 0x02
#define UART_OMAP_MDR1_13X_MODE 0x03
#define UART_OMAP_MDR1_MIR_MODE 0x04
#define UART_OMAP_MDR1_FIR_MODE 0x05
#define UART_OMAP_MDR1_CIR_MODE 0x06
#define UART_OMAP_MDR1_DISABLE 0x07
#define UART_ALTR_AFR 0x40
#define UART_ALTR_EN_TXFIFO_LW 0x01
#define UART_ALTR_TX_LOW 0x41
#endif