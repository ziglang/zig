/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1988, 1991 The Regents of the University of California.
 * All rights reserved.
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
 */

#ifndef _SYS_SYSENT_H_
#define	_SYS_SYSENT_H_

#include <bsm/audit.h>

struct rlimit;
struct sysent;
struct thread;
struct ksiginfo;
struct syscall_args;

enum systrace_probe_t {
	SYSTRACE_ENTRY,
	SYSTRACE_RETURN,
};

typedef	int	sy_call_t(struct thread *, void *);

typedef	void	(*systrace_probe_func_t)(struct syscall_args *,
		    enum systrace_probe_t, int);
typedef	void	(*systrace_args_func_t)(int, void *, uint64_t *, int *);

#ifdef _KERNEL
extern systrace_probe_func_t	systrace_probe_func;
extern bool			systrace_enabled;

#ifdef KDTRACE_HOOKS
#define	SYSTRACE_ENABLED()	(systrace_enabled)
#else
#define SYSTRACE_ENABLED()	(0)
#endif
#endif /* _KERNEL */

struct sysent {			/* system call table */
	sy_call_t *sy_call;	/* implementing function */
	systrace_args_func_t sy_systrace_args_func;
				/* optional argument conversion function. */
	u_int8_t sy_narg;	/* number of arguments */
	u_int8_t sy_flags;	/* General flags for system calls. */
	au_event_t sy_auevent;	/* audit event associated with syscall */
	u_int32_t sy_entry;	/* DTrace entry ID for systrace. */
	u_int32_t sy_return;	/* DTrace return ID for systrace. */
	u_int32_t sy_thrcnt;
};

/*
 * A system call is permitted in capability mode.
 */
#define	SYF_CAPENABLED	0x00000001

#define	SY_THR_FLAGMASK	0x7
#define	SY_THR_STATIC	0x1
#define	SY_THR_DRAINING	0x2
#define	SY_THR_ABSENT	0x4
#define	SY_THR_INCR	0x8

#ifdef KLD_MODULE
#define	SY_THR_STATIC_KLD	0
#else
#define	SY_THR_STATIC_KLD	SY_THR_STATIC
#endif

struct image_params;
struct proc;
struct __sigset;
struct trapframe;
struct vnode;
struct note_info_list;

struct sysentvec {
	int		sv_size;	/* number of entries */
	struct sysent	*sv_table;	/* pointer to sysent */
	int		(*sv_fixup)(uintptr_t *, struct image_params *);
					/* stack fixup function */
	void		(*sv_sendsig)(void (*)(int), struct ksiginfo *, struct __sigset *);
			    		/* send signal */
	const char 	*sv_sigcode;	/* start of sigtramp code */
	int 		*sv_szsigcode;	/* size of sigtramp code */
	int		sv_sigcodeoff;
	char		*sv_name;	/* name of binary type */
	int		(*sv_coredump)(struct thread *, struct vnode *, off_t, int);
					/* function to dump core, or NULL */
	int		sv_elf_core_osabi;
	const char	*sv_elf_core_abi_vendor;
	void		(*sv_elf_core_prepare_notes)(struct thread *,
			    struct note_info_list *, size_t *);
	int		(*sv_copyout_auxargs)(struct image_params *,
			    uintptr_t);
	int		sv_minsigstksz;	/* minimum signal stack size */
	vm_offset_t	sv_minuser;	/* VM_MIN_ADDRESS */
	vm_offset_t	sv_maxuser;	/* VM_MAXUSER_ADDRESS */
	vm_offset_t	sv_usrstack;	/* USRSTACK */
	vm_offset_t	sv_psstrings;	/* PS_STRINGS */
	size_t		sv_psstringssz;	/* PS_STRINGS size */
	int		sv_stackprot;	/* vm protection for stack */
	int		(*sv_copyout_strings)(struct image_params *,
			    uintptr_t *);
	void		(*sv_setregs)(struct thread *, struct image_params *,
			    uintptr_t);
	void		(*sv_fixlimit)(struct rlimit *, int);
	u_long		*sv_maxssiz;
	u_int		sv_flags;
	void		(*sv_set_syscall_retval)(struct thread *, int);
	int		(*sv_fetch_syscall_args)(struct thread *);
	const char	**sv_syscallnames;
	vm_offset_t	sv_timekeep_offset;
	vm_offset_t	sv_shared_page_base;
	vm_offset_t	sv_shared_page_len;
	vm_offset_t	sv_sigcode_offset;
	void		*sv_shared_page_obj;
	vm_offset_t	sv_vdso_offset;
	void		(*sv_schedtail)(struct thread *);
	void		(*sv_thread_detach)(struct thread *);
	int		(*sv_trap)(struct thread *);
	u_long		*sv_hwcap;	/* Value passed in AT_HWCAP. */
	u_long		*sv_hwcap2;	/* Value passed in AT_HWCAP2. */
	const char	*(*sv_machine_arch)(struct proc *);
	vm_offset_t	sv_fxrng_gen_offset;
	void		(*sv_onexec_old)(struct thread *td);
	int		(*sv_onexec)(struct proc *, struct image_params *);
	void		(*sv_onexit)(struct proc *);
	void		(*sv_ontdexit)(struct thread *td);
	int		(*sv_setid_allowed)(struct thread *td,
			    struct image_params *imgp);
	void		(*sv_set_fork_retval)(struct thread *);
					/* Only used on x86 */
	struct regset	**sv_regset_begin;
	struct regset	**sv_regset_end;
};

