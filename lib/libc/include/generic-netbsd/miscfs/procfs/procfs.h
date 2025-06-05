/*	$NetBSD: procfs.h,v 1.82.4.1 2024/04/18 18:22:10 martin Exp $	*/

/*
 * Copyright (c) 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Jan-Simon Pendry.
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
 *	@(#)procfs.h	8.9 (Berkeley) 5/14/95
 */

/*
 * Copyright (c) 1993 Jan-Simon Pendry
 *
 * This code is derived from software contributed to Berkeley by
 * Jan-Simon Pendry.
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
 *	@(#)procfs.h	8.9 (Berkeley) 5/14/95
 */

/* This also pulls in __HAVE_PROCFS_MACHDEP */
#include <sys/ptrace.h>

#ifdef _KERNEL
#include <sys/proc.h>

/*
 * The different types of node in a procfs filesystem
 */
typedef enum {
	PFSauxv,	/* ELF Auxiliary Vector */
	PFSchroot,	/* the process's current root directory */
	PFScmdline,	/* process command line args */
	PFScpuinfo,	/* CPU info (if -o linux) */
	PFScpustat,	/* status info (if -o linux) */
	PFScurproc,	/* symbolic link for curproc */
	PFScwd,		/* the process's current working directory */
	PFSdevices,	/* major/device name mappings (if -o linux) */
	PFSemul,	/* the process's emulation */
	PFSenviron,	/* process environment */
	PFSexe,		/* symlink to the executable file */
	PFSfd,		/* a directory containing the processes open fd's */
	PFSfile,	/* the executable file */
	PFSfpregs,	/* the process's FP register set */
	PFSloadavg,	/* load average (if -o linux) */
	PFSlimit,	/* resource limits */
	PFSmap,		/* memory map */
	PFSmaps,	/* memory map, Linux style (if -o linux) */
	PFSmem,		/* the process's memory image */
	PFSmeminfo,	/* system memory info (if -o linux) */
	PFSmounts,	/* mounted filesystems (if -o linux) */
	PFSnote,	/* process notifier */
	PFSnotepg,	/* process group notifier */
	PFSproc,	/* a process-specific sub-directory */
	PFSregs,	/* the process's register set */
	PFSroot,	/* the filesystem root */
	PFSself,	/* like curproc, but this is the Linux name */
	PFSstat,	/* process status (if -o linux) */
	PFSstatm,	/* process memory info (if -o linux) */
	PFSstatus,	/* process status */
	PFStask,	/* task subdirector (if -o linux) */
	PFSuptime,	/* elapsed time since (if -o linux) */
	PFSversion,	/* kernel version (if -o linux) */
#ifdef __HAVE_PROCFS_MACHDEP
	PROCFS_MACHDEP_NODE_TYPES
#endif
	PFSlast,	/* track number of types */
} pfstype;

/*
 * control data for the proc file system.
 */
struct pfskey {
	pfstype		pk_type;	/* type of procfs node */
	pid_t		pk_pid;		/* associated process */
	int		pk_fd;		/* associated fd if not -1 */
};
struct pfsnode {
	LIST_ENTRY(pfsnode) pfs_hash;	/* per pid hash list */
	struct vnode	*pfs_vnode;	/* vnode associated with this pfsnode */
	struct mount	*pfs_mount;	/* mount associated with this pfsnode */
	struct pfskey	pfs_key;
#define pfs_type pfs_key.pk_type
#define pfs_pid pfs_key.pk_pid
#define pfs_fd pfs_key.pk_fd
	mode_t		pfs_mode;	/* mode bits for stat() */
	u_long		pfs_flags;	/* open flags */
	uint64_t	pfs_fileno;	/* unique file id */
};

#define PROCFS_NOTELEN	64	/* max length of a note (/proc/$pid/note) */
#define PROCFS_MAXNAMLEN	255

#endif /* _KERNEL */

struct procfs_args {
	int version;
	int flags;
};

#define PROCFS_ARGSVERSION	1

#define PROCFSMNT_LINUXCOMPAT	0x01

#define PROCFSMNT_BITS "\177\20" \
    "b\00linuxcompat\0"

/*
 * Kernel stuff follows
 */
