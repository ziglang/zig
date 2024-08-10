/* Register Macro definitions
   Copyright (C) 2022-2024 Free Software Foundation, Inc.
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

#ifndef _SYS_REGDEF_H
#define _SYS_REGDEF_H

#define zero $r0
#define ra $r1
#define tp $r2
#define sp $r3
#define a0 $r4
#define a1 $r5
#define a2 $r6
#define a3 $r7
#define a4 $r8
#define a5 $r9
#define a6 $r10
#define a7 $r11
#define v0 $r4
#define v1 $r5
#define t0 $r12
#define t1 $r13
#define t2 $r14
#define t3 $r15
#define t4 $r16
#define t5 $r17
#define t6 $r18
#define t7 $r19
#define t8 $r20
#define x $r21
#define fp $r22
#define s0 $r23
#define s1 $r24
#define s2 $r25
#define s3 $r26
#define s4 $r27
#define s5 $r28
#define s6 $r29
#define s7 $r30
#define s8 $r31

#define fa0 $f0
#define fa1 $f1
#define fa2 $f2
#define fa3 $f3
#define fa4 $f4
#define fa5 $f5
#define fa6 $f6
#define fa7 $f7
#define fv0 $f0
#define fv1 $f1
#define ft0 $f8
#define ft1 $f9
#define ft2 $f10
#define ft3 $f11
#define ft4 $f12
#define ft5 $f13
#define ft6 $f14
#define ft7 $f15
#define ft8 $f16
#define ft9 $f17
#define ft10 $f18
#define ft11 $f19
#define ft12 $f20
#define ft13 $f21
#define ft14 $f22
#define ft15 $f23
#define fs0 $f24
#define fs1 $f25
#define fs2 $f26
#define fs3 $f27
#define fs4 $f28
#define fs5 $f29
#define fs6 $f30
#define fs7 $f31
#define fcc0 $fcc0
#define fcc1 $fcc1
#define fcc2 $fcc2
#define fcc3 $fcc3
#define fcc4 $fcc4
#define fcc5 $fcc5
#define fcc6 $fcc6
#define fcc7 $fcc7
#define fcsr0 $fcsr0

#define vr0 $vr0
#define vr1 $vr1
#define vr2 $vr2
#define vr3 $vr3
#define vr4 $vr4
#define vr5 $vr5
#define vr6 $vr6
#define vr7 $vr7
#define vr8 $vr8
#define vr9 $vr9
#define vr10 $vr10
#define vr11 $vr11
#define vr12 $vr12
#define vr13 $vr13
#define vr14 $vr14
#define vr15 $vr15
#define vr16 $vr16
#define vr17 $vr17
#define vr18 $vr18
#define vr19 $vr19
#define vr20 $vr20
#define vr21 $vr21
#define vr22 $vr22
#define vr23 $vr23
#define vr24 $vr24
#define vr25 $vr25
#define vr26 $vr26
#define vr27 $vr27
#define vr28 $vr28
#define vr29 $vr29
#define vr30 $vr30
#define vr31 $vr31

#define xr0 $xr0
#define xr1 $xr1
#define xr2 $xr2
#define xr3 $xr3
#define xr4 $xr4
#define xr5 $xr5
#define xr6 $xr6
#define xr7 $xr7
#define xr7 $xr7
#define xr8 $xr8
#define xr9 $xr9
#define xr10 $xr10
#define xr11 $xr11
#define xr12 $xr12
#define xr13 $xr13
#define xr14 $xr14
#define xr15 $xr15
#define xr16 $xr16
#define xr17 $xr17
#define xr18 $xr18
#define xr19 $xr19
#define xr20 $xr20
#define xr21 $xr21
#define xr22 $xr22
#define xr23 $xr23
#define xr24 $xr24
#define xr25 $xr25
#define xr26 $xr26
#define xr27 $xr27
#define xr28 $xr28
#define xr29 $xr29
#define xr30 $xr30
#define xr31 $xr31

#endif /* _SYS_REGDEF_H */