#define	SV_ILP32	0x000100	/* 32-bit executable. */
#define	SV_LP64		0x000200	/* 64-bit executable. */
#define	SV_IA32		0x004000	/* Intel 32-bit executable. */
#define	SV_AOUT		0x008000	/* a.out executable. */
#define	SV_SHP		0x010000	/* Shared page. */
#define	SV_SIGSYS	0x020000	/* SIGSYS for non-existing syscall */
#define	SV_TIMEKEEP	0x040000	/* Shared page timehands. */
#define	SV_ASLR		0x080000	/* ASLR allowed. */
#define	SV_RNG_SEED_VER	0x100000	/* random(4) reseed generation. */
#define	SV_SIG_DISCIGN	0x200000	/* Do not discard ignored signals */
#define	SV_SIG_WAITNDQ	0x400000	/* Wait does not dequeue SIGCHLD */
#define	SV_DSO_SIG	0x800000	/* Signal trampoline packed in dso */

#define	SV_ABI_MASK	0xff
#define	SV_PROC_FLAG(p, x)	((p)->p_sysent->sv_flags & (x))
#define	SV_PROC_ABI(p)		((p)->p_sysent->sv_flags & SV_ABI_MASK)
#define	SV_CURPROC_FLAG(x)	SV_PROC_FLAG(curproc, x)
#define	SV_CURPROC_ABI()	SV_PROC_ABI(curproc)
/* same as ELFOSABI_XXX, to prevent header pollution */
#define	SV_ABI_LINUX	3
#define	SV_ABI_FREEBSD 	9
#define	SV_ABI_UNDEF	255

/* sv_coredump flags */
#define	SVC_PT_COREDUMP	0x00000001	/* dump requested by ptrace(2) */
#define	SVC_NOCOMPRESS	0x00000002	/* disable compression. */
#define	SVC_ALL		0x00000004	/* dump everything */

#ifdef _KERNEL
extern struct sysentvec aout_sysvec;
extern struct sysent sysent[];
extern const char *syscallnames[];
extern struct sysent nosys_sysent;

struct nosys_args {
	register_t dummy;
};

int	nosys(struct thread *, struct nosys_args *);

#define	NO_SYSCALL (-1)

struct module;

struct syscall_module_data {
	int	(*chainevh)(struct module *, int, void *); /* next handler */
	void	*chainarg;		/* arg for next event handler */
	int	*offset;		/* offset into sysent */
	struct sysent *new_sysent;	/* new sysent */
	struct sysent old_sysent;	/* old sysent */
	int	flags;			/* flags for syscall_register */
};

/* separate initialization vector so it can be used in a substructure */
#define SYSENT_INIT_VALS(_syscallname) {			\
	.sy_narg = (sizeof(struct _syscallname ## _args )	\
	    / sizeof(register_t)),				\
	.sy_call = (sy_call_t *)&sys_##_syscallname,		\
	.sy_auevent = SYS_AUE_##_syscallname,			\
	.sy_systrace_args_func = NULL,				\
	.sy_entry = 0,						\
	.sy_return = 0,						\
	.sy_flags = 0,						\
	.sy_thrcnt = 0						\
}

#define	MAKE_SYSENT(syscallname)				\
static struct sysent syscallname##_sysent = SYSENT_INIT_VALS(syscallname);

#define	MAKE_SYSENT_COMPAT(syscallname)				\
static struct sysent syscallname##_sysent = {			\
	(sizeof(struct syscallname ## _args )			\
	    / sizeof(register_t)),				\
	(sy_call_t *)& syscallname,				\
	SYS_AUE_##syscallname					\
}

