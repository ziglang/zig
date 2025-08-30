/* $NetBSD: hdaudioreg.h,v 1.4 2022/03/21 09:12:10 jmcneill Exp $ */

/*
 * Copyright (c) 2009 Precedence Technologies Ltd <support@precedence.co.uk>
 * Copyright (c) 2009 Jared D. McNeill <jmcneill@invisible.ca>
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Precedence Technologies Ltd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _HDAUDIOREG_H
#define _HDAUDIOREG_H

#include <sys/cdefs.h>
#include <sys/types.h>

/*
 * High Definition Audio Memory Mapped Configuration Registers
 */
#define	HDAUDIO_MMIO_GCAP	0x000
#define	 HDAUDIO_GCAP_64OK(x)		((x) & 1)
#define	 HDAUDIO_GCAP_NSDO(x)		((((x) & 6) != 0) ? ((x) & 6) : 1)
#define	 HDAUDIO_GCAP_BSS(x)		(((x) >>  3) & 0x1f)
#define	 HDAUDIO_GCAP_ISS(x)		(((x) >>  8) & 0x0f)
#define	 HDAUDIO_GCAP_OSS(x)		(((x) >> 12) & 0x0f)
#define	HDAUDIO_MMIO_VMIN	0x002
#define	HDAUDIO_MMIO_VMAJ	0x003
#define	HDAUDIO_MMIO_OUTPAY	0x004
#define	HDAUDIO_MMIO_INPAY	0x006
#define	HDAUDIO_MMIO_GCTL	0x008
#define	 HDAUDIO_GCTL_UNSOL_EN		(1 << 8)
#define	 HDAUDIO_GCTL_FLUSH_CTL		(1 << 1)
#define	 HDAUDIO_GCTL_CRST		(1 << 0)
#define	HDAUDIO_MMIO_WAKEEN	0x00c
#define	HDAUDIO_MMIO_STATESTS	0x00e
#define	 HDAUDIO_STATESTS_SDIWAKE	0x7fff
#define	HDAUDIO_MMIO_GSTS	0x010
#define	HDAUDIO_MMIO_INTCTL	0x020
#define	 HDAUDIO_INTCTL_GIE		(1u << 31)
#define	 HDAUDIO_INTCTL_CIE		(1 << 30)
#define	HDAUDIO_MMIO_INTSTS	0x024
#define	 HDAUDIO_INTSTS_GIS		(1u << 31)
#define	 HDAUDIO_INTSTS_CIS		(1 << 30)
#define	 HDAUDIO_INTSTS_SIS_MASK	0x3fffffff
#define	HDAUDIO_MMIO_WALCLK	0x030
#define	HDAUDIO_MMIO_SYNC	0x034
#define	HDAUDIO_MMIO_CORBLBASE	0x040
#define	HDAUDIO_MMIO_CORBUBASE	0x044
#define	HDAUDIO_MMIO_CORBWP	0x048
#define	HDAUDIO_MMIO_CORBRP	0x04a
#define	 HDAUDIO_CORBRP_RP_RESET	(1 << 15)
#define	HDAUDIO_MMIO_CORBCTL	0x04c
#define	 HDAUDIO_CORBCTL_RUN		(1 << 1)
#define	 HDAUDIO_CORBCTL_CMEI_EN	(1 << 0)
#define	HDAUDIO_MMIO_CORBST	0x04d
#define	HDAUDIO_MMIO_CORBSIZE	0x04e
#define	HDAUDIO_MMIO_RIRBLBASE	0x050
#define	HDAUDIO_MMIO_RIRBUBASE	0x054
#define	HDAUDIO_MMIO_RIRBWP	0x058
#define	 HDAUDIO_RIRBWP_WP_RESET	(1 << 15)
#define	HDAUDIO_MMIO_RINTCNT	0x05a
#define	HDAUDIO_MMIO_RIRBCTL	0x05c
#define	 HDAUDIO_RIRBCTL_ROI_EN		(1 << 2)
#define	 HDAUDIO_RIRBCTL_RUN		(1 << 1)
#define	 HDAUDIO_RIRBCTL_INT_EN		(1 << 0)
#define	HDAUDIO_MMIO_RIRBSTS	0x05d
#define	 HDAUDIO_RIRBSTS_RIRBOIS	(1 << 2)
#define	 HDAUDIO_RIRBSTS_RINTFL		(1 << 0)
#define	HDAUDIO_MMIO_RIRBSIZE	0x05e
#define	HDAUDIO_MMIO_IC		0x060
#define	HDAUDIO_MMIO_IR		0x064
#define	HDAUDIO_MMIO_IRS	0x068
#define	HDAUDIO_MMIO_DPLBASE	0x070
#define	HDAUDIO_MMIO_DPUBASE	0x074

