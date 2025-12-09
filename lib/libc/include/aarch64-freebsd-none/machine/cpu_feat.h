/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 Arm Ltd
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _MACHINE_CPU_FEAT_H_
#define	_MACHINE_CPU_FEAT_H_

#include <sys/linker_set.h>
#include <sys/sysctl.h>

typedef enum {
	ERRATA_UNKNOWN,		/* Unknown erratum */
	ERRATA_NONE,		/* No errata for this feature on this system. */
	ERRATA_AFFECTED,	/* There is errata on this system. */
	ERRATA_FW_MITIGAION,	/* There is errata, and a firmware */
				/* mitigation. The mitigation may need a */
				/* kernel component. */
} cpu_feat_errata;

typedef enum {
	/*
	 * Don't implement the feature or erratum wrokarount,
	 * e.g. the feature is not implemented or erratum is
	 * for another CPU.
	 */
	FEAT_ALWAYS_DISABLE,

	/*
	 * Disable by default, but allow the user to enable,
	 * e.g. For a rare erratum with a workaround, Arm
	 * Category B (rare) or similar.
	 */
	FEAT_DEFAULT_DISABLE,

	/*
	 * Enabled by default, bit allow the user to disable,
	 * e.g. For a common erratum with a workaround, Arm
	 * Category A or B or similar.
	 */
	FEAT_DEFAULT_ENABLE,

	/* We could add FEAT_ALWAYS_ENABLE if a need was found. */
} cpu_feat_en;

#define	CPU_FEAT_STAGE_MASK	0x00000001
#define	CPU_FEAT_EARLY_BOOT	0x00000000
#define	CPU_FEAT_AFTER_DEV	0x00000001

#define	CPU_FEAT_SCOPE_MASK	0x00000010
#define	CPU_FEAT_PER_CPU	0x00000000
#define	CPU_FEAT_SYSTEM		0x00000010

#define	CPU_FEAT_USER_ENABLED	0x40000000
#define	CPU_FEAT_USER_DISABLED	0x80000000

struct cpu_feat;

typedef cpu_feat_en (cpu_feat_check)(const struct cpu_feat *, u_int);
typedef bool (cpu_feat_has_errata)(const struct cpu_feat *, u_int,
    u_int **, u_int *);
typedef bool (cpu_feat_enable)(const struct cpu_feat *, cpu_feat_errata,
    u_int *, u_int);
typedef void (cpu_feat_disabled)(const struct cpu_feat *);

struct cpu_feat {
	const char		*feat_name;
	cpu_feat_check		*feat_check;
	cpu_feat_has_errata	*feat_has_errata;
	cpu_feat_enable		*feat_enable;
	cpu_feat_disabled	*feat_disabled;
	uint32_t		 feat_flags;
	bool			 feat_enabled;
};
SET_DECLARE(cpu_feat_set, struct cpu_feat);

SYSCTL_DECL(_hw_feat);

#define	CPU_FEAT(name, descr, check, has_errata, enable, disabled, flags) \
static struct cpu_feat name = {						\
	.feat_name		= #name,				\
	.feat_check		= check,				\
	.feat_has_errata	= has_errata,				\
	.feat_enable		= enable,				\
	.feat_disabled		= disabled,				\
	.feat_flags		= flags,				\
	.feat_enabled		= false,				\
};									\
DATA_SET(cpu_feat_set, name);						\
SYSCTL_BOOL(_hw_feat, OID_AUTO, name, CTLFLAG_RD, &name.feat_enabled,	\
    0, descr)

/*
 * Allow drivers to mark an erratum as worked around, e.g. the Errata
 * Management ABI may know the workaround isn't needed on a given system.
 */
typedef cpu_feat_errata (*cpu_feat_errata_check_fn)(const struct cpu_feat *,
    u_int);
void cpu_feat_register_errata_check(cpu_feat_errata_check_fn);

void	enable_cpu_feat(uint32_t);

/* Check if an erratum is in the list of errata */
static inline bool
cpu_feat_has_erratum(u_int *errata_list, u_int errata_count, u_int erratum)
{
	for (u_int i = 0; i < errata_count; i++)
		if (errata_list[0] == erratum)
			return (true);

	return (false);
}

#endif /* _MACHINE_CPU_FEAT_H_ */