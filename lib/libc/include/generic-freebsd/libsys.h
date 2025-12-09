/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 SRI International
 *
 * This software was developed by SRI International, the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology), and Capabilities Limited under Defense Advanced Research
 * Projects Agency (DARPA) Contract No. FA8750-24-C-B047 ("DEC").
 */

#ifndef _LIBSYS_H_
#define _LIBSYS_H_

#include <sys/types.h>

#include <_libsys.h>

typedef int (__sys_syscall_t)(int number, ...);
typedef int (__sys___syscall_t)(int64_t number, ...);

int	__sys_syscall(int number, ...);
off_t	__sys___syscall(int64_t number, ...);

#endif	/* _LIBSYS_H_ */