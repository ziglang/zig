/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2001 by Thomas Moestl <tmm@FreeBSD.org>.
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
 * IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _MACHINE_OFW_MACHDEP_H_
#define _MACHINE_OFW_MACHDEP_H_

#include <sys/cdefs.h>
#include <sys/types.h>
#include <sys/rman.h>
#include <sys/bus.h>
#include <dev/ofw/openfirm.h>
#include <machine/platform.h>

struct mem_region;
struct numa_mem_region;

typedef	uint32_t	cell_t;

void OF_getetheraddr(device_t dev, u_char *addr);

void OF_initial_setup(void *fdt_ptr, void *junk, int (*openfirm)(void *));
boolean_t OF_bootstrap(void);

void OF_reboot(void);

void ofw_mem_regions(struct mem_region *, int *, struct mem_region *, int *);
void ofw_numa_mem_regions(struct numa_mem_region *, int *);
void ofw_quiesce(void); /* Must be called before VM is up! */
void ofw_save_trap_vec(char *);
int ofw_pcibus_get_domain(device_t dev, device_t child, int *domain);
int ofw_pcibus_get_cpus(device_t dev, device_t child, enum cpu_sets op,
		size_t setsize, cpuset_t *cpuset);

#endif /* _MACHINE_OFW_MACHDEP_H_ */