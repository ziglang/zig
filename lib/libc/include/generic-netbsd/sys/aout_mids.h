/* $NetBSD: aout_mids.h,v 1.7 2017/01/14 21:29:02 christos Exp $ */

/*
 * Copyright (c) 2009, The NetBSD Foundation, Inc.
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

#ifndef _SYS_AOUT_MIDS_H_
#define _SYS_AOUT_MIDS_H_

/*
 * a_mid - keep sorted in numerical order for sanity's sake
 * ensure that: 0 < mid < 0x3ff
 *
 * NB: These are still being used in kernel core files.
 */
#define	MID_ZERO	0x000	/* unknown - implementation dependent */
#define	MID_SUN010	0x001	/* sun 68010/68020 binary */
#define	MID_SUN020	0x002	/* sun 68020-only binary */

#define	MID_PC386	0x064	/* 386 PC binary. (so quoth BFD) */

#define	MID_I386	0x086	/* i386 BSD binary */
#define	MID_M68K	0x087	/* m68k BSD binary with 8K page sizes */
#define	MID_M68K4K	0x088	/* m68k BSD binary with 4K page sizes */
#define	MID_NS32532	0x089	/* ns32532 */
#define	MID_SPARC	0x08a	/* sparc */
#define	MID_PMAX	0x08b	/* pmax */
#define	MID_VAX1K	0x08c	/* VAX 1K page size binaries */
#define	MID_ALPHA	0x08d	/* Alpha BSD binary */
#define	MID_MIPS	0x08e	/* big-endian MIPS */
#define	MID_ARM6	0x08f	/* ARM6 */
#define	MID_M680002K	0x090	/* m68000 with 2K page sizes */
#define	MID_SH3		0x091	/* SH3 */

#define	MID_POWERPC64	0x094	/* big-endian PowerPC 64 */
#define	MID_POWERPC	0x095	/* big-endian PowerPC */
#define	MID_VAX		0x096	/* VAX */
#define	MID_MIPS1	0x097	/* MIPS1 */
#define	MID_MIPS2	0x098	/* MIPS2 */
#define	MID_M88K	0x099	/* m88k BSD */
#define	MID_HPPA	0x09a	/* HP PARISC */
#define	MID_SH5_64	0x09b	/* LP64 SH5 */
#define	MID_SPARC64	0x09c	/* LP64 sparc */
#define	MID_X86_64	0x09d	/* AMD x86-64 */
#define	MID_SH5_32	0x09e	/* ILP32 SH5 */
#define	MID_IA64	0x09f	/* Itanium */

#define	MID_AARCH64	0x0b7	/* ARM AARCH64 */
#define	MID_OR1K	0x0b8	/* OpenRISC 1000 */
#define	MID_RISCV	0x0b9	/* Risc-V */

#define	MID_HP200	0x0c8	/* hp200 (68010) BSD binary */

#define	MID_HP300	0x12c	/* hp300 (68020+68881) BSD binary */

#define	MID_HPUX800     0x20b   /* hp800 HP-UX binary */
#define	MID_HPUX	0x20c	/* hp200/300 HP-UX binary */

#endif /* _SYS_AOUT_MIDS_H_ */