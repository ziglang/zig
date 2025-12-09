/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 Mark Johnston <markj@FreeBSD.org>
 */

#ifndef _SYS_SDT_MACHDEP_H_
#define	_SYS_SDT_MACHDEP_H_

#define	_SDT_ASM_PATCH_INSTR		"nop; nop; nop; nop; nop"

/*
 * Work around an apparent clang bug or limitation which prevents the use of the
 * "i" (immediate) constraint with the probe structure.
 */
#define	_SDT_ASM_PROBE_CONSTRAINT	"Ws"
#define	_SDT_ASM_PROBE_OPERAND		"p"

#endif