/*
 * Copyright (c) 2006, 2010 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */


#ifndef _SPAWN_H_
#define _SPAWN_H_

/*
 * [SPN] Support for _POSIX_SPAWN
 */

#include <sys/cdefs.h>
#include <_types.h>
#include <sys/spawn.h> /* shared types */

#include <Availability.h>

/*
 * [SPN] Inclusion of the <spawn.h> header may make visible symbols defined
 * in the <sched.h>, <signal.h>, and <sys/types.h> headers.
 */
#include <sys/_types/_pid_t.h>
#include <sys/_types/_sigset_t.h>
#include <sys/_types/_mode_t.h>

/*
 * Opaque types for use with posix_spawn() family functions.  Internals are
 * not defined, and should not be accessed directly.  Types are defined as
 * mandated by POSIX.
 */
typedef  void *posix_spawnattr_t;
typedef  void *posix_spawn_file_actions_t;

__BEGIN_DECLS
/*
 * gcc under c99 mode won't compile "[ __restrict]" by itself.  As a workaround,
 * a dummy argument name is added.
 */

int     posix_spawn(pid_t * __restrict, const char * __restrict,
    const posix_spawn_file_actions_t *,
    const posix_spawnattr_t * __restrict,
    char *const __argv[__restrict],
    char *const __envp[__restrict]) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnp(pid_t * __restrict, const char * __restrict,
    const posix_spawn_file_actions_t *,
    const posix_spawnattr_t * __restrict,
    char *const __argv[__restrict],
    char *const __envp[__restrict]) __API_AVAILABLE(macos(10.5), ios(2.0));

int     posix_spawn_file_actions_addclose(posix_spawn_file_actions_t *, int) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawn_file_actions_adddup2(posix_spawn_file_actions_t *, int,
    int) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawn_file_actions_addopen(
	posix_spawn_file_actions_t * __restrict, int,
	const char * __restrict, int, mode_t) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawn_file_actions_init(posix_spawn_file_actions_t *) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_destroy(posix_spawnattr_t *) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_getsigdefault(const posix_spawnattr_t * __restrict,
    sigset_t * __restrict) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_getflags(const posix_spawnattr_t * __restrict,
    short * __restrict) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_getpgroup(const posix_spawnattr_t * __restrict,
    pid_t * __restrict) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_getsigmask(const posix_spawnattr_t * __restrict,
    sigset_t * __restrict) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_init(posix_spawnattr_t *) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setsigdefault(posix_spawnattr_t * __restrict,
    const sigset_t * __restrict) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setflags(posix_spawnattr_t *, short) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setpgroup(posix_spawnattr_t *, pid_t) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setsigmask(posix_spawnattr_t * __restrict,
    const sigset_t * __restrict) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

#if 0   /* _POSIX_PRIORITY_SCHEDULING [PS] : not supported */
int     posix_spawnattr_setschedparam(posix_spawnattr_t * __restrict,
    const struct sched_param * __restrict);
int     posix_spawnattr_setschedpolicy(posix_spawnattr_t *, int);
int     posix_spawnattr_getschedparam(const posix_spawnattr_t * __restrict,
    struct sched_param * __restrict);
int     posix_spawnattr_getschedpolicy(const posix_spawnattr_t * __restrict,
    int * __restrict);
#endif  /* 0 */

__END_DECLS

#if     !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * Darwin-specific extensions below
 */
#include <mach/exception_types.h>
#include <mach/machine.h>
#include <mach/port.h>

#include <sys/_types/_size_t.h>

__BEGIN_DECLS

int     posix_spawnattr_getbinpref_np(const posix_spawnattr_t * __restrict,
    size_t, cpu_type_t *__restrict, size_t *__restrict) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_getarchpref_np(const posix_spawnattr_t * __restrict,
    size_t, cpu_type_t *__restrict, cpu_subtype_t *__restrict, size_t *__restrict) __API_AVAILABLE(macos(11.0), ios(14.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setauditsessionport_np(posix_spawnattr_t * __restrict,
    mach_port_t) __API_AVAILABLE(macos(10.6), ios(3.2));

int     posix_spawnattr_setbinpref_np(posix_spawnattr_t * __restrict,
    size_t, cpu_type_t *__restrict, size_t *__restrict) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setarchpref_np(posix_spawnattr_t * __restrict,
    size_t, cpu_type_t *__restrict, cpu_subtype_t *__restrict, size_t *__restrict) __API_AVAILABLE(macos(11.0), ios(14.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setexceptionports_np(posix_spawnattr_t * __restrict,
    exception_mask_t, mach_port_t,
    exception_behavior_t, thread_state_flavor_t) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setspecialport_np(posix_spawnattr_t * __restrict,
    mach_port_t, int) __API_AVAILABLE(macos(10.5), ios(2.0)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawnattr_setnosmt_np(const posix_spawnattr_t * __restrict attr) __API_AVAILABLE(macos(11.0));

/*
 * Set CPU Security Mitigation on the spawned process
 * This attribute affects all threads and is inherited on fork and exec
 */
int     posix_spawnattr_set_csm_np(const posix_spawnattr_t * __restrict attr, uint32_t flags) __API_AVAILABLE(macos(11.0));
/*
 * flags for CPU Security Mitigation attribute
 * POSIX_SPAWN_NP_CSM_ALL should be used in most cases,
 * the individual flags are provided only for performance evaluation etc
 */
#define POSIX_SPAWN_NP_CSM_ALL         0x0001
#define POSIX_SPAWN_NP_CSM_NOSMT       0x0002
#define POSIX_SPAWN_NP_CSM_TECS        0x0004

int     posix_spawn_file_actions_addinherit_np(posix_spawn_file_actions_t *,
    int) __API_AVAILABLE(macos(10.7), ios(4.3)) __API_UNAVAILABLE(watchos, tvos);

int     posix_spawn_file_actions_addchdir_np(posix_spawn_file_actions_t *,
    const char * __restrict) __API_AVAILABLE(macos(10.15)) __API_UNAVAILABLE(ios, tvos, watchos);

int     posix_spawn_file_actions_addfchdir_np(posix_spawn_file_actions_t *,
    int) __API_AVAILABLE(macos(10.15)) __API_UNAVAILABLE(ios, tvos, watchos);

__END_DECLS

#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#endif  /* _SPAWN_H_ */