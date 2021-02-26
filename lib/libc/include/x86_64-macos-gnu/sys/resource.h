/*
 * Copyright (c) 2000-2018 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1982, 1986, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)resource.h	8.2 (Berkeley) 1/4/94
 */

#ifndef _SYS_RESOURCE_H_
#define _SYS_RESOURCE_H_

#include <sys/appleapiopts.h>
#include <sys/cdefs.h>
#include <sys/_types.h>

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#include <stdint.h>
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

#include <Availability.h>

/* [XSI] The timeval structure shall be defined as described in
 * <sys/time.h>
 */
#include <sys/_types/_timeval.h>

/* The id_t type shall be defined as described in <sys/types.h> */
#include <sys/_types/_id_t.h>


/*
 * Resource limit type (low 63 bits, excluding the sign bit)
 */
typedef __uint64_t      rlim_t;


/*****
 * PRIORITY
 */

/*
 * Possible values of the first parameter to getpriority()/setpriority(),
 * used to indicate the type of the second parameter.
 */
#define PRIO_PROCESS    0               /* Second argument is a PID */
#define PRIO_PGRP       1               /* Second argument is a GID */
#define PRIO_USER       2               /* Second argument is a UID */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define PRIO_DARWIN_THREAD      3               /* Second argument is always 0 (current thread) */
#define PRIO_DARWIN_PROCESS     4               /* Second argument is a PID */


/*
 * Range limitations for the value of the third parameter to setpriority().
 */
#define PRIO_MIN        -20
#define PRIO_MAX        20

/*
 * use PRIO_DARWIN_BG to set the current thread into "background" state
 * which lowers CPU, disk IO, and networking priorites until thread terminates
 * or "background" state is revoked
 */
#define PRIO_DARWIN_BG 0x1000

/*
 * use PRIO_DARWIN_NONUI to restrict a process's ability to make calls to
 * the GPU. (deprecated)
 */
#define PRIO_DARWIN_NONUI 0x1001

#endif  /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */



/*****
 * RESOURCE USAGE
 */

/*
 * Possible values of the first parameter to getrusage(), used to indicate
 * the scope of the information to be returned.
 */
#define RUSAGE_SELF     0               /* Current process information */
#define RUSAGE_CHILDREN -1              /* Current process' children */

/*
 * A structure representing an accounting of resource utilization.  The
 * address of an instance of this structure is the second parameter to
 * getrusage().
 *
 * Note: All values other than ru_utime and ru_stime are implementaiton
 *       defined and subject to change in a future release.  Their use
 *       is discouraged for standards compliant programs.
 */
struct  rusage {
	struct timeval ru_utime;        /* user time used (PL) */
	struct timeval ru_stime;        /* system time used (PL) */
#if __DARWIN_C_LEVEL < __DARWIN_C_FULL
	long    ru_opaque[14];          /* implementation defined */
#else
	/*
	 * Informational aliases for source compatibility with programs
	 * that need more information than that provided by standards,
	 * and which do not mind being OS-dependent.
	 */
	long    ru_maxrss;              /* max resident set size (PL) */
#define ru_first        ru_ixrss        /* internal: ruadd() range start */
	long    ru_ixrss;               /* integral shared memory size (NU) */
	long    ru_idrss;               /* integral unshared data (NU)  */
	long    ru_isrss;               /* integral unshared stack (NU) */
	long    ru_minflt;              /* page reclaims (NU) */
	long    ru_majflt;              /* page faults (NU) */
	long    ru_nswap;               /* swaps (NU) */
	long    ru_inblock;             /* block input operations (atomic) */
	long    ru_oublock;             /* block output operations (atomic) */
	long    ru_msgsnd;              /* messages sent (atomic) */
	long    ru_msgrcv;              /* messages received (atomic) */
	long    ru_nsignals;            /* signals received (atomic) */
	long    ru_nvcsw;               /* voluntary context switches (atomic) */
	long    ru_nivcsw;              /* involuntary " */
#define ru_last         ru_nivcsw       /* internal: ruadd() range end */
#endif  /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */
};

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
/*
 * Flavors for proc_pid_rusage().
 */
#define RUSAGE_INFO_V0  0
#define RUSAGE_INFO_V1  1
#define RUSAGE_INFO_V2  2
#define RUSAGE_INFO_V3  3
#define RUSAGE_INFO_V4  4
#define RUSAGE_INFO_CURRENT     RUSAGE_INFO_V4

typedef void *rusage_info_t;

struct rusage_info_v0 {
	uint8_t  ri_uuid[16];
	uint64_t ri_user_time;
	uint64_t ri_system_time;
	uint64_t ri_pkg_idle_wkups;
	uint64_t ri_interrupt_wkups;
	uint64_t ri_pageins;
	uint64_t ri_wired_size;
	uint64_t ri_resident_size;
	uint64_t ri_phys_footprint;
	uint64_t ri_proc_start_abstime;
	uint64_t ri_proc_exit_abstime;
};