#ifdef _KERNEL
#define CNEQ(cnp, s, len) \
	 ((cnp)->cn_namelen == (len) && \
	  (memcmp((s), (cnp)->cn_nameptr, (len)) == 0))

#define UIO_MX 32

static __inline ino_t
procfs_fileno(pid_t _pid, pfstype _type, int _fd)
{
	ino_t _ino;
	switch (_type) {
	case PFSroot:
		return 2;
	case PFScurproc:
		return 3;
	case PFSself:
		return 4;
	default:
		_ino = _pid + 1;
		if (_fd != -1)
			_ino = _ino << 32 | _fd;
		return _ino * PFSlast + _type;
	}
}

#define PROCFS_FILENO(pid, type, fd) procfs_fileno(pid, type, fd)

#define PROCFS_TYPE(type)	((type) % PFSlast)

struct procfsmount {
	int pmnt_flags;
};

#define VFSTOPROC(mp)	((struct procfsmount *)(mp)->mnt_data)

/*
 * Convert between pfsnode vnode
 */
#define VTOPFS(vp)	((struct pfsnode *)(vp)->v_data)
#define PFSTOV(pfs)	((pfs)->pfs_vnode)

typedef struct vfs_namemap vfs_namemap_t;
struct vfs_namemap {
	const char *nm_name;
	int nm_val;
};

int vfs_getuserstr(struct uio *, char *, int *);
const vfs_namemap_t *vfs_findname(const vfs_namemap_t *, const char *, int);

struct mount;

struct proc *procfs_proc_find(struct mount *, pid_t);
bool procfs_use_linux_compat(struct mount *);

static inline bool
procfs_proc_is_linux_compat(void)
{
	const char *emulname = curlwp->l_proc->p_emul->e_name;
	return (strncmp(emulname, "linux", 5) == 0);
}

int procfs_proc_lock(struct mount *, int, struct proc **, int);
void procfs_proc_unlock(struct proc *);
int procfs_allocvp(struct mount *, struct vnode **, pid_t, pfstype, int);
int procfs_donote(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_doregs(struct lwp *, struct lwp *, struct pfsnode *,
    struct uio *);
int procfs_dofpregs(struct lwp *, struct lwp *, struct pfsnode *,
    struct uio *);
int procfs_domem(struct lwp *, struct lwp *, struct pfsnode *,
    struct uio *);
int procfs_do_pid_stat(struct lwp *, struct lwp *, struct pfsnode *,
    struct uio *);
int procfs_dostatus(struct lwp *, struct lwp *, struct pfsnode *,
    struct uio *);
int procfs_domap(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *, int);
int procfs_doprocargs(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *, int);
int procfs_domeminfo(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_dodevices(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_docpuinfo(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_docpustat(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_doloadavg(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_do_pid_statm(struct lwp *, struct lwp *, struct pfsnode *,
    struct uio *);
int procfs_dofd(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_douptime(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_domounts(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_doemul(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_doversion(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_doauxv(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);
int procfs_dolimit(struct lwp *, struct proc *, struct pfsnode *,
    struct uio *);

void procfs_hashrem(struct pfsnode *);
int procfs_getfp(struct pfsnode *, struct proc *, struct file **);

/* functions to check whether or not files should be displayed */
int procfs_validauxv(struct lwp *, struct mount *);
int procfs_validfile(struct lwp *, struct mount *);
int procfs_validfpregs(struct lwp *, struct mount *);
int procfs_validregs(struct lwp *, struct mount *);
int procfs_validmap(struct lwp *, struct mount *);

int procfs_rw(void *);

int procfs_getcpuinfstr(char *, size_t *);

#define PROCFS_LOCKED	0x01
#define PROCFS_WANT	0x02

extern int (**procfs_vnodeop_p)(void *);
extern struct vfsops procfs_vfsops;

int	procfs_root(struct mount *, int, struct vnode **);

#ifdef __HAVE_PROCFS_MACHDEP
struct vattr;

void	procfs_machdep_allocvp(struct vnode *);
int	procfs_machdep_rw(struct lwp *, struct lwp *, struct pfsnode *,
	    struct uio *);
int	procfs_machdep_getattr(struct vnode *, struct vattr *, struct proc *);
#endif

#endif /* _KERNEL */