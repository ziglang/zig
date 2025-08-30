/*	$NetBSD: exec.h,v 1.161 2021/11/26 08:06:12 ryo Exp $	*/

/*-
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)exec.h	8.4 (Berkeley) 2/19/95
 */

/*-
 * Copyright (c) 1993 Theo de Raadt.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*-
 * Copyright (c) 1994 Christopher G. Demetriou
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
 *	@(#)exec.h	8.4 (Berkeley) 2/19/95
 */

#ifndef _SYS_EXEC_H_
#define _SYS_EXEC_H_

struct pathbuf; /* from namei.h */


/*
 * The following structure is found at the top of the user stack of each
 * user process. The ps program uses it to locate argv and environment
 * strings. Programs that wish ps to display other information may modify
 * it; normally ps_argvstr points to argv[0], and ps_nargvstr is the same
 * as the program's argc. The fields ps_envstr and ps_nenvstr are the
 * equivalent for the environment.
 */
struct ps_strings {
	char	**ps_argvstr;	/* first of 0 or more argument strings */
	int	ps_nargvstr;	/* the number of argument strings */
	char	**ps_envstr;	/* first of 0 or more environment strings */
	int	ps_nenvstr;	/* the number of environment strings */
};

#ifdef _KERNEL
struct ps_strings32 {
	uint32_t	ps_argvstr;	/* first of 0 or more argument strings */
	int32_t		ps_nargvstr;	/* the number of argument strings */
	uint32_t	ps_envstr;	/* first of 0 or more environment strings */
	int32_t		ps_nenvstr;	/* the number of environment strings */
};
#endif

#ifdef _KERNEL
/*
 * the following structures allow execve() to put together processes
 * in a more extensible and cleaner way.
 *
 * the exec_package struct defines an executable being execve()'d.
 * it contains the header, the vmspace-building commands, the vnode
 * information, and the arguments associated with the newly-execve'd
 * process.
 *
 * the exec_vmcmd struct defines a command description to be used
 * in creating the new process's vmspace.
 */

#include <sys/uio.h>
#include <sys/rwlock.h>

struct lwp;
struct proc;
struct exec_package;
struct vnode;
struct coredump_iostate;

typedef int (*exec_makecmds_fcn)(struct lwp *, struct exec_package *);

struct execsw {
	u_int	es_hdrsz;		/* size of header for this format */
	exec_makecmds_fcn es_makecmds;	/* function to setup vmcmds */
	union {				/* probe function */
		int (*elf_probe_func)(struct lwp *,
			struct exec_package *, void *, char *, vaddr_t *);
		int (*ecoff_probe_func)(struct lwp *, struct exec_package *);
	} u;
	struct  emul *es_emul;		/* os emulation */
	int	es_prio;		/* entry priority */
	int	es_arglen;		/* Extra argument size in words */
					/* Copy arguments on the new stack */
	int	(*es_copyargs)(struct lwp *, struct exec_package *,
			struct ps_strings *, char **, void *);
					/* Set registers before execution */
	void	(*es_setregs)(struct lwp *, struct exec_package *, vaddr_t);
					/* Dump core */
	int	(*es_coredump)(struct lwp *, struct coredump_iostate *);
	int	(*es_setup_stack)(struct lwp *, struct exec_package *);
};

#define EXECSW_PRIO_ANY		0x000	/* default, no preference */
#define EXECSW_PRIO_FIRST	0x001	/* this should be among first */
#define EXECSW_PRIO_LAST	0x002	/* this should be among last */

/* exec vmspace-creation command set; see below */
struct exec_vmcmd_set {
	u_int	evs_cnt;
	u_int	evs_used;
	struct	exec_vmcmd *evs_cmds;
};

#define	EXEC_DEFAULT_VMCMD_SETSIZE	9	/* # of cmds in set to start */
struct exec_fakearg {
	char *fa_arg;
	size_t fa_len;
};

struct exec_package {
	const char *ep_kname;		/* kernel-side copy of file's name */
	char	*ep_resolvedname;	/* fully resolved path from namei */
	int	ep_xfd;			/* fexecve file descriptor */
	void	*ep_hdr;		/* file's exec header */
	u_int	ep_hdrlen;		/* length of ep_hdr */
	u_int	ep_hdrvalid;		/* bytes of ep_hdr that are valid */
	struct	exec_vmcmd_set ep_vmcmds;  /* vmcmds used to build vmspace */
	struct	vnode *ep_vp;		/* executable's vnode */
	struct	vattr *ep_vap;		/* executable's attributes */
	vaddr_t	ep_taddr;		/* process's text address */
	vsize_t	ep_tsize;		/* size of process's text */
	vaddr_t	ep_daddr;		/* process's data(+bss) address */
	vsize_t	ep_dsize;		/* size of process's data(+bss) */
	vaddr_t	ep_maxsaddr;		/* proc's max stack addr ("top") */
	vaddr_t	ep_minsaddr;		/* proc's min stack addr ("bottom") */
	vsize_t	ep_ssize;		/* size of process's stack */
	vaddr_t	ep_entry;		/* process's entry point */
	vaddr_t	ep_entryoffset;		/* offset to entry point */
	vaddr_t	ep_vm_minaddr;		/* bottom of process address space */
	vaddr_t	ep_vm_maxaddr;		/* top of process address space */
	u_int	ep_flags;		/* flags; see below. */
	size_t	ep_fa_len;		/* byte size of ep_fa */
	struct exec_fakearg *ep_fa;	/* a fake args vector for scripts */
	int	ep_fd;			/* a file descriptor we're holding */
	void	*ep_emul_arg;		/* emulation argument */
	const struct	execsw *ep_esch;/* execsw entry */
	struct vnode *ep_emul_root;     /* base of emulation filesystem */
	struct vnode *ep_interp;        /* vnode of (elf) interpeter */
	uint32_t ep_pax_flags;		/* pax flags */
	void	(*ep_emul_arg_free)(void *);
					/* free ep_emul_arg */
	uint32_t ep_osversion;		/* OS version */
	char	ep_machine_arch[12];	/* from MARCH note */
};
#define	EXEC_INDIR	0x0001		/* script handling already done */
#define	EXEC_HASFD	0x0002		/* holding a shell script */
#define	EXEC_HASARGL	0x0004		/* has fake args vector */
#define	EXEC_SKIPARG	0x0008		/* don't copy user-supplied argv[0] */
#define	EXEC_DESTR	0x0010		/* destructive ops performed */
#define	EXEC_32		0x0020		/* 32-bit binary emulation */
#define	EXEC_FORCEAUX	0x0040		/* always use ELF AUX vector */
#define	EXEC_TOPDOWN_VM	0x0080		/* may use top-down VM layout */
#define	EXEC_FROM32	0x0100		/* exec'ed from 32-bit binary */

