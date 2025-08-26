/*-
 * Copyright (c) 2004 Marcel Moolenaar
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
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

#ifndef _MACHINE_KDB_H_
#define _MACHINE_KDB_H_

#include <machine/cpufunc.h>

static __inline void
kdb_cpu_clear_singlestep(void)
{
}

static __inline void
kdb_cpu_set_singlestep(void)
{
}

static __inline void
kdb_cpu_sync_icache(unsigned char *addr, size_t size)
{

	/*
	 * Other CPUs flush their instruction cache when resuming from
	 * IPI_STOP.
	 */
	fence_i();
}

static __inline void
kdb_cpu_trap(int type, int code)
{
}

static __inline int
kdb_cpu_set_watchpoint(vm_offset_t addr, vm_size_t size, int access)
{

	return (ENXIO);
}

static __inline int
kdb_cpu_clr_watchpoint(vm_offset_t addr, vm_size_t size)
{

	return (0);
}

#endif /* _MACHINE_KDB_H_ */