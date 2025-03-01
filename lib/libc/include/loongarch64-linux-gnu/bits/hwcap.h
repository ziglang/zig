/* Defines for bits in AT_HWCAP.  LoongArch64 Linux version.
   Copyright (C) 2022-2025 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#if !defined (_SYS_AUXV_H)
# error "Never include <bits/hwcap.h> directly; use <sys/auxv.h> instead."
#endif

/* The following must match the kernel's <asm/hwcap.h>.  */
/* HWCAP flags */
#define HWCAP_LOONGARCH_CPUCFG          (1 << 0)
#define HWCAP_LOONGARCH_LAM             (1 << 1)
#define HWCAP_LOONGARCH_UAL             (1 << 2)
#define HWCAP_LOONGARCH_FPU             (1 << 3)
#define HWCAP_LOONGARCH_LSX             (1 << 4)
#define HWCAP_LOONGARCH_LASX            (1 << 5)
#define HWCAP_LOONGARCH_CRC32           (1 << 6)
#define HWCAP_LOONGARCH_COMPLEX         (1 << 7)
#define HWCAP_LOONGARCH_CRYPTO          (1 << 8)
#define HWCAP_LOONGARCH_LVZ             (1 << 9)
#define HWCAP_LOONGARCH_LBT_X86         (1 << 10)
#define HWCAP_LOONGARCH_LBT_ARM         (1 << 11)
#define HWCAP_LOONGARCH_LBT_MIPS        (1 << 12)
#define HWCAP_LOONGARCH_PTW             (1 << 13)
#define HWCAP_LOONGARCH_LSPW            (1 << 14)