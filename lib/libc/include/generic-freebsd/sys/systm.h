/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1988, 1991, 1993
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
 *	@(#)systm.h	8.7 (Berkeley) 3/29/95
 */

#ifndef _SYS_SYSTM_H_
#define	_SYS_SYSTM_H_

#include <sys/types.h>
#include <sys/callout.h>
#include <sys/kassert.h>
#include <sys/queue.h>
#include <sys/stdint.h>		/* for people using printf mainly */
#include <machine/atomic.h>
#include <machine/cpufunc.h>

__NULLABILITY_PRAGMA_PUSH

#ifdef _KERNEL
extern int cold;		/* nonzero if we are doing a cold boot */
extern int suspend_blocked;	/* block suspend due to pending shutdown */
extern int rebooting;		/* kern_reboot() has been called. */
extern const char version[];	/* system version */
extern const char compiler_version[];	/* compiler version */
extern const char copyright[];	/* system copyright */
extern int kstack_pages;	/* number of kernel stack pages */

extern u_long pagesizes[];	/* supported page sizes */
extern long physmem;		/* physical memory */
extern long realmem;		/* 'real' memory */

extern char *rootdevnames[2];	/* names of possible root devices */

extern int boothowto;		/* reboot flags, from console subsystem */
extern int bootverbose;		/* nonzero to print verbose messages */

extern int maxusers;		/* system tune hint */
extern int ngroups_max;		/* max # of supplemental groups */
extern int vm_guest;		/* Running as virtual machine guest? */

extern u_long maxphys;		/* max raw I/O transfer size */

/*
 * Detected virtual machine guest types. The intention is to expand
 * and/or add to the VM_GUEST_VM type if specific VM functionality is
 * ever implemented (e.g. vendor-specific paravirtualization features).
 * Keep in sync with vm_guest_sysctl_names[].
 */
enum VM_GUEST { VM_GUEST_NO = 0, VM_GUEST_VM, VM_GUEST_XEN, VM_GUEST_HV,
		VM_GUEST_VMWARE, VM_GUEST_KVM, VM_GUEST_BHYVE, VM_GUEST_VBOX,
		VM_GUEST_PARALLELS, VM_GUEST_NVMM, VM_LAST };

#endif /* KERNEL */

/*
 * Align variables.
 */
#define	__read_mostly		__section(".data.read_mostly")
#define	__read_frequently	__section(".data.read_frequently")
#define	__exclusive_cache_line	__aligned(CACHE_LINE_SIZE) \
				    __section(".data.exclusive_cache_line")
#if defined(_STANDALONE)
struct ucred;
#endif

#ifdef _KERNEL
#include <sys/param.h>		/* MAXCPU */
#include <sys/pcpu.h>		/* curthread */
#include <sys/kpilite.h>

/*
 * If we have already panic'd and this is the thread that called
 * panic(), then don't block on any mutexes but silently succeed.
 * Otherwise, the kernel will deadlock since the scheduler isn't
 * going to run the thread that holds any lock we need.
 */
#define	SCHEDULER_STOPPED_TD(td)  ({					\
	MPASS((td) == curthread);					\
	__predict_false((td)->td_stopsched);				\
})
#define	SCHEDULER_STOPPED() SCHEDULER_STOPPED_TD(curthread)

extern const int osreldate;

extern const void *zero_region;	/* address space maps to a zeroed page	*/

extern int unmapped_buf_allowed;

#ifdef __LP64__
#define	IOSIZE_MAX		iosize_max()
#define	DEVFS_IOSIZE_MAX	devfs_iosize_max()
#else
#define	IOSIZE_MAX		SSIZE_MAX
#define	DEVFS_IOSIZE_MAX	SSIZE_MAX
#endif

/*
 * General function declarations.
 */

struct inpcb;
struct lock_object;
struct malloc_type;
struct mtx;
struct proc;
struct socket;
struct thread;
struct tty;
struct ucred;
struct uio;
struct _jmp_buf;
struct trapframe;
struct eventtimer;