#define	HDAUDIO_MMIO_SD_SIZE	0x20
#define	HDAUDIO_MMIO_SD_BASE	0x080

#define	HDAUDIO_SD_REG(off, x)	\
	(HDAUDIO_MMIO_SD_BASE + ((x) * HDAUDIO_MMIO_SD_SIZE) + (off))
#define	HDAUDIO_SD_CTL0(x)	HDAUDIO_SD_REG(0x00, x)
#define	 HDAUDIO_CTL_SRST	 (1 << 0)
#define	 HDAUDIO_CTL_RUN	 (1 << 1)
#define	 HDAUDIO_CTL_IOCE	 (1 << 2)
#define	 HDAUDIO_CTL_FEIE	 (1 << 3)
#define	 HDAUDIO_CTL_DEIE	 (1 << 4)
#define	HDAUDIO_SD_CTL1(x)	HDAUDIO_SD_REG(0x01, x)
#define	HDAUDIO_SD_CTL2(x)	HDAUDIO_SD_REG(0x02, x)
#define	HDAUDIO_SD_STS(x)	HDAUDIO_SD_REG(0x03, x)
#define  HDAUDIO_STS_FIFORDY	 (1 << 5)
#define	 HDAUDIO_STS_DESE	 (1 << 4)
#define	 HDAUDIO_STS_FIFOE	 (1 << 3)
#define	 HDAUDIO_STS_BCIS	 (1 << 2)
#define	HDAUDIO_SD_LPIB(x)	HDAUDIO_SD_REG(0x04, x)
#define	HDAUDIO_SD_CBL(x)	HDAUDIO_SD_REG(0x08, x)
#define	HDAUDIO_SD_LVI(x)	HDAUDIO_SD_REG(0x0c, x)
#define	HDAUDIO_SD_FIFOW(x) 	HDAUDIO_SD_REG(0x0e, x)
#define	HDAUDIO_SD_FIFOS(x) 	HDAUDIO_SD_REG(0x10, x)
#define	HDAUDIO_SD_FMT(x)	HDAUDIO_SD_REG(0x12, x)
#define	 HDAUDIO_FMT_TYPE_MASK	 0x8000
#define	  HDAUDIO_FMT_TYPE_PCM	  0x0000
#define	  HDAUDIO_FMT_TYPE_NONPCM 0x8000
#define	 HDAUDIO_FMT_BASE_MASK	 0x4000
#define	  HDAUDIO_FMT_BASE_48	  0x0000
#define	  HDAUDIO_FMT_BASE_44	  0x4000
#define	 HDAUDIO_FMT_MULT_MASK	 0x3800
#define	  HDAUDIO_FMT_MULT(x)	  ((((x) - 1) << 11) & HDAUDIO_FMT_MULT_MASK)
#define	 HDAUDIO_FMT_DIV_MASK	 0x0700
#define	  HDAUDIO_FMT_DIV(x)	  ((((x) - 1) << 8) & HDAUDIO_FMT_DIV_MASK)
#define	 HDAUDIO_FMT_BITS_MASK	 0x0070
#define	  HDAUDIO_FMT_BITS_8_16	  (0 << 4)
#define	  HDAUDIO_FMT_BITS_16_16  (1 << 4)
#define	  HDAUDIO_FMT_BITS_20_32  (2 << 4)
#define	  HDAUDIO_FMT_BITS_24_32  (3 << 4)
#define	  HDAUDIO_FMT_BITS_32_32  (4 << 4)
#define	 HDAUDIO_FMT_CHAN_MASK	 0x000f
#define	  HDAUDIO_FMT_CHAN(x)	  (((x) - 1) & HDAUDIO_FMT_CHAN_MASK)
#define	HDAUDIO_SD_BDPL(x)	HDAUDIO_SD_REG(0x18, x)
#define	HDAUDIO_SD_BDPU(x)	HDAUDIO_SD_REG(0x1c, x)

/*
 * Codec Parameters and Controls
 */
