/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2025 Klara, Inc.
 */

#ifndef _INOTIFY_H_
#define _INOTIFY_H_

#include <sys/_types.h>

/* Flags for inotify_init1(). */
#define	IN_NONBLOCK	0x00000004	/* O_NONBLOCK */
#define	IN_CLOEXEC	0x00100000	/* O_CLOEXEC */

struct inotify_event {
	int		wd;
	__uint32_t	mask;
	__uint32_t	cookie;
	__uint32_t	len;
	char		name[0];
};

/* Events, set in the mask field. */
#define	IN_ACCESS		0x00000001
#define	IN_MODIFY		0x00000002
#define	IN_ATTRIB		0x00000004
#define	IN_CLOSE_WRITE		0x00000008
#define	IN_CLOSE_NOWRITE	0x00000010
#define	IN_CLOSE		(IN_CLOSE_WRITE | IN_CLOSE_NOWRITE)
#define	IN_OPEN			0x00000020
#define	IN_MOVED_FROM		0x00000040
#define	IN_MOVED_TO		0x00000080
#define	IN_MOVE			(IN_MOVED_FROM | IN_MOVED_TO)
#define	IN_CREATE		0x00000100
#define	IN_DELETE		0x00000200
#define	IN_DELETE_SELF		0x00000400
#define	IN_MOVE_SELF		0x00000800
#define	IN_ALL_EVENTS		0x00000fff

/* Events report only for entries in a watched dir, not the dir itself. */
#define	_IN_DIR_EVENTS		(IN_CLOSE_WRITE | IN_DELETE | IN_MODIFY | \
				 IN_MOVED_FROM | IN_MOVED_TO)

#ifdef _KERNEL
/*
 * An unlink that's done as part of a rename only records IN_DELETE if the
 * unlinked vnode itself is watched, and not when the containing directory is
 * watched.
 */
#define	_IN_MOVE_DELETE		0x40000000
/*
 * Inode link count changes only trigger IN_ATTRIB events if the inode itself is
 * watched, and not when the containing directory is watched.
 */
#define	_IN_ATTRIB_LINKCOUNT	0x80000000
#endif

/* Flags, set in the mask field. */
#define	IN_ONLYDIR		0x01000000
#define	IN_DONT_FOLLOW		0x02000000
#define	IN_EXCL_UNLINK		0x04000000
#define	IN_MASK_CREATE		0x10000000
#define	IN_MASK_ADD		0x20000000
#define	IN_ONESHOT		0x80000000
#define	_IN_ALL_FLAGS		(IN_ONLYDIR | IN_DONT_FOLLOW |		\
				 IN_EXCL_UNLINK | IN_MASK_CREATE |	\
				 IN_MASK_ADD | IN_ONESHOT)

/* Flags returned by the kernel. */
#define	IN_UNMOUNT		0x00002000
#define	IN_Q_OVERFLOW		0x00004000
#define	IN_IGNORED		0x00008000
#define	IN_ISDIR		0x40000000
#define	_IN_ALL_RETFLAGS	(IN_Q_OVERFLOW | IN_UNMOUNT | IN_IGNORED | \
				 IN_ISDIR)

#define	_IN_ALIGN		_Alignof(struct inotify_event)
#define	_IN_NAMESIZE(namelen)	\
	((namelen) == 0 ? 0 : __align_up((namelen) + 1, _IN_ALIGN))

#ifdef _KERNEL
struct componentname;
struct file;
struct inotify_softc;
struct thread;
struct vnode;

int	inotify_create_file(struct thread *, struct file *, int, int *);
void	inotify_log(struct vnode *, const char *, size_t, int, __uint32_t);

int	kern_inotify_rm_watch(int, uint32_t, struct thread *);
int	kern_inotify_add_watch(int, int, const char *, uint32_t,
	    struct thread *);

void	vn_inotify(struct vnode *, struct vnode *, struct componentname *, int,
	    uint32_t);
int	vn_inotify_add_watch(struct vnode *, struct inotify_softc *,
	    __uint32_t, __uint32_t *, struct thread *);
void	vn_inotify_revoke(struct vnode *);

/* Log an inotify event. */
#define	INOTIFY(vp, ev) do {						\
	if (__predict_false((vn_irflag_read(vp) & (VIRF_INOTIFY |	\
	    VIRF_INOTIFY_PARENT)) != 0))				\
		VOP_INOTIFY((vp), NULL, NULL, (ev), 0);			\
} while (0)

/* Log an inotify event using a specific name for the vnode. */
#define	INOTIFY_NAME_LOCK(vp, dvp, cnp, ev, lock) do {			\
	if (__predict_false((vn_irflag_read(vp) & VIRF_INOTIFY) != 0 ||	\
	    (vn_irflag_read(dvp) & VIRF_INOTIFY) != 0)) {		\
		if (lock)						\
			vn_lock((vp), LK_SHARED | LK_RETRY);		\
		VOP_INOTIFY((vp), (dvp), (cnp), (ev), 0);		\
		if (lock)						\
			VOP_UNLOCK(vp);					\
	}								\
} while (0)
#define	INOTIFY_NAME(vp, dvp, cnp, ev)					\
	INOTIFY_NAME_LOCK((vp), (dvp), (cnp), (ev), false)

extern __uint32_t inotify_rename_cookie;

#define	INOTIFY_MOVE(vp, fdvp, fcnp, tvp, tdvp, tcnp) do {		\
	if (__predict_false((vn_irflag_read(fdvp) & VIRF_INOTIFY) != 0 || \
	    (vn_irflag_read(tdvp) & VIRF_INOTIFY) != 0 ||		\
	    (vn_irflag_read(vp) & VIRF_INOTIFY) != 0)) {		\
		__uint32_t cookie;					\
									\
		cookie = atomic_fetchadd_32(&inotify_rename_cookie, 1);	\
		VOP_INOTIFY((vp), (fdvp), (fcnp), IN_MOVED_FROM, cookie); \
		VOP_INOTIFY((vp), (tdvp), (tcnp), IN_MOVED_TO, cookie);	\
	}								\
	if ((tvp) != NULL)						\
		INOTIFY_NAME_LOCK((tvp), (tdvp), (tcnp),		\
		    _IN_MOVE_DELETE, true);				\
} while (0)

#define	INOTIFY_REVOKE(vp) do {						\
	if (__predict_false((vn_irflag_read(vp) & VIRF_INOTIFY) != 0))	\
		vn_inotify_revoke((vp));				\
} while (0)

#else
#include <sys/cdefs.h>

__BEGIN_DECLS
int	inotify_init(void);
int	inotify_init1(int flags);
int	inotify_add_watch(int fd, const char *pathname, __uint32_t mask);
int	inotify_add_watch_at(int fd, int dfd, const char *pathname,
	    __uint32_t mask);
int	inotify_rm_watch(int fd, int wd);
__END_DECLS
#endif /* !_KERNEL */

#endif /* !_INOTIFY_H_ */