int	setjmp(struct _jmp_buf *) __returns_twice;
void	longjmp(struct _jmp_buf *, int) __dead2;
int	dumpstatus(vm_offset_t addr, off_t count);
int	nullop(void);
int	eopnotsupp(void);
int	ureadc(int, struct uio *);
void	hashdestroy(void *, struct malloc_type *, u_long);
void	*hashinit(int count, struct malloc_type *type, u_long *hashmask);
void	*hashinit_flags(int count, struct malloc_type *type,
    u_long *hashmask, int flags);
#define	HASH_NOWAIT	0x00000001
#define	HASH_WAITOK	0x00000002

void	*phashinit(int count, struct malloc_type *type, u_long *nentries);
void	*phashinit_flags(int count, struct malloc_type *type, u_long *nentries,
    int flags);

void	cpu_flush_dcache(void *, size_t);
void	cpu_rootconf(void);
void	critical_enter_KBI(void);
void	critical_exit_KBI(void);
void	critical_exit_preempt(void);
void	init_param1(void);
void	init_param2(long physpages);
void	init_static_kenv(char *, size_t);
void	tablefull(const char *);

/*
 * Allocate per-thread "current" state in the linuxkpi
 */
extern int (*lkpi_alloc_current)(struct thread *, int);
int linux_alloc_current_noop(struct thread *, int);

#if (defined(KLD_MODULE) && !defined(KLD_TIED)) || defined(KTR_CRITICAL) || !defined(_KERNEL) || defined(GENOFFSET)
#define critical_enter() critical_enter_KBI()
#define critical_exit() critical_exit_KBI()
#else
static __inline void
critical_enter(void)
{
	struct thread_lite *td;

	td = (struct thread_lite *)curthread;
	td->td_critnest++;
	atomic_interrupt_fence();
}

static __inline void
critical_exit(void)
{
	struct thread_lite *td;

	td = (struct thread_lite *)curthread;
	KASSERT(td->td_critnest != 0,
	    ("critical_exit: td_critnest == 0"));
	atomic_interrupt_fence();
	td->td_critnest--;
	atomic_interrupt_fence();
	if (__predict_false(td->td_owepreempt))
		critical_exit_preempt();

}
#endif

#ifdef  EARLY_PRINTF
typedef void early_putc_t(int ch);
extern early_putc_t *early_putc;
#endif
int	kvprintf(char const *, void (*)(int, void*), void *, int,
	    __va_list) __printflike(1, 0);
void	log(int, const char *, ...) __printflike(2, 3);
void	log_console(struct uio *);
void	vlog(int, const char *, __va_list) __printflike(2, 0);
int	asprintf(char **ret, struct malloc_type *mtp, const char *format, 
	    ...) __printflike(3, 4);
int	printf(const char *, ...) __printflike(1, 2);
int	snprintf(char *, size_t, const char *, ...) __printflike(3, 4);
int	sprintf(char *buf, const char *, ...) __printflike(2, 3);
int	uprintf(const char *, ...) __printflike(1, 2);
int	vprintf(const char *, __va_list) __printflike(1, 0);
int	vasprintf(char **ret, struct malloc_type *mtp, const char *format,
	    __va_list ap) __printflike(3, 0);
int	vsnprintf(char *, size_t, const char *, __va_list) __printflike(3, 0);
int	vsnrprintf(char *, size_t, int, const char *, __va_list) __printflike(4, 0);
int	vsprintf(char *buf, const char *, __va_list) __printflike(2, 0);
int	sscanf(const char *, char const * _Nonnull, ...) __scanflike(2, 3);
int	vsscanf(const char * _Nonnull, char const * _Nonnull, __va_list)  __scanflike(2, 0);
long	strtol(const char *, char **, int);
u_long	strtoul(const char *, char **, int);
quad_t	strtoq(const char *, char **, int);
u_quad_t strtouq(const char *, char **, int);
void	tprintf(struct proc *p, int pri, const char *, ...) __printflike(3, 4);
void	vtprintf(struct proc *, int, const char *, __va_list) __printflike(3, 0);
void	hexdump(const void *ptr, int length, const char *hdr, int flags);
#define	HD_COLUMN_MASK	0xff
#define	HD_DELIM_MASK	0xff00
#define	HD_OMIT_COUNT	(1 << 16)
#define	HD_OMIT_HEX	(1 << 17)
#define	HD_OMIT_CHARS	(1 << 18)