struct rusage_info_v1 {
	uint8_t  ri_uuid[16];
	uint64_t ri_user_time;
	uint64_t ri_system_time;
	uint64_t ri_pkg_idle_wkups;
	uint64_t ri_interrupt_wkups;
	uint64_t ri_pageins;
	uint64_t ri_wired_size;
	uint64_t ri_resident_size;
	uint64_t ri_phys_footprint;
	uint64_t ri_proc_start_abstime;
	uint64_t ri_proc_exit_abstime;
	uint64_t ri_child_user_time;
	uint64_t ri_child_system_time;
	uint64_t ri_child_pkg_idle_wkups;
	uint64_t ri_child_interrupt_wkups;
	uint64_t ri_child_pageins;
	uint64_t ri_child_elapsed_abstime;
};

struct rusage_info_v2 {
	uint8_t  ri_uuid[16];
	uint64_t ri_user_time;
	uint64_t ri_system_time;
	uint64_t ri_pkg_idle_wkups;
	uint64_t ri_interrupt_wkups;
	uint64_t ri_pageins;
	uint64_t ri_wired_size;
	uint64_t ri_resident_size;
	uint64_t ri_phys_footprint;
	uint64_t ri_proc_start_abstime;
	uint64_t ri_proc_exit_abstime;
	uint64_t ri_child_user_time;
	uint64_t ri_child_system_time;
	uint64_t ri_child_pkg_idle_wkups;
	uint64_t ri_child_interrupt_wkups;
	uint64_t ri_child_pageins;
	uint64_t ri_child_elapsed_abstime;
	uint64_t ri_diskio_bytesread;
	uint64_t ri_diskio_byteswritten;
};

struct rusage_info_v3 {
	uint8_t  ri_uuid[16];
	uint64_t ri_user_time;
	uint64_t ri_system_time;
	uint64_t ri_pkg_idle_wkups;
	uint64_t ri_interrupt_wkups;
	uint64_t ri_pageins;
	uint64_t ri_wired_size;
	uint64_t ri_resident_size;
	uint64_t ri_phys_footprint;
	uint64_t ri_proc_start_abstime;
	uint64_t ri_proc_exit_abstime;
	uint64_t ri_child_user_time;
	uint64_t ri_child_system_time;
	uint64_t ri_child_pkg_idle_wkups;
	uint64_t ri_child_interrupt_wkups;
	uint64_t ri_child_pageins;
	uint64_t ri_child_elapsed_abstime;
	uint64_t ri_diskio_bytesread;
	uint64_t ri_diskio_byteswritten;
	uint64_t ri_cpu_time_qos_default;
	uint64_t ri_cpu_time_qos_maintenance;
	uint64_t ri_cpu_time_qos_background;
	uint64_t ri_cpu_time_qos_utility;
	uint64_t ri_cpu_time_qos_legacy;
	uint64_t ri_cpu_time_qos_user_initiated;
	uint64_t ri_cpu_time_qos_user_interactive;
	uint64_t ri_billed_system_time;
	uint64_t ri_serviced_system_time;
};

struct rusage_info_v4 {
	uint8_t  ri_uuid[16];
	uint64_t ri_user_time;
	uint64_t ri_system_time;
	uint64_t ri_pkg_idle_wkups;
	uint64_t ri_interrupt_wkups;
	uint64_t ri_pageins;
	uint64_t ri_wired_size;
	uint64_t ri_resident_size;
	uint64_t ri_phys_footprint;
	uint64_t ri_proc_start_abstime;
	uint64_t ri_proc_exit_abstime;
	uint64_t ri_child_user_time;
	uint64_t ri_child_system_time;
	uint64_t ri_child_pkg_idle_wkups;
	uint64_t ri_child_interrupt_wkups;
	uint64_t ri_child_pageins;
	uint64_t ri_child_elapsed_abstime;
	uint64_t ri_diskio_bytesread;
	uint64_t ri_diskio_byteswritten;
	uint64_t ri_cpu_time_qos_default;
	uint64_t ri_cpu_time_qos_maintenance;
	uint64_t ri_cpu_time_qos_background;
	uint64_t ri_cpu_time_qos_utility;
	uint64_t ri_cpu_time_qos_legacy;
	uint64_t ri_cpu_time_qos_user_initiated;
	uint64_t ri_cpu_time_qos_user_interactive;
	uint64_t ri_billed_system_time;
	uint64_t ri_serviced_system_time;
	uint64_t ri_logical_writes;
	uint64_t ri_lifetime_max_phys_footprint;
	uint64_t ri_instructions;
	uint64_t ri_cycles;
	uint64_t ri_billed_energy;
	uint64_t ri_serviced_energy;
	uint64_t ri_interval_max_phys_footprint;
	uint64_t ri_runnable_time;
};

typedef struct rusage_info_v4 rusage_info_current;

#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */



/*****
 * RESOURCE LIMITS
 */

/*
 * Symbolic constants for resource limits; since all limits are representable
 * as a type rlim_t, we are permitted to define RLIM_SAVED_* in terms of
 * RLIM_INFINITY.
 */
