/*
 * Copyright (c) 2006, 2007, 2010 Apple Inc. All rights reserved.
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
#ifndef _LIBPROC_H_
#define _LIBPROC_H_

#include <sys/cdefs.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/resource.h>
#include <stdint.h>
#include <stdbool.h>
#include <mach/message.h> /* for audit_token_t */

#include <sys/proc_info.h>

#include <Availability.h>
#include <os/availability.h>

/*
 * This header file contains private interfaces to obtain process information.
 * These interfaces are subject to change in future releases.
 */

/*!
 *       @define PROC_LISTPIDSPATH_PATH_IS_VOLUME
 *       @discussion This flag indicates that all processes that hold open
 *               file references on the volume associated with the specified
 *               path should be returned.
 */
#define PROC_LISTPIDSPATH_PATH_IS_VOLUME        1


/*!
 *       @define PROC_LISTPIDSPATH_EXCLUDE_EVTONLY
 *       @discussion This flag indicates that file references that were opened
 *               with the O_EVTONLY flag should be excluded from the matching
 *               criteria.
 */
#define PROC_LISTPIDSPATH_EXCLUDE_EVTONLY       2

__BEGIN_DECLS


/*!
 *       @function proc_listpidspath
 *       @discussion A function which will search through the current
 *               processes looking for open file references which match
 *               a specified path or volume.
 *       @param type types of processes to be searched (see proc_listpids)
 *       @param typeinfo adjunct information for type
 *       @param path file or volume path
 *       @param pathflags flags to control which files should be considered
 *               during the process search.
 *       @param buffer a C array of int-sized values to be filled with
 *               process identifiers that hold an open file reference
 *               matching the specified path or volume.  Pass NULL to
 *               obtain the minimum buffer size needed to hold the
 *               currently active processes.
 *       @param buffersize the size (in bytes) of the provided buffer.
 *       @result the number of bytes of data returned in the provided buffer;
 *               -1 if an error was encountered;
 */
int     proc_listpidspath(uint32_t      type,
    uint32_t      typeinfo,
    const char    *path,
    uint32_t      pathflags,
    void          *buffer,
    int           buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_listallpids(void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
int proc_listpgrppids(pid_t pgrpid, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
int proc_listchildpids(pid_t ppid, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_pidfdinfo(int pid, int fd, int flavor, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_pidfileportinfo(int pid, uint32_t fileport, int flavor, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
int proc_name(int pid, void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_regionfilename(int pid, uint64_t address, void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_kmsgbuf(void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_pidpath(int pid, void * buffer, uint32_t  buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_pidpath_audittoken(audit_token_t *audittoken, void * buffer, uint32_t  buffersize) API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0));
int proc_libversion(int *major, int * minor) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

/*
 * Return resource usage information for the given pid, which can be a live process or a zombie.
 *
 * Returns 0 on success; or -1 on failure, with errno set to indicate the specific error.
 */
int proc_pid_rusage(int pid, int flavor, rusage_info_t *buffer) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);

/*
 * A process can use the following api to set its own process control
 * state on resoure starvation. The argument can have one of the PROC_SETPC_XX values
 */
#define PROC_SETPC_NONE         0
#define PROC_SETPC_THROTTLEMEM  1
#define PROC_SETPC_SUSPEND      2
#define PROC_SETPC_TERMINATE    3

int proc_setpcontrol(const int control) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
int proc_setpcontrol(const int control);

int proc_track_dirty(pid_t pid, uint32_t flags);
int proc_set_dirty(pid_t pid, bool dirty);
int proc_get_dirty(pid_t pid, uint32_t *flags);
int proc_clear_dirty(pid_t pid, uint32_t flags);

int proc_terminate(pid_t pid, int *sig);

/*
 * NO_SMT means that on an SMT CPU, this thread must be scheduled alone,
 * with the paired CPU idle.
 *
 * Set NO_SMT on the current proc (all existing and future threads)
 * This attribute is inherited on fork and exec
 */
int proc_set_no_smt(void) __API_AVAILABLE(macos(11.0));

/* Set NO_SMT on the current thread */
int proc_setthread_no_smt(void) __API_AVAILABLE(macos(11.0));

/*
 * CPU Security Mitigation APIs
 *
 * Set CPU security mitigation on the current proc (all existing and future threads)
 * This attribute is inherited on fork and exec
 */
int proc_set_csm(uint32_t flags) __API_AVAILABLE(macos(11.0));

/* Set CPU security mitigation on the current thread */
int proc_setthread_csm(uint32_t flags) __API_AVAILABLE(macos(11.0));

/*
 * flags for CPU Security Mitigation APIs
 * PROC_CSM_ALL should be used in most cases,
 * the individual flags are provided only for performance evaluation etc
 */
#define PROC_CSM_ALL         0x0001  /* Set all available mitigations */
#define PROC_CSM_NOSMT       0x0002  /* Set NO_SMT - see above */
#define PROC_CSM_TECS        0x0004  /* Execute VERW on every return to user mode */

int proc_udata_info(int pid, int flavor, void *buffer, int buffersize);

#if __has_include(<libproc_private.h>)
#include <libproc_private.h>
#endif

__END_DECLS

#endif /*_LIBPROC_H_ */