#define ovbcopy(f, t, l) bcopy((f), (t), (l))
void	explicit_bzero(void * _Nonnull, size_t);

void	*memset(void * _Nonnull buf, int c, size_t len);
void	*memcpy(void * _Nonnull to, const void * _Nonnull from, size_t len);
void	*memmove(void * _Nonnull dest, const void * _Nonnull src, size_t n);
int	memcmp(const void *b1, const void *b2, size_t len);

#ifdef SAN_NEEDS_INTERCEPTORS
#define	SAN_INTERCEPTOR(func)	\
	__CONCAT(SAN_INTERCEPTOR_PREFIX, __CONCAT(_, func))
void	*SAN_INTERCEPTOR(memset)(void *, int, size_t);
void	*SAN_INTERCEPTOR(memcpy)(void *, const void *, size_t);
void	*SAN_INTERCEPTOR(memmove)(void *, const void *, size_t);
int	SAN_INTERCEPTOR(memcmp)(const void *, const void *, size_t);
#ifndef SAN_RUNTIME
#define bcopy(from, to, len)	SAN_INTERCEPTOR(memmove)((to), (from), (len))
#define bzero(buf, len)		SAN_INTERCEPTOR(memset)((buf), 0, (len))
#define bcmp(b1, b2, len)	SAN_INTERCEPTOR(memcmp)((b1), (b2), (len))
#define memset(buf, c, len)	SAN_INTERCEPTOR(memset)((buf), (c), (len))
#define memcpy(to, from, len)	SAN_INTERCEPTOR(memcpy)((to), (from), (len))
#define memmove(dest, src, n)	SAN_INTERCEPTOR(memmove)((dest), (src), (n))
#define memcmp(b1, b2, len)	SAN_INTERCEPTOR(memcmp)((b1), (b2), (len))
#endif /* !SAN_RUNTIME */
#else /* !SAN_NEEDS_INTERCEPTORS */
#define bcopy(from, to, len)	__builtin_memmove((to), (from), (len))
#define bzero(buf, len)		__builtin_memset((buf), 0, (len))
#define bcmp(b1, b2, len)	__builtin_memcmp((b1), (b2), (len))
#define memset(buf, c, len)	__builtin_memset((buf), (c), (len))
#define memcpy(to, from, len)	__builtin_memcpy((to), (from), (len))
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))
#define memcmp(b1, b2, len)	__builtin_memcmp((b1), (b2), (len))
#endif /* SAN_NEEDS_INTERCEPTORS */

void	*memset_early(void * _Nonnull buf, int c, size_t len);
#define bzero_early(buf, len) memset_early((buf), 0, (len))
void	*memcpy_early(void * _Nonnull to, const void * _Nonnull from, size_t len);
void	*memmove_early(void * _Nonnull dest, const void * _Nonnull src, size_t n);
#define bcopy_early(from, to, len) memmove_early((to), (from), (len))

#define	copystr(src, dst, len, outlen)	({			\
	size_t __r, __len, *__outlen;				\
								\
	__len = (len);						\
	__outlen = (outlen);					\
	__r = strlcpy((dst), (src), __len);			\
	if (__outlen != NULL)					\
		*__outlen = ((__r >= __len) ? __len : __r + 1);	\
	((__r >= __len) ? ENAMETOOLONG : 0);			\
})

int	copyinstr(const void * __restrict udaddr,
	    void * _Nonnull __restrict kaddr, size_t len,
	    size_t * __restrict lencopied);
int	copyin(const void * __restrict udaddr,
	    void * _Nonnull __restrict kaddr, size_t len);
int	copyin_nofault(const void * __restrict udaddr,
	    void * _Nonnull __restrict kaddr, size_t len);
int	copyout(const void * _Nonnull __restrict kaddr,
	    void * __restrict udaddr, size_t len);
int	copyout_nofault(const void * _Nonnull __restrict kaddr,
	    void * __restrict udaddr, size_t len);

