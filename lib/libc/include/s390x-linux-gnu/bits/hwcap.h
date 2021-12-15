/* Defines for bits in AT_HWCAP.
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

#ifndef _SYS_AUXV_H
# error "Never include <bits/hwcap.h> directly; use <sys/auxv.h> instead."
#endif

/*
 * The following must match the kernels asm/elf.h.
 * Note that these are *not* the same as the STORE FACILITY LIST bits.
 */
#define HWCAP_S390_ESAN3        1
#define HWCAP_S390_ZARCH        2
#define HWCAP_S390_STFLE        4
#define HWCAP_S390_MSA          8
#define HWCAP_S390_LDISP        16
#define HWCAP_S390_EIMM         32
#define HWCAP_S390_DFP          64
#define HWCAP_S390_HPAGE        128
#define HWCAP_S390_ETF3EH       256
#define HWCAP_S390_HIGH_GPRS    512
#define HWCAP_S390_TE           1024
#define HWCAP_S390_VX           2048
#define HWCAP_S390_VXRS         HWCAP_S390_VX
#define HWCAP_S390_VXD          4096
#define HWCAP_S390_VXRS_BCD     HWCAP_S390_VXD
#define HWCAP_S390_VXE          8192
#define HWCAP_S390_VXRS_EXT     HWCAP_S390_VXE
#define HWCAP_S390_GS           16384
#define HWCAP_S390_VXRS_EXT2    32768
#define HWCAP_S390_VXRS_PDE     65536
#define HWCAP_S390_SORT         131072
#define HWCAP_S390_DFLT         262144
#define HWCAP_S390_VXRS_PDE2    524288
#define HWCAP_S390_NNPA         1048576