/*-
 * Copyright (c) 2023-2025 Ruslan Bukin <br@bsdpad.com>
 *
 * This work was supported by Innovate UK project 105694, "Digital Security
 * by Design (DSbD) Technology Platform Prototype".
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

/* User-visible header. */

#include <sys/param.h>
#include <sys/cpuset.h>
#include <sys/types.h>
#include <sys/hwt_record.h>

#ifndef _SYS_HWT_H_
#define _SYS_HWT_H_

#define	HWT_MAGIC		0x42
#define	HWT_IOC_ALLOC		_IOW(HWT_MAGIC, 0x00, struct hwt_alloc)
#define	HWT_IOC_START		_IOW(HWT_MAGIC, 0x01, struct hwt_start)
#define	HWT_IOC_STOP		_IOW(HWT_MAGIC, 0x02, struct hwt_stop)
#define	HWT_IOC_RECORD_GET	_IOW(HWT_MAGIC, 0x03, struct hwt_record_get)
#define	HWT_IOC_BUFPTR_GET	_IOW(HWT_MAGIC, 0x04, struct hwt_bufptr_get)
#define	HWT_IOC_SET_CONFIG	_IOW(HWT_MAGIC, 0x05, struct hwt_set_config)
#define	HWT_IOC_WAKEUP		_IOW(HWT_MAGIC, 0x06, struct hwt_wakeup)
#define	HWT_IOC_SVC_BUF		_IOW(HWT_MAGIC, 0x07, struct hwt_svc_buf)

#define	HWT_BACKEND_MAXNAMELEN	256

#define	HWT_MODE_THREAD		1
#define	HWT_MODE_CPU		2

struct hwt_alloc {
	size_t		bufsize;
	int		mode;
	pid_t		pid;		/* thread mode */
	cpuset_t	*cpu_map;	/* cpu mode only */
	size_t		cpusetsize;
	const char	*backend_name;
	int		*ident;
	int		kqueue_fd;
} __aligned(16);

struct hwt_start {
	int		reserved;
} __aligned(16);

struct hwt_stop {
	int		reserved;
} __aligned(16);

struct hwt_wakeup {
	int		reserved;
} __aligned(16);

struct hwt_record_user_entry {
	enum hwt_record_type	record_type;
	union {
		/*
		 * Used for MMAP, EXECUTABLE, INTERP,
		 * and KERNEL records.
		 */
		struct {
			char fullpath[MAXPATHLEN];
			uintptr_t addr;
			uintptr_t baseaddr;
		};
		/* Used for BUFFER records. */
		struct {
			int buf_id;
			int curpage;
			vm_offset_t offset;
		};
		/* Used for THREAD_* records. */
		int thread_id;
	};
} __aligned(16);

struct hwt_record_get {
	struct hwt_record_user_entry	*records;
	int				*nentries;
	int             wait;
} __aligned(16);

struct hwt_bufptr_get {
	int		*ident;
	vm_offset_t	*offset;
	uint64_t	*data;
} __aligned(16);

struct hwt_set_config {
	/* Configuration of ctx. */
	int			pause_on_mmap;

	/* The following passed to backend as is. */
	void			*config;
	size_t			config_size;
	int			config_version;
} __aligned(16);

struct hwt_svc_buf {
	/* The following passed to backend as is. */
	void			*data;
	size_t			data_size;
	int			data_version;
} __aligned(16);

#endif /* !_SYS_HWT_H_ */