#ifdef SAN_NEEDS_INTERCEPTORS
int	SAN_INTERCEPTOR(copyin)(const void *, void *, size_t);
int	SAN_INTERCEPTOR(copyinstr)(const void *, void *, size_t, size_t *);
int	SAN_INTERCEPTOR(copyout)(const void *, void *, size_t);
#ifndef SAN_RUNTIME
#define	copyin(u, k, l)		SAN_INTERCEPTOR(copyin)((u), (k), (l))
#define	copyinstr(u, k, l, lc)	SAN_INTERCEPTOR(copyinstr)((u), (k), (l), (lc))
#define	copyout(k, u, l)	SAN_INTERCEPTOR(copyout)((k), (u), (l))
#endif /* !SAN_RUNTIME */
#endif /* SAN_NEEDS_INTERCEPTORS */

int	fubyte(volatile const void *base);
long	fuword(volatile const void *base);
int	fuword16(volatile const void *base);
int32_t	fuword32(volatile const void *base);
int64_t	fuword64(volatile const void *base);
int	fueword(volatile const void *base, long *val);
int	fueword32(volatile const void *base, int32_t *val);
int	fueword64(volatile const void *base, int64_t *val);
int	subyte(volatile void *base, int byte);
int	suword(volatile void *base, long word);
int	suword16(volatile void *base, int word);
int	suword32(volatile void *base, int32_t word);
int	suword64(volatile void *base, int64_t word);
uint32_t casuword32(volatile uint32_t *base, uint32_t oldval, uint32_t newval);
u_long	casuword(volatile u_long *p, u_long oldval, u_long newval);
int	casueword32(volatile uint32_t *base, uint32_t oldval, uint32_t *oldvalp,
	    uint32_t newval);
int	casueword(volatile u_long *p, u_long oldval, u_long *oldvalp,
	    u_long newval);

#if defined(SAN_NEEDS_INTERCEPTORS) && !defined(KCSAN)
int	SAN_INTERCEPTOR(fubyte)(volatile const void *base);
int	SAN_INTERCEPTOR(fuword16)(volatile const void *base);
int	SAN_INTERCEPTOR(fueword)(volatile const void *base, long *val);
int	SAN_INTERCEPTOR(fueword32)(volatile const void *base, int32_t *val);
int	SAN_INTERCEPTOR(fueword64)(volatile const void *base, int64_t *val);
int	SAN_INTERCEPTOR(subyte)(volatile void *base, int byte);
int	SAN_INTERCEPTOR(suword)(volatile void *base, long word);
int	SAN_INTERCEPTOR(suword16)(volatile void *base, int word);
int	SAN_INTERCEPTOR(suword32)(volatile void *base, int32_t word);
int	SAN_INTERCEPTOR(suword64)(volatile void *base, int64_t word);
int	SAN_INTERCEPTOR(casueword32)(volatile uint32_t *base, uint32_t oldval,
	    uint32_t *oldvalp, uint32_t newval);
int	SAN_INTERCEPTOR(casueword)(volatile u_long *p, u_long oldval,
	    u_long *oldvalp, u_long newval);
#ifndef SAN_RUNTIME
#define	fubyte(b)		SAN_INTERCEPTOR(fubyte)((b))
#define	fuword16(b)		SAN_INTERCEPTOR(fuword16)((b))
#define	fueword(b, v)		SAN_INTERCEPTOR(fueword)((b), (v))
#define	fueword32(b, v)		SAN_INTERCEPTOR(fueword32)((b), (v))
#define	fueword64(b, v)		SAN_INTERCEPTOR(fueword64)((b), (v))
#define	subyte(b, w)		SAN_INTERCEPTOR(subyte)((b), (w))
#define	suword(b, w)		SAN_INTERCEPTOR(suword)((b), (w))
#define	suword16(b, w)		SAN_INTERCEPTOR(suword16)((b), (w))
#define	suword32(b, w)		SAN_INTERCEPTOR(suword32)((b), (w))
#define	suword64(b, w)		SAN_INTERCEPTOR(suword64)((b), (w))
#define	casueword32(b, o, p, n)	SAN_INTERCEPTOR(casueword32)((b), (o), (p), (n))
#define	casueword(b, o, p, n)	SAN_INTERCEPTOR(casueword)((b), (o), (p), (n))
#endif /* !SAN_RUNTIME */
#endif /* SAN_NEEDS_INTERCEPTORS && !KCSAN */

int	sysbeep(int hertz, sbintime_t duration);

