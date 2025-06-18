/*	$NetBSD: cputypes.h,v 1.16.4.1 2024/10/03 16:11:36 martin Exp $	*/

/*
 * Copyright (c) 1998, 2001 Ben Harris
 * Copyright (c) 1994-1996 Mark Brinicombe.
 * Copyright (c) 1994 Brini.
 * All rights reserved.
 *
 * This code is derived from software written for Brini by Mark Brinicombe
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Brini.
 * 4. The name of the company nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRINI ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL BRINI OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _ARM_CPUTYPES_H_
#define _ARM_CPUTYPES_H_

/*
 * The CPU ID register is theoretically structured, but the definitions of
 * the fields keep changing.
 */

/* The high-order byte is always the implementor */
#define CPU_ID_IMPLEMENTOR_MASK	0xff000000
#define CPU_ID_ARM_LTD		0x41000000 /* 'A' */
#define CPU_ID_BROADCOM		0x42000000 /* 'B' */
#define CPU_ID_CAVIUM		0x43000000 /* 'C' */
#define CPU_ID_DEC		0x44000000 /* 'D' */
#define CPU_ID_INFINEON		0x49000000 /* 'I' */
#define CPU_ID_MOTOROLA		0x4d000000 /* 'M' */
#define CPU_ID_NVIDIA		0x4e000000 /* 'N' */
#define CPU_ID_APM		0x50000000 /* 'P' */
#define CPU_ID_QUALCOMM		0x51000000 /* 'Q' */
#define CPU_ID_SAMSUNG		0x53000000 /* 'S' */
#define CPU_ID_TI		0x54000000 /* 'T' */
#define CPU_ID_MARVELL		0x56000000 /* 'V' */
#define CPU_ID_APPLE		0x61000000 /* 'a' */
#define CPU_ID_FARADAY		0x66000000 /* 'f' */
#define CPU_ID_INTEL		0x69000000 /* 'i' */
#define CPU_ID_AMPERE		0xc0000000 /* 'À' */

/* How to decide what format the CPUID is in. */
#define CPU_ID_ISOLD(x)		(((x) & 0x0000f000) == 0x00000000)
#define CPU_ID_IS7(x)		(((x) & 0x0000f000) == 0x00007000)
#define CPU_ID_ISNEW(x)		(!CPU_ID_ISOLD(x) && !CPU_ID_IS7(x))

/* On ARM3 and ARM6, this byte holds the foundry ID. */
#define CPU_ID_FOUNDRY_MASK	0x00ff0000
#define CPU_ID_FOUNDRY_VLSI	0x00560000

/* On ARM7 it holds the architecture and variant (sub-model) */
#define CPU_ID_7ARCH_MASK	0x00800000
#define CPU_ID_7ARCH_V3		0x00000000
#define CPU_ID_7ARCH_V4T	0x00800000
#define CPU_ID_7VARIANT_MASK	0x007f0000

/* On more recent ARMs, it does the same, but in a different format */
#define CPU_ID_ARCH_MASK	0x000f0000
#define CPU_ID_ARCH_V3		0x00000000
#define CPU_ID_ARCH_V4		0x00010000
#define CPU_ID_ARCH_V4T		0x00020000
#define CPU_ID_ARCH_V5		0x00030000
#define CPU_ID_ARCH_V5T		0x00040000
#define CPU_ID_ARCH_V5TE	0x00050000
#define CPU_ID_ARCH_V5TEJ	0x00060000
#define CPU_ID_ARCH_V6		0x00070000
#define CPU_ID_VARIANT_MASK	0x00f00000

/* Next three nybbles are part number */
#define CPU_ID_PARTNO_MASK	0x0000fff0

/* Intel XScale has sub fields in part number */
#define CPU_ID_XSCALE_COREGEN_MASK	0x0000e000 /* core generation */
#define CPU_ID_XSCALE_COREREV_MASK	0x00001c00 /* core revision */
#define CPU_ID_XSCALE_PRODUCT_MASK	0x000003f0 /* product number */

