/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 The FreeBSD Foundation
 *
 * This software was developed by Mitchell Horne under sponsorship from
 * the FreeBSD Foundation.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _MACHINE_GDB_MACHDEP_H_
#define	_MACHINE_GDB_MACHDEP_H_

#define	GDB_BUFSZ	4096
#define	GDB_NREGS	68
#define	GDB_REG_X0	0
#define	GDB_REG_X19	19
#define	GDB_REG_X29	29
#define	GDB_REG_LR	30
#define	GDB_REG_SP	31
#define	GDB_REG_PC	32
#define	GDB_REG_CSPR	33
#define	GDB_REG_V0	34
#define	GDB_REG_V31	65
#define	GDB_REG_FPSR	66
#define	GDB_REG_FPCR	67
_Static_assert(GDB_BUFSZ >= (GDB_NREGS * 16), "buffer fits 'g' regs");

static __inline size_t
gdb_cpu_regsz(int regnum)
{
	if (regnum == GDB_REG_CSPR || regnum == GDB_REG_FPSR ||
	    regnum == GDB_REG_FPCR)
		return (4);
	else if (regnum >= GDB_REG_V0 && regnum <= GDB_REG_V31)
		return (16);

	return (8);
}

static __inline int
gdb_cpu_query(void)
{
	return (0);
}

static __inline void *
gdb_begin_write(void)
{
	return (NULL);
}

static __inline void
gdb_end_write(void *arg __unused)
{
}

void *gdb_cpu_getreg(int, size_t *);
void gdb_cpu_setreg(int, void *);
int gdb_cpu_signal(int, int);
void gdb_cpu_stop_reason(int, int);

#endif /* !_MACHINE_GDB_MACHDEP_H_ */