void	hardclock(int cnt, int usermode);
void	hardclock_sync(int cpu);
void	statclock(int cnt, int usermode);
void	profclock(int cnt, int usermode, uintfptr_t pc);

int	hardclockintr(void);

void	startprofclock(struct proc *);
void	stopprofclock(struct proc *);
void	cpu_startprofclock(void);
void	cpu_stopprofclock(void);
void	suspendclock(void);
void	resumeclock(void);
sbintime_t 	cpu_idleclock(void);
void	cpu_activeclock(void);
void	cpu_new_callout(int cpu, sbintime_t bt, sbintime_t bt_opt);
void	cpu_et_frequency(struct eventtimer *et, uint64_t newfreq);
extern int	cpu_disable_c2_sleep;
extern int	cpu_disable_c3_sleep;

extern void	(*tcp_hpts_softclock)(void);
extern volatile uint32_t __read_frequently hpts_that_need_softclock;

#define	tcp_hpts_softclock()	do {					\
		if (hpts_that_need_softclock > 0)			\
			tcp_hpts_softclock();				\
} while (0)

char	*kern_getenv(const char *name);
void	freeenv(char *env);
int	getenv_int(const char *name, int *data);
int	getenv_uint(const char *name, unsigned int *data);
int	getenv_long(const char *name, long *data);
int	getenv_ulong(const char *name, unsigned long *data);
int	getenv_string(const char *name, char *data, int size);
int	getenv_int64(const char *name, int64_t *data);
int	getenv_uint64(const char *name, uint64_t *data);
int	getenv_quad(const char *name, quad_t *data);
int	getenv_bool(const char *name, bool *data);
bool	getenv_is_true(const char *name);
bool	getenv_is_false(const char *name);
int	kern_setenv(const char *name, const char *value);
int	kern_unsetenv(const char *name);
int	testenv(const char *name);

int	getenv_array(const char *name, void *data, int size, int *psize,
    int type_size, bool allow_signed);
#define	GETENV_UNSIGNED	false	/* negative numbers not allowed */
#define	GETENV_SIGNED	true	/* negative numbers allowed */

typedef uint64_t (cpu_tick_f)(void);
void set_cputicker(cpu_tick_f *func, uint64_t freq, bool isvariable);
extern cpu_tick_f *cpu_ticks;
uint64_t cpu_tickrate(void);
uint64_t cputick2usec(uint64_t tick);

#include <sys/libkern.h>

/* Initialize the world */
void	consinit(void);
void	cpu_initclocks(void);
void	cpu_initclocks_bsp(void);
void	cpu_initclocks_ap(void);
void	usrinfoinit(void);

/* Finalize the world */
void	kern_reboot(int) __dead2;
void	shutdown_nice(int);

/* Stubs for obsolete functions that used to be for interrupt management */
static __inline intrmask_t	splhigh(void)		{ return 0; }
static __inline intrmask_t	splimp(void)		{ return 0; }
static __inline intrmask_t	splnet(void)		{ return 0; }
static __inline intrmask_t	spltty(void)		{ return 0; }
static __inline void		splx(intrmask_t ipl __unused)	{ return; }

/*
 * Common `proc' functions are declared here so that proc.h can be included
 * less often.
 */
int	_sleep(const void * _Nonnull chan, struct lock_object *lock, int pri,
	   const char *wmesg, sbintime_t sbt, sbintime_t pr, int flags);
#define	msleep(chan, mtx, pri, wmesg, timo)				\
	_sleep((chan), &(mtx)->lock_object, (pri), (wmesg),		\
	    tick_sbt * (timo), 0, C_HARDCLOCK)
#define	msleep_sbt(chan, mtx, pri, wmesg, bt, pr, flags)		\
	_sleep((chan), &(mtx)->lock_object, (pri), (wmesg), (bt), (pr),	\
	    (flags))
int	msleep_spin_sbt(const void * _Nonnull chan, struct mtx *mtx,
	    const char *wmesg, sbintime_t sbt, sbintime_t pr, int flags);
#define	msleep_spin(chan, mtx, wmesg, timo)				\
	msleep_spin_sbt((chan), (mtx), (wmesg), tick_sbt * (timo),	\
	    0, C_HARDCLOCK)