struct exec_vmcmd {
	int	(*ev_proc)(struct lwp *, struct exec_vmcmd *);
				/* procedure to run for region of vmspace */
	vsize_t	ev_len;		/* length of the segment to map */
	vaddr_t	ev_addr;	/* address in the vmspace to place it at */
	struct	vnode *ev_vp;	/* vnode pointer for the file w/the data */
	vsize_t	ev_offset;	/* offset in the file for the data */
	u_int	ev_prot;	/* protections for segment */
	int	ev_flags;
#define	VMCMD_RELATIVE	0x0001	/* ev_addr is relative to base entry */
#define	VMCMD_BASE	0x0002	/* marks a base entry */
#define	VMCMD_FIXED	0x0004	/* entry must be mapped at ev_addr */
#define	VMCMD_STACK	0x0008	/* entry is for a stack */
};

/*
 * functions used either by execve() or the various CPU-dependent execve()
 * hooks.
 */
vaddr_t	exec_vm_minaddr		(vaddr_t);
void	kill_vmcmd		(struct exec_vmcmd **);
int	exec_makecmds		(struct lwp *, struct exec_package *);
int	exec_runcmds		(struct lwp *, struct exec_package *);
void	vmcmdset_extend		(struct exec_vmcmd_set *);
void	kill_vmcmds		(struct exec_vmcmd_set *);
int	vmcmd_map_pagedvn	(struct lwp *, struct exec_vmcmd *);
int	vmcmd_map_readvn	(struct lwp *, struct exec_vmcmd *);
int	vmcmd_readvn		(struct lwp *, struct exec_vmcmd *);
int	vmcmd_map_zero		(struct lwp *, struct exec_vmcmd *);
int	copyargs		(struct lwp *, struct exec_package *,
				    struct ps_strings *, char **, void *);
int	copyin_psstrings	(struct proc *, struct ps_strings *);
int	copy_procargs		(struct proc *, int, size_t *,
    int (*)(void *, const void *, size_t, size_t), void *);
void	setregs			(struct lwp *, struct exec_package *, vaddr_t);
int	check_veriexec		(struct lwp *, struct vnode *,
				     struct exec_package *, int);
int	check_exec		(struct lwp *, struct exec_package *,
				     struct pathbuf *, char **);
int	exec_init		(int);
int	exec_read		(struct lwp *, struct vnode *, u_long off,
				    void *, size_t, int);
int	exec_setup_stack	(struct lwp *, struct exec_package *);

void	exec_free_emul_arg	(struct exec_package *);


/*
 * Machine dependent functions
 */
struct core;
struct core32;
int	cpu_coredump(struct lwp *, struct coredump_iostate *, struct core *);
int	cpu_coredump32(struct lwp *, struct coredump_iostate *, struct core32 *);

int	exec_add(struct execsw *, int);
int	exec_remove(struct execsw *, int);
int	exec_sigcode_alloc(const struct emul *);
void	exec_sigcode_free(const struct emul *);

void	new_vmcmd(struct exec_vmcmd_set *,
		    int (*)(struct lwp *, struct exec_vmcmd *),
		    vsize_t, vaddr_t, struct vnode *, u_long, u_int, int);
#define	NEW_VMCMD(evsp,lwp,len,addr,vp,offset,prot) \
	new_vmcmd(evsp,lwp,len,addr,vp,offset,prot,0)
#define	NEW_VMCMD2(evsp,lwp,len,addr,vp,offset,prot,flags) \
	new_vmcmd(evsp,lwp,len,addr,vp,offset,prot,flags)

typedef	int (*execve_fetch_element_t)(char * const *, size_t, char **);
int	execve1(struct lwp *, bool, const char *, int, char * const *,
    char * const *, execve_fetch_element_t);

struct posix_spawn_file_actions;
struct posix_spawnattr;
int	check_posix_spawn	(struct lwp *);
void	posix_spawn_fa_free(struct posix_spawn_file_actions *, size_t);
int	do_posix_spawn(struct lwp *, pid_t *, bool *, const char *,
    struct posix_spawn_file_actions *, struct posix_spawnattr *,
    char *const *, char *const *, execve_fetch_element_t);
int      exec_makepathbuf(struct lwp *, const char *, enum uio_seg,
    struct pathbuf **, size_t *);

extern int	maxexec;
extern krwlock_t exec_lock;

/*
 * Utility functions
 */
void emul_find_root(struct lwp *, struct exec_package *);
int emul_find_interp(struct lwp *, struct exec_package *, const char *);

#endif /* _KERNEL */

#endif /* !_SYS_EXEC_H_ */