/* And finally, the revision number. */
#define CPU_ID_REVISION_MASK	0x0000000f

/* Individual CPUs are probably best IDed by everything but the revision. */
#define CPU_ID_CPU_MASK		0xfffffff0

/* Fake CPU IDs for ARMs without CP15 */
#define CPU_ID_ARM2		0x41560200
#define CPU_ID_ARM250		0x41560250

/* Pre-ARM7 CPUs -- [15:12] == 0 */
#define CPU_ID_ARM3		0x41560300
#define CPU_ID_ARM600		0x41560600
#define CPU_ID_ARM610		0x41560610
#define CPU_ID_ARM620		0x41560620

/* ARM7 CPUs -- [15:12] == 7 */
#define CPU_ID_ARM700		0x41007000 /* XXX This is a guess. */
#define CPU_ID_ARM710		0x41007100
#define CPU_ID_ARM7500		0x41027100
#define CPU_ID_ARM710A		0x41067100
#define CPU_ID_ARM7500FE	0x41077100
#define CPU_ID_ARM710T		0x41807100
#define CPU_ID_ARM720T		0x41807200
#define CPU_ID_ARM740T8K	0x41807400 /* XXX no MMU, 8KB cache */
#define CPU_ID_ARM740T4K	0x41817400 /* XXX no MMU, 4KB cache */

/* Post-ARM7 CPUs */
#define CPU_ID_ARM810		0x41018100
#define CPU_ID_ARM920T		0x41129200
#define CPU_ID_ARM922T		0x41029220
#define CPU_ID_ARM926EJS	0x41069260
#define CPU_ID_ARM940T		0x41029400 /* XXX no MMU */
#define CPU_ID_ARM946ES		0x41049460 /* XXX no MMU */
#define CPU_ID_ARM966ES		0x41049660 /* XXX no MMU */
#define CPU_ID_ARM966ESR1	0x41059660 /* XXX no MMU */
#define CPU_ID_ARM1020E		0x4115a200 /* (AKA arm10 rev 1) */
#define CPU_ID_ARM1022ES	0x4105a220
#define CPU_ID_ARM1026EJS	0x4106a260
#define CPU_ID_ARM11MPCORE	0x410fb020
#define CPU_ID_ARM1136JS	0x4107b360
#define CPU_ID_ARM1136JSR1	0x4117b360
#define CPU_ID_ARM1156T2S	0x4107b560 /* MPU only */
#define CPU_ID_ARM1176JZS	0x410fb760
#define CPU_ID_ARM11_P(n)	((n & 0xff07f000) == 0x4107b000)

/* ARMv7 CPUs */
#define CPU_ID_CORTEXA5R0	0x410fc050
#define CPU_ID_CORTEXA7R0	0x410fc070
#define CPU_ID_CORTEXA8R1	0x411fc080
#define CPU_ID_CORTEXA8R2	0x412fc080
#define CPU_ID_CORTEXA8R3	0x413fc080
#define CPU_ID_CORTEXA9R1	0x411fc090
#define CPU_ID_CORTEXA9R2	0x412fc090
#define CPU_ID_CORTEXA9R3	0x413fc090
#define CPU_ID_CORTEXA9R4	0x414fc090
#define CPU_ID_CORTEXA12R0	0x410fc0d0
#define CPU_ID_CORTEXA15R2	0x412fc0f0
#define CPU_ID_CORTEXA15R3	0x413fc0f0
#define CPU_ID_CORTEXA15R4	0x414fc0f0
#define CPU_ID_CORTEXA17R1	0x411fc0e0