#define SYSCALL_MODULE(name, offset, new_sysent, evh, arg)	\
static struct syscall_module_data name##_syscall_mod = {	\
	evh, arg, offset, new_sysent, { 0, NULL, AUE_NULL }	\
};								\
								\
static moduledata_t name##_mod = {				\
	"sys/" #name,						\
	syscall_module_handler,					\
	&name##_syscall_mod					\
};								\
DECLARE_MODULE(name, name##_mod, SI_SUB_SYSCALLS, SI_ORDER_MIDDLE)

#define	SYSCALL_MODULE_HELPER(syscallname)			\
static int syscallname##_syscall = SYS_##syscallname;		\
MAKE_SYSENT(syscallname);					\
SYSCALL_MODULE(syscallname,					\
    & syscallname##_syscall, & syscallname##_sysent,		\
    NULL, NULL)

#define	SYSCALL_MODULE_PRESENT(syscallname)				\
	(sysent[SYS_##syscallname].sy_call != (sy_call_t *)lkmnosys &&	\
	sysent[SYS_##syscallname].sy_call != (sy_call_t *)lkmressys)

/*
 * Syscall registration helpers with resource allocation handling.
 */
struct syscall_helper_data {
	struct sysent new_sysent;
	struct sysent old_sysent;
	int syscall_no;
	int registered;
};
#define SYSCALL_INIT_HELPER_F(syscallname, flags) {		\
    .new_sysent = {						\
	.sy_narg = (sizeof(struct syscallname ## _args )	\
	    / sizeof(register_t)),				\
	.sy_call = (sy_call_t *)& sys_ ## syscallname,		\
	.sy_auevent = SYS_AUE_##syscallname,			\
	.sy_flags = (flags)					\
    },								\
    .syscall_no = SYS_##syscallname				\
}
#define SYSCALL_INIT_HELPER_COMPAT_F(syscallname, flags) {	\
    .new_sysent = {						\
	.sy_narg = (sizeof(struct syscallname ## _args )	\
	    / sizeof(register_t)),				\
	.sy_call = (sy_call_t *)& syscallname,			\
	.sy_auevent = SYS_AUE_##syscallname,			\
	.sy_flags = (flags)					\
    },								\
    .syscall_no = SYS_##syscallname				\
}
#define SYSCALL_INIT_HELPER(syscallname)			\
    SYSCALL_INIT_HELPER_F(syscallname, 0)
#define SYSCALL_INIT_HELPER_COMPAT(syscallname)			\
    SYSCALL_INIT_HELPER_COMPAT_F(syscallname, 0)
#define SYSCALL_INIT_LAST {					\
    .syscall_no = NO_SYSCALL					\
}

int	syscall_module_handler(struct module *mod, int what, void *arg);
int	syscall_helper_register(struct syscall_helper_data *sd, int flags);
int	syscall_helper_unregister(struct syscall_helper_data *sd);
/* Implementation, exposed for COMPAT code */
int	kern_syscall_register(struct sysent *sysents, int *offset,
	    struct sysent *new_sysent, struct sysent *old_sysent, int flags);
int	kern_syscall_deregister(struct sysent *sysents, int offset,
	    const struct sysent *old_sysent);
int	kern_syscall_module_handler(struct sysent *sysents,
	    struct module *mod, int what, void *arg);
int	kern_syscall_helper_register(struct sysent *sysents,
	    struct syscall_helper_data *sd, int flags);
int	kern_syscall_helper_unregister(struct sysent *sysents,
	    struct syscall_helper_data *sd);

struct proc;
const char *syscallname(struct proc *p, u_int code);

/* Special purpose system call functions. */
struct nosys_args;

int	lkmnosys(struct thread *, struct nosys_args *);
int	lkmressys(struct thread *, struct nosys_args *);

int	syscall_thread_enter(struct thread *td, struct sysent **se);
void	syscall_thread_exit(struct thread *td, struct sysent *se);

int shared_page_alloc(int size, int align);
int shared_page_fill(int size, int align, const void *data);
void shared_page_write(int base, int size, const void *data);
void exec_sysvec_init(void *param);
void exec_sysvec_init_secondary(struct sysentvec *sv, struct sysentvec *sv2);
void exec_inittk(void);

void exit_onexit(struct proc *p);
void exec_free_abi_mappings(struct proc *p);
void exec_onexec_old(struct thread *td);

#define INIT_SYSENTVEC(name, sv)					\
    SYSINIT(name, SI_SUB_EXEC, SI_ORDER_ANY,				\
	(sysinit_cfunc_t)exec_sysvec_init, sv);

#endif /* _KERNEL */

#endif /* !_SYS_SYSENT_H_ */