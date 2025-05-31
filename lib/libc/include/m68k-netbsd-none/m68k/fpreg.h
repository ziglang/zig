/*	$NetBSD: fpreg.h,v 1.3 2014/03/18 18:20:41 riastradh Exp $	*/

/*
 * Copyright (c) 1995 Gordon Ross
 * Copyright (c) 1995 Ken Nakata
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
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 * 4. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Gordon Ross
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _FPREG_H_
#define _FPREG_H_


/*
 * MC68881/68882 FPcr bit definitions
 */

/* fpsr */
#define FPSR_CCB    0xff000000
# define FPSR_NEG   0x08000000
# define FPSR_ZERO  0x04000000
# define FPSR_INF   0x02000000
# define FPSR_NAN   0x01000000
#define FPSR_QTT    0x00ff0000
# define FPSR_QSG   0x00800000
# define FPSR_QUO   0x007f0000
#define FPSR_EXCP   0x0000ff00
#define FPSR_EXCP2  0x00003e00
# define FPSR_BSUN  0x00008000
# define FPSR_SNAN  0x00004000
# define FPSR_OPERR 0x00002000
# define FPSR_OVFL  0x00001000
# define FPSR_UNFL  0x00000800
# define FPSR_DZ    0x00000400
# define FPSR_INEX2 0x00000200
# define FPSR_INEX1 0x00000100
#define FPSR_AEX    0x000000f8
# define FPSR_AIOP  0x00000080
# define FPSR_AOVFL 0x00000040
# define FPSR_AUNFL 0x00000020
# define FPSR_ADZ   0x00000010
# define FPSR_AINEX 0x00000008

/* fpcr */
#define FPCR_EXCP   FPSR_EXCP
#define FPCR_EXCP2  FPSR_EXCP2
# define FPCR_BSUN  FPSR_BSUN
# define FPCR_SNAN  FPSR_SNAN
# define FPCR_OPERR FPSR_OPERR
# define FPCR_OVFL  FPSR_OVFL
# define FPCR_UNFL  FPSR_UNFL
# define FPCR_DZ    FPSR_DZ
# define FPCR_INEX2 FPSR_INEX2
# define FPCR_INEX1 FPSR_INEX1
#define FPCR_MODE   0x000000ff
# define FPCR_PREC  0x000000c0
#  define FPCR_EXTD 0x00000000
#  define FPCR_SNGL 0x00000040
#  define FPCR_DBL  0x00000080
# define FPCR_ROUND 0x00000030
#  define FPCR_NEAR 0x00000000
#  define FPCR_ZERO 0x00000010
#  define FPCR_MINF 0x00000020
#  define FPCR_PINF 0x00000030


#endif