/* ARMv8 CPUS */
#define CPU_ID_CORTEXA32R1	0x411fd010
#define CPU_ID_CORTEXA35R0	0x410fd040
#define CPU_ID_CORTEXA35R1	0x411fd040
#define CPU_ID_CORTEXA53R0	0x410fd030
#define CPU_ID_CORTEXA55R1	0x411fd050
#define CPU_ID_CORTEXA57R0	0x410fd070
#define CPU_ID_CORTEXA57R1	0x411fd070
#define CPU_ID_CORTEXA65R0	0x410fd060
#define CPU_ID_CORTEXA72R0	0x410fd080
#define CPU_ID_CORTEXA73R0	0x410fd090
#define CPU_ID_CORTEXA75R2	0x412fd0a0
#define CPU_ID_CORTEXA76AER1	0x411fd0e0
#define CPU_ID_CORTEXA76R3	0x413fd0b0
#define CPU_ID_NEOVERSEN1R3	0x413fd0c0
#define CPU_ID_NEOVERSEE1R1	0x411fd4a0
#define CPU_ID_CORTEXA77R0	0x410fd0d0

#define CPU_ID_CORTEX_P(n)	((n & 0xff0fe000) == 0x410fc000)
#define CPU_ID_CORTEX_A5_P(n)	((n & 0xff0ff0f0) == 0x410fc050)
#define CPU_ID_CORTEX_A7_P(n)	((n & 0xff0ff0f0) == 0x410fc070)
#define CPU_ID_CORTEX_A8_P(n)	((n & 0xff0ff0f0) == 0x410fc080)
#define CPU_ID_CORTEX_A9_P(n)	((n & 0xff0ff0f0) == 0x410fc090)
#define CPU_ID_CORTEX_A12_P(n)	((n & 0xff0ff0f0) == 0x410fc0d0)
#define CPU_ID_CORTEX_A15_P(n)	((n & 0xff0ff0f0) == 0x410fc0f0)
#define CPU_ID_CORTEX_A17_P(n)	((n & 0xff0ff0f0) == 0x410fc0e0)
#define CPU_ID_CORTEX_A32_P(n)	((n & 0xff0ff0f0) == 0x410fd010)
#define CPU_ID_CORTEX_A35_P(n)	((n & 0xff0ff0f0) == 0x410fd040)
#define CPU_ID_CORTEX_A53_P(n)	((n & 0xff0ff0f0) == 0x410fd030)
#define CPU_ID_CORTEX_A55_P(n)	((n & 0xff0ff0f0) == 0x410fd050)
#define CPU_ID_CORTEX_A57_P(n)	((n & 0xff0ff0f0) == 0x410fd070)
#define CPU_ID_CORTEX_A65_P(n)	((n & 0xff0ff0f0) == 0x410fd060)
#define CPU_ID_CORTEX_A72_P(n)	((n & 0xff0ff0f0) == 0x410fd080)
#define CPU_ID_CORTEX_A73_P(n)	((n & 0xff0ff0f0) == 0x410fd090)
#define CPU_ID_CORTEX_A75_P(n)	((n & 0xff0ff0f0) == 0x410fd0a0)
#define CPU_ID_CORTEX_A76_P(n)	((n & 0xff0ff0f0) == 0x410fd0b0)
#define CPU_ID_CORTEX_A76AE_P(n) ((n & 0xff0ff0f0) == 0x410fd0e0)
#define CPU_ID_CORTEX_A77_P(n)	((n & 0xff0ff0f0) == 0x410fd0f0)

#define CPU_ID_NEOVERSEN1_P(n)	((n & 0xff0ffff0) == 0x410fd0c0)

#define CPU_ID_THUNDERXRX	0x43000a10
#define CPU_ID_THUNDERXP1d0	0x43000a10
#define CPU_ID_THUNDERXP1d1	0x43000a11
#define CPU_ID_THUNDERXP2d1	0x431f0a11
#define CPU_ID_THUNDERX81XXRX	0x43000a20
#define CPU_ID_THUNDERX83XXRX	0x43000a30
#define CPU_ID_THUNDERX2RX	0x43000af0

