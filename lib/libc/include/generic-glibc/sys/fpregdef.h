/* Copyright (C) 1991-2021 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_FPREGDEF_H
#define _SYS_FPREGDEF_H

#include <sgidefs.h>

/* Commonalities first, individualities next...  */

#define fv0	$f0	/* return value */
#define fv1	$f2

#if _MIPS_SIM == _ABIO32 || _MIPS_SIM == _ABIN32
#define fs0	$f20	/* callee saved */
#define fs1	$f22
#define fs2	$f24
#define fs3	$f26
#define fs4	$f28
#define fs5	$f30
#endif /* _MIPS_SIM == _ABIO32 || _MIPS_SIM == _ABIN32 */

#if _MIPS_SIM == _ABI64 || _MIPS_SIM == _ABIN32
#define fa0	$f12	/* argument registers */
#define fa1	$f13
#define fa2	$f14
#define fa3	$f15
#define fa4	$f16
#define fa5	$f17
#define fa6	$f18
#define fa7	$f19

#define ft0	$f4	/* caller saved */
#define ft1	$f5
#define ft2	$f6
#define ft3	$f7
#define ft4	$f8
#define ft5	$f9
#define ft6	$f10
#define ft7	$f11
#endif /* _MIPS_SIM == _ABI64 || _MIPS_SIM == _ABIN32 */

#if _MIPS_SIM == _ABIO32
#define fv0f	$f1	/* return value, high part */
#define fv1f	$f3

#define fa0	$f12	/* argument registers */
#define fa0f	$f13
#define fa1	$f14
#define fa1f	$f15

#define ft0	$f4	/* caller saved */
#define ft0f	$f5
#define ft1	$f6
#define ft1f	$f7
#define ft2	$f8
#define ft2f	$f9
#define ft3	$f10
#define ft3f	$f11
#define ft4	$f16
#define ft4f	$f17
#define ft5	$f18
#define ft5f	$f19

#define fs0f	$f21	/* callee saved, high part */
#define fs1f	$f23
#define fs2f	$f25
#define fs3f	$f27
#define fs4f	$f29
#define fs5f	$f31
#endif /* _MIPS_SIM == _ABIO32 */

#if _MIPS_SIM == _ABI64
#define ft8	$f20	/* caller saved */
#define ft9	$f21
#define ft10	$f22
#define ft11	$f23
#define ft12	$f1
#define ft13	$f3

#define fs0	$f24	/* callee saved */
#define fs1	$f25
#define fs2	$f26
#define fs3	$f27
#define fs4	$f28
#define fs5	$f29
#define fs6	$f30
#define fs7	$f31
#endif /* _MIPS_SIM == _ABI64 */

#if _MIPS_SIM == _ABIN32
#define ft8	$f21	/* caller saved */
#define ft9	$f23
#define ft10	$f25
#define ft11	$f27
#define ft12	$f29
#define ft13	$f31
#define ft14	$f1
#define ft15	$f3
#endif /* _MIPS_SIM == _ABIN32 */

#define fcr31	$31	/* FPU status register */

#endif /* sys/fpregdef.h */