/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * Copyright (C) 2012 ARM Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#ifndef __ASM_HWCAP_H
#define __ASM_HWCAP_H

/*
 * HWCAP flags - for AT_HWCAP
 */
#define HWCAP_FP		(1 << 0)
#define HWCAP_ASIMD		(1 << 1)
#define HWCAP_EVTSTRM		(1 << 2)
#define HWCAP_AES		(1 << 3)
#define HWCAP_PMULL		(1 << 4)
#define HWCAP_SHA1		(1 << 5)
#define HWCAP_SHA2		(1 << 6)
#define HWCAP_CRC32		(1 << 7)
#define HWCAP_ATOMICS		(1 << 8)
#define HWCAP_FPHP		(1 << 9)
#define HWCAP_ASIMDHP		(1 << 10)
#define HWCAP_CPUID		(1 << 11)
#define HWCAP_ASIMDRDM		(1 << 12)
#define HWCAP_JSCVT		(1 << 13)
#define HWCAP_FCMA		(1 << 14)
#define HWCAP_LRCPC		(1 << 15)
#define HWCAP_DCPOP		(1 << 16)
#define HWCAP_SHA3		(1 << 17)
#define HWCAP_SM3		(1 << 18)
#define HWCAP_SM4		(1 << 19)
#define HWCAP_ASIMDDP		(1 << 20)
#define HWCAP_SHA512		(1 << 21)
#define HWCAP_SVE		(1 << 22)
#define HWCAP_ASIMDFHM		(1 << 23)
#define HWCAP_DIT		(1 << 24)
#define HWCAP_USCAT		(1 << 25)
#define HWCAP_ILRCPC		(1 << 26)
#define HWCAP_FLAGM		(1 << 27)
#define HWCAP_SSBS		(1 << 28)
#define HWCAP_SB		(1 << 29)
#define HWCAP_PACA		(1 << 30)
#define HWCAP_PACG		(1UL << 31)

/*
 * HWCAP2 flags - for AT_HWCAP2
 */
#define HWCAP2_DCPODP		(1 << 0)
#define HWCAP2_SVE2		(1 << 1)
#define HWCAP2_SVEAES		(1 << 2)
#define HWCAP2_SVEPMULL		(1 << 3)
#define HWCAP2_SVEBITPERM	(1 << 4)
#define HWCAP2_SVESHA3		(1 << 5)
#define HWCAP2_SVESM4		(1 << 6)
#define HWCAP2_FLAGM2		(1 << 7)
#define HWCAP2_FRINT		(1 << 8)
#define HWCAP2_SVEI8MM		(1 << 9)
#define HWCAP2_SVEF32MM		(1 << 10)
#define HWCAP2_SVEF64MM		(1 << 11)
#define HWCAP2_SVEBF16		(1 << 12)
#define HWCAP2_I8MM		(1 << 13)
#define HWCAP2_BF16		(1 << 14)
#define HWCAP2_DGH		(1 << 15)
#define HWCAP2_RNG		(1 << 16)
#define HWCAP2_BTI		(1 << 17)
#define HWCAP2_MTE		(1 << 18)
#define HWCAP2_ECV		(1 << 19)

#endif /* __ASM_HWCAP_H */