#define CPU_ID_AMPERE1		0xc00fac30
#define CPU_ID_AMPERE1A		0xc00fac40

/*
 * Chip-specific errata. These defines are intended to be
 * booleans used within if statements. When an appropriate
 * kernel option is disabled, these defines must be defined
 * as 0 to allow the compiler to remove a dead code thus
 * produce better optimized kernel image.
 */
/*
 * Vendor:	Cavium
 * Chip:	ThunderX
 * Revision(s):	Pass 1.0, Pass 1.1
 */
#define	CPU_ID_ERRATA_CAVIUM_THUNDERX_1_1_P(n)		\
    (((n) & 0xfff0ffff) == CPU_ID_THUNDERXP1d0 ||	\
     ((n) & 0xfff0ffff) == CPU_ID_THUNDERXP1d1)

#define CPU_ID_APPLE_M1_ICESTORM	0x61000220
#define CPU_ID_APPLE_M1_FIRESTORM	0x61000230

#define CPU_ID_SA110		0x4401a100
#define CPU_ID_SA1100		0x4401a110
#define CPU_ID_NVIDIADENVER2	0x4e0f0030
#define CPU_ID_EMAG8180		0x503f0002
#define CPU_ID_TI925T		0x54029250
#define CPU_ID_MV88FR571_VD	0x56155710
#define CPU_ID_MV88SV131	0x56251310
#define CPU_ID_FA526		0x66015260
#define CPU_ID_SA1110		0x6901b110
#define CPU_ID_IXP1200		0x6901c120
#define CPU_ID_80200		0x69052000
#define CPU_ID_PXA250		0x69052100 /* sans core revision */
#define CPU_ID_PXA210		0x69052120
#define CPU_ID_PXA250A		0x69052100 /* 1st version Core */
#define CPU_ID_PXA210A		0x69052120 /* 1st version Core */
#define CPU_ID_PXA250B		0x69052900 /* 3rd version Core */
#define CPU_ID_PXA210B		0x69052920 /* 3rd version Core */
#define CPU_ID_PXA250C		0x69052d00 /* 4th version Core */
#define CPU_ID_PXA210C		0x69052d20 /* 4th version Core */
#define CPU_ID_PXA27X		0x69054110
#define CPU_ID_80321_400	0x69052420
#define CPU_ID_80321_600	0x69052430
#define CPU_ID_80321_400_B0	0x69052c20
#define CPU_ID_80321_600_B0	0x69052c30
#define CPU_ID_80219_400	0x69052e20
#define CPU_ID_80219_600	0x69052e30
#define CPU_ID_IXP425_533	0x690541c0
#define CPU_ID_IXP425_400	0x690541d0
#define CPU_ID_IXP425_266	0x690541f0
#define CPU_ID_MV88SV58XX_P(n)	((n & 0xff0fff00) == 0x560f5800)
#define CPU_ID_MV88SV581X_V6	0x560f5810 /* Marvell Sheeva 88SV581x v6 Core */
#define CPU_ID_MV88SV581X_V7	0x561f5810 /* Marvell Sheeva 88SV581x v7 Core */
#define CPU_ID_MV88SV584X_V6	0x561f5840 /* Marvell Sheeva 88SV584x v6 Core */
#define CPU_ID_MV88SV584X_V7	0x562f5840 /* Marvell Sheeva 88SV584x v7 Core */
/* Marvell's CPUIDs with ARM ID in implementor field */
#define CPU_ID_ARM_88SV581X_V6	0x410fb760 /* Marvell Sheeva 88SV581x v6 Core */
#define CPU_ID_ARM_88SV581X_V7	0x413fc080 /* Marvell Sheeva 88SV581x v7 Core */
#define CPU_ID_ARM_88SV584X_V6	0x410fb020 /* Marvell Sheeva 88SV584x v6 Core */

#endif /* _ARM_CPUTYPES_H_ */