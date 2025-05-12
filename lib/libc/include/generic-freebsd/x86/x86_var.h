/*-
 * Copyright (c) 1995 Bruce D. Evans.
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
 * 3. Neither the name of the author nor the names of contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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

#ifndef _X86_X86_VAR_H_
#define	_X86_X86_VAR_H_

/*
 * Miscellaneous machine-dependent declarations.
 */

extern	long	Maxmem;
extern	u_int	basemem;
extern	u_int	cpu_exthigh;
extern	u_int	cpu_feature;
extern	u_int	cpu_feature2;
extern	u_int	amd_feature;
extern	u_int	amd_feature2;
extern	u_int	amd_rascap;
extern	u_int	amd_pminfo;
extern	u_int	amd_extended_feature_extensions;
extern	u_int	via_feature_rng;
extern	u_int	via_feature_xcrypt;
extern	u_int	cpu_clflush_line_size;
extern	u_int	cpu_stdext_feature;
extern	u_int	cpu_stdext_feature2;
extern	u_int	cpu_stdext_feature3;
extern	uint64_t cpu_ia32_arch_caps;
extern	u_int	cpu_high;
extern	u_int	cpu_id;
extern	u_int	cpu_max_ext_state_size;
extern	u_int	cpu_mxcsr_mask;
extern	u_int	cpu_procinfo;
extern	u_int	cpu_procinfo2;
extern	u_int	cpu_procinfo3;
extern	char	cpu_vendor[];
extern	char	cpu_model[];
extern	u_int	cpu_vendor_id;
extern	u_int	cpu_mon_mwait_flags;
extern	u_int	cpu_mon_min_size;
extern	u_int	cpu_mon_max_size;
extern	u_int	cpu_maxphyaddr;
extern	u_int	cpu_power_eax;
extern	u_int	cpu_power_ebx;
extern	u_int	cpu_power_ecx;
extern	u_int	cpu_power_edx;
extern	u_int	hv_base;
extern	u_int	hv_high;
extern	char	hv_vendor[];
extern	char	kstack[];
extern	char	sigcode[];
extern	int	szsigcode;
extern	int	workaround_erratum383;
extern	int	_udatasel;
extern	int	_ucodesel;
extern	int	_ucode32sel;
extern	int	_ufssel;
extern	int	_ugssel;
extern	int	use_xsave;
extern	uint64_t xsave_mask;
extern	u_int	max_apic_id;
extern	int	i386_read_exec;
extern	int	pti;
extern	int	hw_ibrs_ibpb_active;
extern	int	hw_mds_disable;
extern	int	hw_ssb_active;
extern	int	x86_taa_enable;
extern	int	cpu_flush_rsb_ctxsw;
extern	int	x86_rngds_mitg_enable;
extern	int	zenbleed_enable;
extern	int	cpu_amdc1e_bug;
extern	char	bootmethod[16];

struct	pcb;
struct	thread;
struct	reg;
struct	fpreg;
struct  dbreg;
struct	dumperinfo;
struct	trapframe;
struct	minidumpstate;

/*
 * The interface type of the interrupt handler entry point cannot be
 * expressed in C.  Use simplest non-variadic function type as an
 * approximation.
 */
typedef void alias_for_inthand_t(void);

bool	acpi_get_fadt_bootflags(uint16_t *flagsp);
void	*alloc_fpusave(int flags);
u_int	cpu_auxmsr(void);
vm_paddr_t cpu_getmaxphyaddr(void);
bool	cpu_mwait_usable(void);
void	cpu_probe_amdc1e(void);
void	cpu_setregs(void);
int	dbreg_set_watchpoint(vm_offset_t addr, vm_size_t size, int access);
int	dbreg_clr_watchpoint(vm_offset_t addr, vm_size_t size);
void	dbreg_list_watchpoints(void);
void	x86_clear_dbregs(struct pcb *pcb);
bool	disable_wp(void);
void	restore_wp(bool old_wp);
void	finishidentcpu(void);
void	identify_cpu1(void);
void	identify_cpu2(void);
void	identify_cpu_ext_features(void);
void	identify_cpu_fixup_bsp(void);
void	identify_hypervisor(void);
void	initializecpu(void);
void	initializecpucache(void);
bool	fix_cpuid(void);
void	fillw(int /*u_short*/ pat, void *base, size_t cnt);
int	isa_nmi(int cd);
void	handle_ibrs_entry(void);
void	handle_ibrs_exit(void);
void	hw_ibrs_recalculate(bool all_cpus);
void	hw_mds_recalculate(void);
void	hw_ssb_recalculate(bool all_cpus);
void	x86_taa_recalculate(void);
void	x86_rngds_mitg_recalculate(bool all_cpus);
void	zenbleed_sanitize_enable(void);
void	zenbleed_check_and_apply(bool all_cpus);
void	nmi_call_kdb(u_int cpu, u_int type, struct trapframe *frame);
void	nmi_call_kdb_smp(u_int type, struct trapframe *frame);
void	nmi_handle_intr(u_int type, struct trapframe *frame);
void	pagecopy(void *from, void *to);
void	printcpuinfo(void);
int	pti_get_default(void);
int	user_dbreg_trap(register_t dr6);
int	cpu_minidumpsys(struct dumperinfo *, const struct minidumpstate *);
struct pcb *get_pcb_td(struct thread *td);
void	x86_set_fork_retval(struct thread *td);
uint64_t rdtsc_ordered(void);

/*
 * MSR ops for x86_msr_op()
 */
#define	MSR_OP_ANDNOT		0x00000001
#define	MSR_OP_OR		0x00000002
#define	MSR_OP_WRITE		0x00000003
#define	MSR_OP_READ		0x00000004

/*
 * Where and which execution mode
 */
#define	MSR_OP_LOCAL		0x10000000
#define	MSR_OP_SCHED_ALL	0x20000000
#define	MSR_OP_SCHED_ONE	0x30000000
#define	MSR_OP_RENDEZVOUS_ALL	0x40000000
#define	MSR_OP_RENDEZVOUS_ONE	0x50000000
#define	MSR_OP_CPUID(id)	((id) << 8)

void x86_msr_op(u_int msr, u_int op, uint64_t arg1, uint64_t *res);

#if defined(__i386__) && defined(INVARIANTS)
void	trap_check_kstack(void);
#else
#define	trap_check_kstack()
#endif

#endif