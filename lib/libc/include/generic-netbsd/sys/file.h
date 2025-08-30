/*	$NetBSD: file.h,v 1.88 2021/09/19 15:51:27 thorpej Exp $	*/

/*-
 * Copyright (c) 2009 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Andrew Doran.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright (c) 1982, 1986, 1989, 1993
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
 * 3. Neither the name of the University nor the names of its contributors
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
 *	@(#)file.h	8.3 (Berkeley) 1/9/95
 */

#ifndef _SYS_FILE_H_
#define	_SYS_FILE_H_

#include <sys/fcntl.h>
#include <sys/unistd.h>

#if defined(_KERNEL) || defined(_KMEMUSER)
#include <sys/queue.h>
#include <sys/mutex.h>
#include <sys/condvar.h>

struct proc;
struct lwp;
struct uio;
struct iovec;
struct stat;
struct knote;
struct uvm_object;

struct fileops {
	const char *fo_name;
	int	(*fo_read)	(struct file *, off_t *, struct uio *,
				    kauth_cred_t, int);
	int	(*fo_write)	(struct file *, off_t *, struct uio *,
				    kauth_cred_t, int);
	int	(*fo_ioctl)	(struct file *, u_long, void *);
	int	(*fo_fcntl)	(struct file *, u_int, void *);
	int	(*fo_poll)	(struct file *, int);
	int	(*fo_stat)	(struct file *, struct stat *);
	int	(*fo_close)	(struct file *);
	int	(*fo_kqfilter)	(struct file *, struct knote *);
	void	(*fo_restart)	(struct file *);
	int	(*fo_mmap)	(struct file *, off_t *, size_t, int, int *,
				 int *, struct uvm_object **, int *);
	int	(*fo_seek)	(struct file *, off_t, int, off_t *, int);
};

union file_data {
	struct vnode *fd_vp;		// DTYPE_VNODE
	struct socket *fd_so;		// DTYPE_SOCKET
	struct pipe *fd_pipe;		// DTYPE_PIPE
	struct kqueue *fd_kq;		// DTYPE_KQUEUE
	struct eventfd *fd_eventfd;	// DTYPE_EVENTFD
	struct timerfd *fd_timerfd;	// DTYPE_TIMERFD
	void *fd_data;			// DTYPE_MISC
	struct audio_file *fd_audioctx;	// DTYPE_MISC (audio)
	struct pad_softc *fd_pad;	// DTYPE_MISC (pad)
	int fd_devunit;			// DTYPE_MISC (tap)
	struct bpf_d *fd_bpf;		// DTYPE_MISC (bpf)
	struct fcrypt *fd_fcrypt;	// DTYPE_CRYPTO is not used
	struct mqueue *fd_mq;		// DTYPE_MQUEUE
	struct ksem *fd_ks;		// DTYPE_SEM
	struct iscsifd *fd_iscsi;	// DTYPE_MISC (iscsi)
};

/*
 * Kernel file descriptor.  One entry for each open kernel vnode and
 * socket.
 *
 * This structure is exported via the KERN_FILE sysctl.
 * Only add members to the end, do not delete them.
 *
 * Note: new code should not use KERN_FILE; use KERN_FILE2 instead,
 * which exports struct kinfo_file instead; struct kinfo_file is
 * declared in sys/sysctl.h and is meant to be ABI-stable.
 */
struct file {
	off_t		f_offset;	/* first, is 64-bit */
	kauth_cred_t 	f_cred;		/* creds associated with descriptor */
	const struct fileops *f_ops;
	union file_data	f_undata;	/* descriptor data, e.g. vnode/socket */
	LIST_ENTRY(file) f_list;	/* list of active files */
	kmutex_t	f_lock;		/* lock on structure */
	int		f_flag;		/* see fcntl.h */
	u_int		f_marker;	/* traversal marker (sysctl) */
	u_int		f_type;		/* descriptor type */
	u_int		f_advice;	/* access pattern hint; UVM_ADV_* */
	u_int		f_count;	/* reference count */
	u_int		f_msgcount;	/* references from message queue */
	u_int		f_unpcount;	/* deferred close: see uipc_usrreq.c */
	SLIST_ENTRY(file) f_unplist;	/* deferred close: see uipc_usrreq.c */
};

#define f_vnode		f_undata.fd_vp
#define f_socket	f_undata.fd_so
#define f_pipe		f_undata.fd_pipe
#define f_kqueue	f_undata.fd_kq
#define f_data		f_undata.fd_data
#define f_mqueue	f_undata.fd_mq
#define f_ksem		f_undata.fd_ks
#define f_eventfd	f_undata.fd_eventfd
#define f_timerfd	f_undata.fd_timerfd

#define f_rndctx	f_undata.fd_rndctx
#define f_audioctx	f_undata.fd_audioctx
#define f_pad		f_undata.fd_pad
#define f_devunit	f_undata.fd_devunit
#define f_bpf		f_undata.fd_bpf
#define f_fcrypt	f_undata.fd_fcrypt
#define f_iscsi		f_undata.fd_iscsi
#endif /* _KERNEL || _KMEMUSER */

/*
 * Descriptor types.
 */

#define	DTYPE_VNODE	1		/* file */
#define	DTYPE_SOCKET	2		/* communications endpoint */
#define	DTYPE_PIPE	3		/* pipe */
#define	DTYPE_KQUEUE	4		/* event queue */
#define	DTYPE_MISC	5		/* misc file descriptor type */
#define	DTYPE_CRYPTO	6		/* crypto */
#define	DTYPE_MQUEUE	7		/* message queue */
#define	DTYPE_SEM	8		/* semaphore */
#define	DTYPE_EVENTFD	9		/* eventfd */
#define	DTYPE_TIMERFD	10		/* timerfd */

#define DTYPE_NAMES	\
    "0", "file", "socket", "pipe", "kqueue", "misc", "crypto", "mqueue", \
    "semaphore", "eventfd", "timerfd"

#ifdef _KERNEL

/*
 * Flags for fo_read and fo_write and do_fileread/write/v
 */
#define	FOF_UPDATE_OFFSET	0x0001	/* update the file offset */
#define	FOF_IOV_SYSSPACE	0x0100	/* iov structure in kernel memory */

LIST_HEAD(filelist, file);
extern struct filelist	filehead;	/* head of list of open files */
extern u_int		maxfiles;	/* kernel limit on # of open files */

extern const struct fileops vnops;	/* vnode operations for files */

int	dofileread(int, struct file *, void *, size_t,
	    off_t *, int, register_t *);
int	dofilewrite(int, struct file *, const void *,
	    size_t, off_t *, int, register_t *);

int	do_filereadv(int, const struct iovec *, int, off_t *,
	    int, register_t *);
int	do_filewritev(int, const struct iovec *, int, off_t *,
	    int, register_t *);

int	fsetown(pid_t *, u_long, const void *);
int	fgetown(pid_t, u_long, void *);
void	fownsignal(pid_t, int, int, int, void *);

/* Commonly used fileops */
int	fnullop_fcntl(struct file *, u_int, void *);
int	fnullop_poll(struct file *, int);
int	fnullop_kqfilter(struct file *, struct knote *);
int	fbadop_read(struct file *, off_t *, struct uio *, kauth_cred_t, int);
int	fbadop_write(struct file *, off_t *, struct uio *, kauth_cred_t, int);
int	fbadop_ioctl(struct file *, u_long, void *);
int	fbadop_close(struct file *);
int	fbadop_stat(struct file *, struct stat *);
void	fnullop_restart(struct file *);

#endif /* _KERNEL */

#endif /* _SYS_FILE_H_ */