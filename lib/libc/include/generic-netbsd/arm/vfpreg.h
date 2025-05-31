/*      $NetBSD: vfpreg.h,v 1.17 2019/09/07 19:42:42 tnn Exp $ */

/*
 * Copyright (c) 2008 ARM Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the company may not be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ARM LTD ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL ARM LTD BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _ARM_VFPREG_H_
#define _ARM_VFPREG_H_

/* FPSID register */

#define VFP_FPSID_IMP_MSK	0xff000000	/* Implementer */
#define VFP_FPSID_IMP_ARM	0x41000000	/* Implementer: ARM */
#define VFP_FPSID_SW		0x00800000	/* VFP implemented in SW */
#define VFP_FPSID_FMT_MSK	0x00600000	/* FLDMX/FSTMX Format */
#define VFP_FPSID_FMT_1		0x00000000	/* Standard format 1 */
#define VFP_FPSID_FMT_2		0x00200000	/* Standard format 2 */
#define VFP_FPSID_FMT_WEIRD	0x00600000	/* Non-standard format */
#define VFP_FPSID_SP		0x00100000	/* Only single precision */
#define VFP_FPSID_ARCH_MSK	0x000f0000	/* Architecture */
#define VFP_FPSID_ARCH_V1	0x00000000	/* Arch VFPv1 */
#define VFP_FPSID_ARCH_V2	0x00010000	/* Arch VFPv2 */
#define VFP_FPSID_ARCH_V3_2	0x00020000	/* Arch VFPv3 (subarch v2) */
#define VFP_FPSID_ARCH_V3	0x00030000	/* Arch VFPv3 (no subarch) */
#define VFP_FPSID_ARCH_V3_3	0x00040000	/* Arch VFPv3 (subarch v3) */
#define VFP_FPSID_PART_MSK	0x0000ff00	/* Part number */
#define VFP_FPSID_PART_VFP10	0x00001000	/* VFP10 */
#define VFP_FPSID_PART_VFP11	0x00002000	/* VFP11 */
#define VFP_FPSID_PART_VFP30	0x00003000	/* VFP30 */
#define VFP_FPSID_VAR_MSK	0x000000f0	/* Variant */
#define VFP_FPSID_VAR_ARM10	0x000000a0	/* Variant ARM10 */
#define VFP_FPSID_VAR_ARM11	0x000000b0	/* Variant ARM11 */
#define VFP_FPSID_REV_MSK	0x0000000f	/* Revision */

#define FPU_VFP10_ARM10E	0x410001a0	/* Really a VFPv2 part */
#define FPU_VFP11_ARM11		0x410120b0
#define FPU_VFP_CORTEXA5	0x41023050
#define FPU_VFP_CORTEXA7	0x41023070
#define FPU_VFP_CORTEXA8	0x410330c0
#define FPU_VFP_CORTEXA9	0x41033090
#define FPU_VFP_CORTEXA12	0x410330d0
#define FPU_VFP_CORTEXA15	0x410330f0
#define FPU_VFP_CORTEXA15_QEMU	0x410430f0
#define FPU_VFP_CORTEXA17	0x410330e0
#define FPU_VFP_CORTEXA53	0x41034030
#define FPU_VFP_CORTEXA57	0x41034070
#define FPU_VFP_MV88SV58XX	0x56022090

#define VFP_FPEXC_EX		0x80000000	/* EXception status bit */
#define VFP_FPEXC_EN		0x40000000	/* VFP Enable bit */
#define VFP_FPEXC_DEX		0x20000000	/* Defined sync EXception bit */
#define VFP_FPEXC_FP2V		0x10000000	/* FPinst2 instruction Valid */
#define VFP_FPEXC_VV		0x08000000	/* Vecitr Valid */
#define VFP_FPEXC_TFV		0x04000000	/* Trapped Fault Valid */
#define VFP_FPEXC_VECITR	0x00000700	/* VECtor ITeRation count */
#define VFP_FPEXC_IDF		0x00000080	/* Input Denormal flag */
#define VFP_FPEXC_IXF		0x00000010	/* Potential inexact flag */
#define VFP_FPEXC_UFF		0x00000008	/* Potential underflow flag */
#define VFP_FPEXC_OFF		0x00000004	/* Potential overflow flag */
#define VFP_FPEXC_DZF		0x00000002	/* Potential DivByZero flag */
#define VFP_FPEXC_IOF		0x00000001	/* Potential inv. op. flag */
#define VFP_FPEXC_FSUM		0x000000ff	/* all flag bits */

#define VFP_FPSCR_N	0x80000000	/* set if compare <= result */
#define VFP_FPSCR_Z	0x40000000	/* set if compare = result */
#define VFP_FPSCR_C	0x20000000	/* set if compare (=,>=,UNORD) result */
#define VFP_FPSCR_V	0x10000000	/* set if compare UNORD result */
#define VFP_FPSCR_QC	0x08000000	/* Cumulative saturation (SIMD) */
#define VFP_FPSCR_AHP	0x04000000	/* Alternative Half-Precision */
#define VFP_FPSCR_DN	0x02000000	/* Default NaN mode */
#define VFP_FPSCR_FZ	0x01000000	/* Flush-to-zero mode */
#define VFP_FPSCR_RMODE	0x00c00000	/* Rounding Mode */
#define VFP_FPSCR_RZ	0x00c00000	/* round towards zero (RZ) */
#define VFP_FPSCR_RM	0x00800000	/* round towards +INF (RP) */
#define VFP_FPSCR_RP	0x00400000	/* round towards -INF (RM) */
#define VFP_FPSCR_RN	0x00000000	/* round to nearest (RN) */
#define VFP_FPSCR_STRIDE 0x00300000	/* Vector Stride */
#define VFP_FPSCR_LEN	0x00070000	/* Vector Length */
#define VFP_FPSCR_IDE	0x00008000	/* Inout Subnormal Exception Enable */
#define VFP_FPSCR_ESUM	0x00001f00	/* IXE|UFE|OFE|DZE|IOE */
#define VFP_FPSCR_IXE	0x00001000	/* Inexact Exception Enable */
#define VFP_FPSCR_UFE	0x00000800	/* Underflow Exception Enable */
#define VFP_FPSCR_OFE	0x00000400	/* Overflow Exception Enable */
#define VFP_FPSCR_DZE	0x00000200	/* DivByZero Exception Enable */
#define VFP_FPSCR_IOE	0x00000100	/* Invalid Operation Cumulative Flag */
#define VFP_FPSCR_IDC	0x00000080	/* Input Subnormal Cumlative Flag */
#define VFP_FPSCR_CSUM	0x0000001f	/* IXC|UFC|OFC|DZC|IOC */
#define VFP_FPSCR_IXC	0x00000010	/* Inexact Cumulative Flag */
#define VFP_FPSCR_UFC	0x00000008	/* Underflow Cumulative Flag */
#define VFP_FPSCR_OFC	0x00000004	/* Overflow Cumulative Flag */
#define VFP_FPSCR_DZC	0x00000002	/* DivByZero Cumulative Flag */
#define VFP_FPSCR_IOC	0x00000001	/* Invalid Operation Cumulative Flag */

#endif /* _ARM_VFPREG_H_ */