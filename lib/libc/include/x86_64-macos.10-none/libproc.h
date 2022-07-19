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

#include <sys/proc_info.h>

#include <Availability.h>

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

#ifdef PRIVATE
#include <sys/event.h>
/*
 * Enumerate potential userspace pointers embedded in kernel data structures.
 * Currently inspects kqueues only.
 *
 * NOTE: returned "pointers" are opaque user-supplied values and thus not
 * guaranteed to address valid objects or be pointers at all.
 *
 * Returns the number of pointers found (which may exceed buffersize), or -1 on
 * failure and errno set appropriately.
 */
int proc_list_uptrs(pid_t pid, uint64_t *buffer, uint32_t buffersize);

int proc_list_dynkqueueids(int pid, kqueue_id_t *buf, uint32_t bufsz);
int proc_piddynkqueueinfo(int pid, int flavor, kqueue_id_t kq_id, void *buffer,
    int buffersize);
#endif /* PRIVATE */

int proc_udata_info(int pid, int flavor, void *buffer, int buffersize);

__END_DECLS

#endif /*_LIBPROC_H_ */