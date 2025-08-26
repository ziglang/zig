/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _LINUX_KCMP_H
#define _LINUX_KCMP_H

#include <linux/types.h>

/* Comparison type */
enum kcmp_type {
	KCMP_FILE,
	KCMP_VM,
	KCMP_FILES,
	KCMP_FS,
	KCMP_SIGHAND,
	KCMP_IO,
	KCMP_SYSVSEM,
	KCMP_EPOLL_TFD,

	KCMP_TYPES,
};

/* Slot for KCMP_EPOLL_TFD */
struct kcmp_epoll_slot {
	__u32 efd;		/* epoll file descriptor */
	__u32 tfd;		/* target file number */
	__u32 toff;		/* target offset within same numbered sequence */
};

#endif /* _LINUX_KCMP_H */