int	pause_sbt(const char *wmesg, sbintime_t sbt, sbintime_t pr,
	    int flags);
static __inline int
pause(const char *wmesg, int timo)
{
	return (pause_sbt(wmesg, tick_sbt * timo, 0, C_HARDCLOCK));
}
#define	pause_sig(wmesg, timo)						\
	pause_sbt((wmesg), tick_sbt * (timo), 0, C_HARDCLOCK | C_CATCH)
#define	tsleep(chan, pri, wmesg, timo)					\
	_sleep((chan), NULL, (pri), (wmesg), tick_sbt * (timo),		\
	    0, C_HARDCLOCK)
#define	tsleep_sbt(chan, pri, wmesg, bt, pr, flags)			\
	_sleep((chan), NULL, (pri), (wmesg), (bt), (pr), (flags))
void	wakeup(const void *chan);
void	wakeup_one(const void *chan);
void	wakeup_any(const void *chan);

/*
 * Common `struct cdev *' stuff are declared here to avoid #include poisoning
 */

struct cdev;
dev_t dev2udev(struct cdev *x);
const char *devtoname(struct cdev *cdev);

#ifdef __LP64__
size_t	devfs_iosize_max(void);
size_t	iosize_max(void);
#endif

int poll_no_poll(int events);

/* XXX: Should be void nanodelay(u_int nsec); */
void	DELAY(int usec);

int kcmp_cmp(uintptr_t a, uintptr_t b);

/* Root mount holdback API */
struct root_hold_token {
	int				flags;
	const char			*who;
	TAILQ_ENTRY(root_hold_token)	list;
};

struct root_hold_token *root_mount_hold(const char *identifier);
void root_mount_hold_token(const char *identifier, struct root_hold_token *h);
void root_mount_rel(struct root_hold_token *h);
int root_mounted(void);

/*
 * Unit number allocation API. (kern/subr_unit.c)
 */
struct unrhdr;
#define	UNR_NO_MTX	((void *)(uintptr_t)-1)
struct unrhdr *new_unrhdr(int low, int high, struct mtx *mutex);
void init_unrhdr(struct unrhdr *uh, int low, int high, struct mtx *mutex);
void delete_unrhdr(struct unrhdr *uh);
void clear_unrhdr(struct unrhdr *uh);
void clean_unrhdr(struct unrhdr *uh);
void clean_unrhdrl(struct unrhdr *uh);
int alloc_unr(struct unrhdr *uh);
int alloc_unr_specific(struct unrhdr *uh, u_int item);
int alloc_unrl(struct unrhdr *uh);
void free_unr(struct unrhdr *uh, u_int item);
void *create_iter_unr(struct unrhdr *uh);
int next_iter_unr(void *handle);
void free_iter_unr(void *handle);

struct unrhdr64 {
        uint64_t	counter;
};

static __inline void
new_unrhdr64(struct unrhdr64 *unr64, uint64_t low)
{

	unr64->counter = low;
}

static __inline uint64_t
alloc_unr64(struct unrhdr64 *unr64)
{

	return (atomic_fetchadd_64(&unr64->counter, 1));
}

void	intr_prof_stack_use(struct thread *td, struct trapframe *frame);

void counted_warning(unsigned *counter, const char *msg);

/*
 * APIs to manage deprecation and obsolescence.
 */
void _gone_in(int major, const char *msg);
void _gone_in_dev(device_t dev, int major, const char *msg);
#ifdef NO_OBSOLETE_CODE
#define __gone_ok(m, msg)					 \
	_Static_assert(m < P_OSREL_MAJOR(__FreeBSD_version)),	 \
	    "Obsolete code: " msg);
#else
#define	__gone_ok(m, msg)
#endif
#define gone_in(major, msg)		__gone_ok(major, msg) _gone_in(major, msg)
#define gone_in_dev(dev, major, msg)	__gone_ok(major, msg) _gone_in_dev(dev, major, msg)

#ifdef INVARIANTS
#define	__diagused
#else
#define	__diagused	__unused
#endif

#ifdef WITNESS
#define	__witness_used
#else
#define	__witness_used	__unused
#endif

#endif /* _KERNEL */

__NULLABILITY_PRAGMA_POP
#endif /* !_SYS_SYSTM_H_ */