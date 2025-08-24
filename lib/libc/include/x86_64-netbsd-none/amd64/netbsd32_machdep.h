/*	$NetBSD: netbsd32_machdep.h,v 1.25 2019/11/27 09:16:58 rin Exp $	*/

#ifndef _MACHINE_NETBSD32_H_
#define _MACHINE_NETBSD32_H_

#include <sys/ucontext.h>
#include <compat/sys/ucontext.h>
#include <compat/sys/siginfo.h>

#include <x86/fpu.h>

/*
 * i386 ptrace constants
 * Please keep in sync with sys/arch/i386/include/ptrace.h.
 */
#define	PT32_STEP		(PT_FIRSTMACH + 0)
#define	PT32_GETREGS		(PT_FIRSTMACH + 1)
#define	PT32_SETREGS		(PT_FIRSTMACH + 2)
#define	PT32_GETFPREGS		(PT_FIRSTMACH + 3)
#define	PT32_SETFPREGS		(PT_FIRSTMACH + 4)
#define	PT32_GETXMMREGS		(PT_FIRSTMACH + 5)
#define	PT32_SETXMMREGS		(PT_FIRSTMACH + 6)
#define	PT32_GETDBREGS		(PT_FIRSTMACH + 7)
#define	PT32_SETDBREGS		(PT_FIRSTMACH + 8)
#define	PT32_SETSTEP		(PT_FIRSTMACH + 9)
#define	PT32_CLEARSTEP		(PT_FIRSTMACH + 10)
#define	PT32_GETXSTATE		(PT_FIRSTMACH + 11)
#define	PT32_SETXSTATE		(PT_FIRSTMACH + 12)

#define NETBSD32_POINTER_TYPE uint32_t
typedef	struct { NETBSD32_POINTER_TYPE i32; } netbsd32_pointer_t;

/* i386 has 32bit aligned 64bit integers */
#define NETBSD32_INT64_ALIGN __attribute__((__aligned__(4)))

typedef netbsd32_pointer_t netbsd32_sigcontextp_t;

struct netbsd32_sigcontext13 {
	uint32_t	sc_gs;
	uint32_t	sc_fs;
	uint32_t	sc_es;
	uint32_t	sc_ds;
	uint32_t	sc_edi;
	uint32_t	sc_esi;
	uint32_t	sc_ebp;
	uint32_t	sc_ebx;
	uint32_t	sc_edx;
	uint32_t	sc_ecx;
	uint32_t	sc_eax;
	/* XXX */
	uint32_t	sc_eip;
	uint32_t	sc_cs;
	uint32_t	sc_eflags;
	uint32_t	sc_esp;
	uint32_t	sc_ss;

	uint32_t	sc_onstack;	/* sigstack state to restore */
	uint32_t	sc_mask;	/* signal mask to restore (old style) */

	uint32_t	sc_trapno;	/* XXX should be above */
	uint32_t	sc_err;
};

struct netbsd32_sigcontext {
	uint32_t	sc_gs;
	uint32_t	sc_fs;
	uint32_t	sc_es;
	uint32_t	sc_ds;
	uint32_t	sc_edi;
	uint32_t	sc_esi;
	uint32_t	sc_ebp;
	uint32_t	sc_ebx;
	uint32_t	sc_edx;
	uint32_t	sc_ecx;
	uint32_t	sc_eax;
	/* XXX */
	uint32_t	sc_eip;
	uint32_t	sc_cs;
	uint32_t	sc_eflags;
	uint32_t	sc_esp;
	uint32_t	sc_ss;

	uint32_t	sc_onstack;	/* sigstack state to restore */
	uint32_t	__sc_mask13;	/* signal mask to restore (old style) */

	uint32_t	sc_trapno;	/* XXX should be above */
	uint32_t	sc_err;

	sigset_t sc_mask;		/* signal mask to restore (new style) */
};

#define sc_sp sc_esp
#define sc_fp sc_ebp
#define sc_pc sc_eip
#define sc_ps sc_eflags

struct netbsd32_sigframe_sigcontext {
	uint32_t	sf_ra;
	int32_t		sf_signum;
	int32_t		sf_code;
	uint32_t	sf_scp;
	struct netbsd32_sigcontext sf_sc;
};

struct netbsd32_sigframe_siginfo {
	uint32_t	sf_ra;
	int32_t		sf_signum;
	uint32_t	sf_sip;
	uint32_t	sf_ucp;
	siginfo32_t	sf_si;
	ucontext32_t	sf_uc;
};

struct reg32 {
	int	r_eax;
	int	r_ecx;
	int	r_edx;
	int	r_ebx;
	int	r_esp;
	int	r_ebp;
	int	r_esi;
	int	r_edi;
	int	r_eip;
	int	r_eflags;
	int	r_cs;
	int	r_ss;
	int	r_ds;
	int	r_es;
	int	r_fs;
	int	r_gs;
};

struct fpreg32 {
	char	__data[108];
};

struct dbreg32 {
	int	dr[8];
};

struct xmmregs32 {
	struct fxsave fxstate;
};
__CTASSERT(sizeof(struct xmmregs32) == 512);

struct x86_get_ldt_args32 {
	int32_t start;
	uint32_t desc;
	int32_t num;
};

struct x86_set_ldt_args32 {
	int32_t start;
	uint32_t desc;
	int32_t num;
};

struct mtrr32 {
	uint64_t base;
	uint64_t len;
	uint8_t type;
	uint8_t __pad0[3];
	int flags;
	uint32_t owner;
} __packed;

struct x86_64_get_mtrr_args32 {
	uint32_t mtrrp;
	uint32_t n;
};

struct x86_64_set_mtrr_args32 {
	uint32_t mtrrp;
	uint32_t n;
};

#define NETBSD32_MID_MACHINE MID_I386

/* Translate ptrace() PT_* request from 32-bit userland to kernel. */
int netbsd32_ptrace_translate_request(int);

int netbsd32_process_read_regs(struct lwp *, struct reg32 *);
int netbsd32_process_read_fpregs(struct lwp *, struct fpreg32 *, size_t *);
int netbsd32_process_read_dbregs(struct lwp *, struct dbreg32 *, size_t *);

int netbsd32_process_write_regs(struct lwp *, const struct reg32 *);
int netbsd32_process_write_fpregs(struct lwp *, const struct fpreg32 *, size_t);
int netbsd32_process_write_dbregs(struct lwp *, const struct dbreg32 *, size_t);

#endif /* _MACHINE_NETBSD32_H_ */