#define	CORB_GET_PARAMETER			0xf00
#define	 COP_VENDOR_ID				 0x00
#define	 COP_REVISION_ID			 0x02
#define	 COP_SUBORDINATE_NODE_COUNT		 0x04
#define	  COP_NODECNT_STARTNODE(x)		  (((x) >> 16) & 0xff)
#define	  COP_NODECNT_NUMNODES(x)		  (((x) >> 0) & 0xff)
#define	 COP_FUNCTION_GROUP_TYPE		 0x05
#define	 COP_AUDIO_FUNCTION_GROUP_CAPABILITIES	 0x08
#define	 COP_AUDIO_WIDGET_CAPABILITIES		 0x09
#define	  COP_AWCAP_CHANNEL_COUNT(x)		  \
	    (((((x) & (0x7 << 13)) >> 12) | ((x) & 0x1)) + 1)
#define	  COP_AWCAP_INAMP_PRESENT		  (1 << 1)
#define	  COP_AWCAP_OUTAMP_PRESENT		  (1 << 2)
#define	  COP_AWCAP_AMP_PARAM_OVERRIDE		  (1 << 3)
#define	  COP_AWCAP_FORMAT_OVERRIDE		  (1 << 4)
#define	  COP_AWCAP_STRIPE			  (1 << 5)
#define	  COP_AWCAP_PROC_WIDGET			  (1 << 6)
#define	  COP_AWCAP_UNSOL_CAPABLE		  (1 << 7)
#define	  COP_AWCAP_CONN_LIST			  (1 << 8)
#define	  COP_AWCAP_DIGITAL			  (1 << 9)
#define	  COP_AWCAP_POWER_CNTRL			  (1 << 10)
#define	  COP_AWCAP_LR_SWAP			  (1 << 11)
#define	  COP_AWCAP_CP_CAPS			  (1 << 12)
#define	  COP_AWCAP_CHAN_COUNT_EXT(x)		  (((x) >> 13) & 0x7)
#define	  COP_AWCAP_DELAY(x)			  (((x) >> 16) & 0xf)
#define	  COP_AWCAP_TYPE(x)			  (((x) >> 20) & 0xf)
#define	   COP_AWCAP_TYPE_MASK			   0x00f00000
#define	   COP_AWCAP_TYPE_SHIFT			   20
#define	   COP_AWCAP_TYPE_AUDIO_OUTPUT		   0x0
#define	   COP_AWCAP_TYPE_AUDIO_INPUT		   0x1
#define	   COP_AWCAP_TYPE_AUDIO_MIXER		   0x2
#define	   COP_AWCAP_TYPE_AUDIO_SELECTOR	   0x3
#define	   COP_AWCAP_TYPE_PIN_COMPLEX		   0x4
#define	   COP_AWCAP_TYPE_POWER_WIDGET		   0x5
#define	   COP_AWCAP_TYPE_VOLUME_KNOB		   0x6
#define	   COP_AWCAP_TYPE_BEEP_GENERATOR	   0x7
#define	   COP_AWCAP_TYPE_VENDOR_DEFINED	   0xf
#define	 COP_SUPPORTED_PCM_SIZE_RATES		 0x0a
#define	 COP_SUPPORTED_STREAM_FORMATS		 0x0b
#define	  COP_STREAM_FORMAT_PCM			  (1 << 0)
#define	  COP_STREAM_FORMAT_FLOAT32		  (1 << 1)
#define	  COP_STREAM_FORMAT_AC3			  (1 << 2)
#define	 COP_PIN_CAPABILITIES			 0x0c
#define	  COP_PINCAP_IMPEDANCE_SENSE_CAPABLE	  (1 << 0)
#define	  COP_PINCAP_TRIGGER_REQD		  (1 << 1)
#define	  COP_PINCAP_PRESENSE_DETECT_CAPABLE	  (1 << 2)
#define	  COP_PINCAP_HEADPHONE_DRIVE_CAPABLE	  (1 << 3)
#define	  COP_PINCAP_OUTPUT_CAPABLE		  (1 << 4)
#define	  COP_PINCAP_INPUT_CAPABLE		  (1 << 5)
#define	  COP_PINCAP_BALANCED_IO_PINS		  (1 << 6)
#define	  COP_PINCAP_HDMI			  (1 << 7)
#define	  COP_PINCAP_VREF_CONTROL(x)		  (((x) >> 8) & 0xff)
#define	   COP_VREF_HIZ				   (1 << 0)
#define	   COP_VREF_50				   (1 << 1)
#define	   COP_VREF_GROUND			   (1 << 2)
#define	   COP_VREF_80				   (1 << 4)
#define	   COP_VREF_100				   (1 << 5)
#define	  COP_PINCAP_EAPD_CAPABLE		  (1 << 16)
#define	  COP_PINCAP_DP				  (1 << 24)
#define	  COP_PINCAP_HBR			  (1 << 27)
#define	 COP_AMPLIFIER_CAPABILITIES_INAMP	 0x0d
#define	 COP_AMPLIFIER_CAPABILITIES_OUTAMP	 0x12
#define	  COP_AMPCAP_OFFSET(x)			  (((x) >> 0) & 0x7f)
#define	  COP_AMPCAP_NUM_STEPS(x)		  (((x) >> 8) & 0x7f)
#define	  COP_AMPCAP_STEP_SIZE(x)		  (((x) >> 16) & 0x7f)
#define	  COP_AMPCAP_MUTE_CAPABLE(x)		  (((x) >> 31) & 0x1)
#define	 COP_CONNECTION_LIST_LENGTH		 0x0e
#define   COP_CONNECTION_LIST_LENGTH_LEN(x)	   ((x) & 0x7f)
#define	  COP_CONNECTION_LIST_LENGTH_LONG_FORM	   (1 << 7)
#define	 COP_SUPPORTED_POWER_STATES		 0x0f
#define	 COP_PROCESSING_CAPABILITIES		 0x10
#define	 COP_GPIO_COUNT				 0x11
#define	  COP_GPIO_COUNT_NUM_GPIO(x)		  ((x) & 0xff)
#define	 COP_VOLUME_KNOB_CAPABILITIES		 0x13
#define	 COP_HDMI_LPCM_CAD			 0x20
#define	  COP_LPCM_CAD_44_1_MS			  (1u << 31)
#define	  COP_LPCM_CAD_44_1			  (1 << 30)
#define	  COP_LPCM_CAD_192K_24BIT		  (1 << 29)
#define	  COP_LPCM_CAD_192K_20BIT		  (1 << 28)
#define	  COP_LPCM_CAD_192K_MAXCHAN(x)		  (((x) >> 24) & 0xf)
#define	  COP_LPCM_CAD_192K_MAXCHAN_CP(x)	  (((x) >> 20) & 0xf)
#define	  COP_LPCM_CAD_96K_24BIT		  (1 << 19)
#define	  COP_LPCM_CAD_96K_20BIT		  (1 << 18)
#define	  COP_LPCM_CAD_96K_MAXCHAN(x)		  (((x) >> 14) & 0xf)
#define	  COP_LPCM_CAD_96K_MAXCHAN_CP(x)	  (((x) >> 10) & 0xf)
#define	  COP_LPCM_CAD_48K_24BIT		  (1 << 9)
#define	  COP_LPCM_CAD_48K_20BIT		  (1 << 8)
#define	  COP_LPCM_CAD_48K_MAXCHAN(x)		  (((x) >> 4) & 0xf)
#define	  COP_LPCM_CAD_48K_MAXCHAN_CP(x)	  (((x) >> 0) & 0xf)
#define	CORB_GET_CONNECTION_SELECT_CONTROL	0xf01
#define	CORB_SET_CONNECTION_SELECT_CONTROL	0x701
#define	CORB_GET_CONNECTION_LIST_ENTRY		0xf02
#define	CORB_GET_PROCESSING_STATE		0xf03
#define	CORB_SET_PROCESSING_STATE		0x703
#define	CORB_GET_COEFFICIENT_INDEX		0xd00
#define	CORB_SET_COEFFICIENT_INDEX		0x500
#define	CORB_GET_PROCESSING_COEFFICIENT		0xc00
#define	CORB_SET_PROCESSING_COEFFICIENT		0x400
#define	CORB_GET_AMPLIFIER_GAIN_MUTE		0xb00
#define	CORB_SET_AMPLIFIER_GAIN_MUTE		0x300
#define	CORB_GET_CONVERTER_FORMAT		0xa00
#define	CORB_SET_CONVERTER_FORMAT		0x200
#define	CORB_GET_DIGITAL_CONVERTER_CONTROL	0xf0d
#define	CORB_SET_DIGITAL_CONVERTER_CONTROL_1	0x70d
#define	 COP_DIGITAL_CONVCTRL1_DIGEN		 (1 << 0)
#define	 COP_DIGITAL_CONVCTRL1_V		 (1 << 1)
#define	 COP_DIGITAL_CONVCTRL1_VCFG		 (1 << 2)
#define	 COP_DIGITAL_CONVCTRL1_PRE		 (1 << 3)
#define	 COP_DIGITAL_CONVCTRL1_COPY		 (1 << 4)
#define	 COP_DIGITAL_CONVCTRL1_NAUDIO		 (1 << 5)
#define	 COP_DIGITAL_CONVCTRL1_PRO		 (1 << 6)
#define	 COP_DIGITAL_CONVCTRL1_L		 (1 << 7)
#define	CORB_SET_DIGITAL_CONVERTER_CONTROL_2	0x70e
#define	 COP_DIGITAL_CONVCTRL2_CC_MASK		 0x7f
#define	CORB_GET_POWER_STATE			0xf05
#define	CORB_SET_POWER_STATE			0x705
#define	 COP_POWER_STATE_D0			 0x00
#define	 COP_POWER_STATE_D1			 0x01
#define	 COP_POWER_STATE_D2			 0x02
#define	 COP_POWER_STATE_D3			 0x03
#define	CORB_GET_CONVERTER_STREAM_CHANNEL	0xf06
#define	CORB_SET_CONVERTER_STREAM_CHANNEL	0x706
#define	CORB_GET_INPUT_CONVERTER_SDI_SELECT	0xf04
#define	CORB_SET_INPUT_CONVERTER_SDI_SELECT	0x704
#define	CORB_GET_PIN_WIDGET_CONTROL		0xf07
#define	CORB_SET_PIN_WIDGET_CONTROL		0x707
#define	 COP_PWC_VREF_ENABLE_MASK		 0x7
#define	 COP_PWC_VREF_HIZ			 0x00
#define	 COP_PWC_VREF_50			 0x01
#define	 COP_PWC_VREF_GND			 0x02
#define	 COP_PWC_VREF_80			 0x04
#define	 COP_PWC_VREF_100			 0x05
#define	 COP_PWC_IN_ENABLE			 (1 << 5)
#define	 COP_PWC_OUT_ENABLE			 (1 << 6)
#define	 COP_PWC_HPHN_ENABLE			 (1 << 7)
#define	 COP_PWC_EPT_MASK			 0x3
#define	 COP_PWC_EPT_NATIVE			 0x0
#define	 COP_PWC_EPT_HIGH_BIT_RATE		 0x3
#define	CORB_GET_UNSOLICITED_RESPONSE		0xf08
#define	CORB_SET_UNSOLICITED_RESPONSE		0x708
#define	 COP_SET_UNSOLICITED_RESPONSE_ENABLE	 (1 << 7)
#define	CORB_GET_PIN_SENSE			0xf09
#define	 COP_GET_PIN_SENSE_PRESENSE_DETECT	 (1u << 31)
#define	 COP_GET_PIN_SENSE_ELD_VALID		 (1 << 30) /* digital */
#define	 COP_GET_PIN_SENSE_IMPEDENCE_SENSE(x)	 ((x) & 0x7fffffff) /* analog */
#define	CORB_SET_PIN_SENSE			0x709
#define	CORB_GET_EAPD_BTL_ENABLE		0xf0c
#define	CORB_SET_EAPD_BTL_ENABLE		0x70c
#define	 COP_EAPD_ENABLE_BTL			 (1 << 0)
#define	 COP_EAPD_ENABLE_EAPD			 (1 << 1)
#define	 COP_EAPD_ENABLE_LR_SWAP		 (1 << 2)
#define	CORB_GET_GPI_DATA			0xf10
#define	CORB_SET_GPI_DATA			0x710
#define	CORB_GET_GPI_WAKE_ENABLE_MASK		0xf11
#define	CORB_SET_GPI_WAKE_ENABLE_MASK		0x711
#define	CORB_GET_GPI_UNSOLICITED_ENABLE_MASK	0xf12
#define	CORB_SET_GPI_UNSOLICITED_ENABLE_MASK	0x712
#define	CORB_GET_GPI_STICKY_MASK		0xf13
#define	CORB_SET_GPI_STICKY_MASK		0x713
#define	CORB_GET_GPO_DATA			0xf14
#define	CORB_SET_GPO_DATA			0x714
#define	CORB_GET_GPIO_DATA			0xf15
#define	CORB_SET_GPIO_DATA			0x715
#define	CORB_GET_GPIO_ENABLE_MASK		0xf16
#define	CORB_SET_GPIO_ENABLE_MASK		0x716
#define	CORB_GET_GPIO_DIRECTION			0xf17
#define	CORB_SET_GPIO_DIRECTION			0x717
#define	CORB_GET_GPIO_WAKE_ENABLE_MASK		0xf18
#define	CORB_SET_GPIO_WAKE_ENABLE_MASK		0x718
#define	CORB_GET_GPIO_UNSOLICITED_ENABLE_MASK	0xf19
#define	CORB_SET_GPIO_UNSOLICITED_ENABLE_MASK	0x719
#define	CORB_GET_GPIO_STICKY_MASK		0xf1a
#define	CORB_SET_GPIO_STICKY_MASK		0x71a
#define	CORB_GET_BEEP_GENERATION		0xf0a
#define	CORB_SET_BEEP_GENERATION		0x70a
#define	CORB_GET_VOLUME_KNOB			0xf0f
#define	CORB_SET_VOLUME_KNOB			0x70f
#define	CORB_GET_SUBSYSTEM_ID			0xf20
#define	CORB_SET_SUBSYSTEM_ID_1			0x720
#define	CORB_SET_SUBSYSTEM_ID_2			0x721
#define	CORB_SET_SUBSYSTEM_ID_3			0x722
#define	CORB_SET_SUBSYSTEM_ID_4			0x723
#define	CORB_GET_CONFIGURATION_DEFAULT		0xf1c
#define  COP_CFG_SEQUENCE(x)			 (((x) >> 0) & 0xf)
#define  COP_CFG_DEFAULT_ASSOCIATION(x)		 (((x) >> 4) & 0xf)
#define  COP_CFG_MISC(x)			 (((x) >> 8) & 0xf)
#define  COP_CFG_COLOR(x)			 (((x) >> 12) & 0xf)
#define  COP_CFG_CONNECTION_TYPE(x)		 (((x) >> 16) & 0xf)
#define	  COP_CONN_TYPE_UNKNOWN			  0x0
#define	  COP_CONN_TYPE_18INCH			  0x1
#define	  COP_CONN_TYPE_14INCH			  0x2
#define	  COP_CONN_TYPE_ATAPI_INTERNAL		  0x3
#define	  COP_CONN_TYPE_RCA			  0x4
#define	  COP_CONN_TYPE_OPTICAL			  0x5
#define	  COP_CONN_TYPE_OTHER_DIGITAL		  0x6
#define	  COP_CONN_TYPE_OTHER_ANALOG		  0x7
#define	  COP_CONN_TYPE_DIN			  0x8
#define	  COP_CONN_TYPE_XLR			  0x9
#define	  COP_CONN_TYPE_RJ11			  0xa
#define	  COP_CONN_TYPE_COMBINATION		  0xb
#define	  COP_CONN_TYPE_OTHER			  0xf
#define  COP_CFG_DEFAULT_DEVICE(x)		 (((x) >> 20) & 0xf)
#define	  COP_DEVICE_MASK			  0x00f00000
#define	  COP_DEVICE_SHIFT			  20
#define	  COP_DEVICE_LINE_OUT			  0x0
#define	  COP_DEVICE_SPEAKER			  0x1
#define	  COP_DEVICE_HP_OUT			  0x2
#define	  COP_DEVICE_CD				  0x3
#define	  COP_DEVICE_SPDIF_OUT			  0x4
#define	  COP_DEVICE_DIGITAL_OTHER_OUT		  0x5
#define	  COP_DEVICE_MODEM_LINE_SIDE		  0x6
#define	  COP_DEVICE_MODEM_HANDSET_SIDE		  0x7
#define	  COP_DEVICE_LINE_IN			  0x8
#define	  COP_DEVICE_AUX			  0x9
#define	  COP_DEVICE_MIC_IN			  0xa
#define	  COP_DEVICE_TELEPHONY			  0xb
#define	  COP_DEVICE_SPDIF_IN			  0xc
#define	  COP_DEVICE_DIGITAL_OTHER_IN		  0xd
#define	  COP_DEVICE_OTHER			  0xf
#define  COP_CFG_LOCATION(x)			 (((x) >> 24) & 0x3f)
#define  COP_CFG_PORT_CONNECTIVITY(x)		 (((x) >> 30) & 0x3)
#define	  COP_PORT_JACK				  0x0
#define	  COP_PORT_NONE				  0x1
#define	  COP_PORT_FIXED_FUNCTION		  0x2
#define	  COP_PORT_BOTH				  0x3
#define	CORB_SET_CONFIGURATION_DEFAULT_1	0x71c
#define	CORB_SET_CONFIGURATION_DEFAULT_2	0x71d
#define	CORB_SET_CONFIGURATION_DEFAULT_3	0x71e
#define	CORB_SET_CONFIGURATION_DEFAULT_4	0x71f
#define	CORB_GET_STRIPE_CONTROL			0xf24
#define	CORB_SET_STRIPE_CONTROL			0x720
#define	CORB_EXECUTE_RESET			0x7ff
#define	CORB_GET_CONVERTER_CHANNEL_COUNT	0xf2d
#define	CORB_SET_CONVERTER_CHANNEL_COUNT	0x72d
#define	CORB_GET_HDMI_DIP_SIZE			0xf2e
#define	 COP_DIP_ELD_SIZE			 (1 << 3)
#define	 COP_DIP_PI_GP(x)			 ((x) & 0x7)
#define	 COP_DIP_PI_AUDIO_INFO			 COP_DIP_PI_GP(0)
#define	 COP_DIP_BUFFER_SIZE(x)			 ((x) & 0xff)
#define	CORB_GET_HDMI_ELD_DATA			0xf2f
#define	 COP_ELD_VALID				 (1u << 31)
#define	 COP_ELD_DATA(x)			 (((x) >> 0) & 0xff)
#define	CORB_GET_HDMI_DIP_INDEX			0xf30
#define	CORB_SET_HDMI_DIP_INDEX			0x730
#define	 COP_DIP_INDEX_BYTE_SHIFT		 0
#define	 COP_DIP_INDEX_BYTE_MASK		 0xf
#define	 COP_DIP_INDEX_PACKET_INDEX_SHIFT	 4
#define	 COP_DIP_INDEX_PACKET_INDEX_MASK	 0xf
#define	CORB_GET_HDMI_DIP_DATA			0xf31
#define	CORB_SET_HDMI_DIP_DATA			0x731
#define	CORB_GET_HDMI_DIP_XMIT_CTRL		0xf32
#define	CORB_SET_HDMI_DIP_XMIT_CTRL		0x732
#define	 COP_DIP_XMIT_CTRL_DISABLE		 (0x0 << 6)
#define	 COP_DIP_XMIT_CTRL_ONCE			 (0x2 << 6)
#define	 COP_DIP_XMIT_CTRL_BEST_EFFORT		 (0x3 << 6)
#define	CORB_GET_PROTECTION_CONTROL		0xf33
#define	CORB_SET_PROTECTION_CONTROL		0x733
#define	 COP_PROTECTION_CONTROL_CES_ON		 (1 << 9)
#define	 COP_PROTECTION_CONTROL_READY		 (1 << 8)
#define	 COP_PROTECTION_CONTROL_URSUBTAG_SHIFT	 3
#define	 COP_PROTECTION_CONTROL_URSUBTAG_MASK	 0x1f
#define	 COP_PROTECTION_CONTROL_CPSTATE_MASK	 0x3
#define	 COP_PROTECTION_CONTROL_CPSTATE_DONTCARE (0 << 0)
#define	 COP_PROTECTION_CONTROL_CPSTATE_OFF	 (2 << 0)
#define	 COP_PROTECTION_CONTROL_CPSTATE_ON	 (3 << 0)
#define	CORB_ASP_GET_CHANNEL_MAPPING		0xf34
#define	CORB_ASP_SET_CHANNEL_MAPPING		0x734


/*
 * RIRB Entry Format
 */
struct rirb_entry {
	uint32_t	resp;
	uint32_t	resp_ex;
#define	RIRB_CODEC_ID(entry)	((entry)->resp_ex & 0xf)
#define	RIRB_UNSOL(entry)	((entry)->resp_ex & 0x10)
} __packed;

#endif /* !_HDAUDIOREG_H */