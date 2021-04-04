/* Defines for bits in AT_HWCAP.  ARM Linux version.
   Copyright (C) 2012-2021 Free Software Foundation, Inc.
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
   <https://www.gnu.org/licenses/>.  */

#if !defined (_SYS_AUXV_H) && !defined (_LINUX_ARM_SYSDEP_H)
# error "Never include <bits/hwcap.h> directly; use <sys/auxv.h> instead."
#endif

/* The following must match the kernel's <asm/hwcap.h>.  */
#define HWCAP_ARM_SWP		1
#define HWCAP_ARM_HALF		2
#define HWCAP_ARM_THUMB		4
#define HWCAP_ARM_26BIT		8
#define HWCAP_ARM_FAST_MULT	16
#define HWCAP_ARM_FPA		32
#define HWCAP_ARM_VFP		64
#define HWCAP_ARM_EDSP		128
#define HWCAP_ARM_JAVA		256
#define HWCAP_ARM_IWMMXT	512
#define HWCAP_ARM_CRUNCH	1024
#define HWCAP_ARM_THUMBEE	2048
#define HWCAP_ARM_NEON		4096
#define HWCAP_ARM_VFPv3		8192
#define HWCAP_ARM_VFPv3D16	16384
#define HWCAP_ARM_TLS		32768
#define HWCAP_ARM_VFPv4		65536
#define HWCAP_ARM_IDIVA		131072
#define HWCAP_ARM_IDIVT		262144
#define HWCAP_ARM_VFPD32	524288
#define HWCAP_ARM_LPAE		1048576
#define HWCAP_ARM_EVTSTRM	2097152