#define RLIM_INFINITY   (((__uint64_t)1 << 63) - 1)     /* no limit */
#define RLIM_SAVED_MAX  RLIM_INFINITY   /* Unrepresentable hard limit */
#define RLIM_SAVED_CUR  RLIM_INFINITY   /* Unrepresentable soft limit */

/*
 * Possible values of the first parameter to getrlimit()/setrlimit(), to
 * indicate for which resource the operation is being performed.
 */
#define RLIMIT_CPU      0               /* cpu time per process */
#define RLIMIT_FSIZE    1               /* file size */
#define RLIMIT_DATA     2               /* data segment size */
#define RLIMIT_STACK    3               /* stack size */
#define RLIMIT_CORE     4               /* core file size */
#define RLIMIT_AS       5               /* address space (resident set size) */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define RLIMIT_RSS      RLIMIT_AS       /* source compatibility alias */
#define RLIMIT_MEMLOCK  6               /* locked-in-memory address space */
#define RLIMIT_NPROC    7               /* number of processes */
#endif  /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */
#define RLIMIT_NOFILE   8               /* number of open files */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define RLIM_NLIMITS    9               /* total number of resource limits */
#endif  /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */
#define _RLIMIT_POSIX_FLAG      0x1000  /* Set bit for strict POSIX */

/*
 * A structure representing a resource limit.  The address of an instance
 * of this structure is the second parameter to getrlimit()/setrlimit().
 */
struct rlimit {
	rlim_t  rlim_cur;               /* current (soft) limit */
	rlim_t  rlim_max;               /* maximum value for rlim_cur */
};

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
/*
 * proc_rlimit_control()
 *
 * Resource limit flavors
 */
#define RLIMIT_WAKEUPS_MONITOR          0x1 /* Configure the wakeups monitor. */
#define RLIMIT_CPU_USAGE_MONITOR        0x2 /* Configure the CPU usage monitor. */
#define RLIMIT_THREAD_CPULIMITS         0x3 /* Configure a blocking, per-thread, CPU limits. */
#define RLIMIT_FOOTPRINT_INTERVAL       0x4 /* Configure memory footprint interval tracking */

/*
 * Flags for wakeups monitor control.
 */
#define WAKEMON_ENABLE                  0x01
#define WAKEMON_DISABLE                 0x02
#define WAKEMON_GET_PARAMS              0x04
#define WAKEMON_SET_DEFAULTS            0x08
#define WAKEMON_MAKE_FATAL              0x10 /* Configure the task so that violations are fatal. */

/*
 * Flags for CPU usage monitor control.
 */
#define CPUMON_MAKE_FATAL               0x1000

/*
 * Flags for memory footprint interval tracking.
 */
#define FOOTPRINT_INTERVAL_RESET        0x1 /* Reset the footprint interval counter to zero */

struct proc_rlimit_control_wakeupmon {
	uint32_t wm_flags;
	int32_t wm_rate;
};



/* I/O type */
#define IOPOL_TYPE_DISK 0
#define IOPOL_TYPE_VFS_ATIME_UPDATES 2
#define IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES 3
#define IOPOL_TYPE_VFS_STATFS_NO_DATA_VOLUME 4

/* scope */
#define IOPOL_SCOPE_PROCESS   0
#define IOPOL_SCOPE_THREAD    1
#define IOPOL_SCOPE_DARWIN_BG 2

/* I/O Priority */
#define IOPOL_DEFAULT           0
#define IOPOL_IMPORTANT         1
#define IOPOL_PASSIVE           2
#define IOPOL_THROTTLE          3
#define IOPOL_UTILITY           4
#define IOPOL_STANDARD          5

/* compatibility with older names */
#define IOPOL_APPLICATION       IOPOL_STANDARD
#define IOPOL_NORMAL            IOPOL_IMPORTANT


#define IOPOL_ATIME_UPDATES_DEFAULT     0
#define IOPOL_ATIME_UPDATES_OFF         1

#define IOPOL_MATERIALIZE_DATALESS_FILES_DEFAULT 0
#define IOPOL_MATERIALIZE_DATALESS_FILES_OFF     1
#define IOPOL_MATERIALIZE_DATALESS_FILES_ON      2

#define IOPOL_VFS_STATFS_NO_DATA_VOLUME_DEFAULT 0
#define IOPOL_VFS_STATFS_FORCE_NO_DATA_VOLUME   1

#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */


__BEGIN_DECLS
int     getpriority(int, id_t);
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
int     getiopolicy_np(int, int) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */
int     getrlimit(int, struct rlimit *) __DARWIN_ALIAS(getrlimit);
int     getrusage(int, struct rusage *);
int     setpriority(int, id_t, int);
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
int     setiopolicy_np(int, int, int) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */
int     setrlimit(int, const struct rlimit *) __DARWIN_ALIAS(setrlimit);
__END_DECLS

#endif  /* !_SYS_RESOURCE_H_ */