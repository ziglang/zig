/*-
 * Copyright (c) 2016-2017 Ruslan Bukin <br@bsdpad.com>
 * All rights reserved.
 * Copyright (c) 2019 Mitchell Horne <mhorne@FreeBSD.org>
 *
 * Portions of this software were developed by SRI International and the
 * University of Cambridge Computer Laboratory under DARPA/AFRL contract
 * FA8750-10-C-0237 ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * Portions of this software were developed by the University of Cambridge
 * Computer Laboratory as part of the CTSRD Project, with support from the
 * UK Higher Education Innovation Fund (HEIF).
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

#ifndef _MACHINE_SBI_H_
#define	_MACHINE_SBI_H_

/* SBI Specification Version */
#define	SBI_SPEC_VERS_MAJOR_OFFSET	24
#define	SBI_SPEC_VERS_MAJOR_MASK	(0x7F << SBI_SPEC_VERS_MAJOR_OFFSET)
#define	SBI_SPEC_VERS_MINOR_OFFSET	0
#define	SBI_SPEC_VERS_MINOR_MASK	(0xFFFFFF << SBI_SPEC_VERS_MINOR_OFFSET)

/* SBI Implementation IDs */
#define	SBI_IMPL_ID_BBL			0
#define	SBI_IMPL_ID_OPENSBI		1
#define	SBI_IMPL_ID_XVISOR		2
#define	SBI_IMPL_ID_KVM			3
#define	SBI_IMPL_ID_RUSTSBI		4
#define	SBI_IMPL_ID_DIOSIX		5

/* SBI Error Codes */
#define	SBI_SUCCESS			0
#define	SBI_ERR_FAILURE			-1
#define	SBI_ERR_NOT_SUPPORTED		-2
#define	SBI_ERR_INVALID_PARAM		-3
#define	SBI_ERR_DENIED			-4
#define	SBI_ERR_INVALID_ADDRESS		-5
#define	SBI_ERR_ALREADY_AVAILABLE	-6

/* SBI Base Extension */
#define	SBI_EXT_ID_BASE			0x10
#define	SBI_BASE_GET_SPEC_VERSION	0
#define	SBI_BASE_GET_IMPL_ID		1
#define	SBI_BASE_GET_IMPL_VERSION	2
#define	SBI_BASE_PROBE_EXTENSION	3
#define	SBI_BASE_GET_MVENDORID		4
#define	SBI_BASE_GET_MARCHID		5
#define	SBI_BASE_GET_MIMPID		6

/* Timer (TIME) Extension */
#define	SBI_EXT_ID_TIME			0x54494D45
#define	SBI_TIME_SET_TIMER		0

/* IPI (IPI) Extension */
#define	SBI_EXT_ID_IPI			0x735049
#define	SBI_IPI_SEND_IPI		0

/* RFENCE (RFNC) Extension */
#define	SBI_EXT_ID_RFNC				0x52464E43
#define	SBI_RFNC_REMOTE_FENCE_I			0
#define	SBI_RFNC_REMOTE_SFENCE_VMA		1
#define	SBI_RFNC_REMOTE_SFENCE_VMA_ASID		2
#define	SBI_RFNC_REMOTE_HFENCE_GVMA_VMID	3
#define	SBI_RFNC_REMOTE_HFENCE_GVMA		4
#define	SBI_RFNC_REMOTE_HFENCE_VVMA_ASID	5
#define	SBI_RFNC_REMOTE_HFENCE_VVMA		6

/* Hart State Management (HSM) Extension */
#define	SBI_EXT_ID_HSM			0x48534D
#define	SBI_HSM_HART_START		0
#define	SBI_HSM_HART_STOP		1
#define	SBI_HSM_HART_STATUS		2
#define	 SBI_HSM_STATUS_STARTED		0
#define	 SBI_HSM_STATUS_STOPPED		1
#define	 SBI_HSM_STATUS_START_PENDING	2
#define	 SBI_HSM_STATUS_STOP_PENDING	3

/* System Reset (SRST) Extension */
#define	SBI_EXT_ID_SRST			0x53525354
#define	SBI_SRST_SYSTEM_RESET		0
#define	 SBI_SRST_TYPE_SHUTDOWN		0
#define	 SBI_SRST_TYPE_COLD_REBOOT	1
#define	 SBI_SRST_TYPE_WARM_REBOOT	2
#define	 SBI_SRST_REASON_NONE		0
#define	 SBI_SRST_REASON_SYSTEM_FAILURE	1

/* Legacy Extensions */
#define	SBI_SET_TIMER			0
#define	SBI_CONSOLE_PUTCHAR		1
#define	SBI_CONSOLE_GETCHAR		2
#define	SBI_CLEAR_IPI			3
#define	SBI_SEND_IPI			4
#define	SBI_REMOTE_FENCE_I		5
#define	SBI_REMOTE_SFENCE_VMA		6
#define	SBI_REMOTE_SFENCE_VMA_ASID	7
#define	SBI_SHUTDOWN			8

#define	SBI_CALL0(e, f)				SBI_CALL5(e, f, 0, 0, 0, 0, 0)
#define	SBI_CALL1(e, f, p1)			SBI_CALL5(e, f, p1, 0, 0, 0, 0)
#define	SBI_CALL2(e, f, p1, p2)			SBI_CALL5(e, f, p1, p2, 0, 0, 0)
#define	SBI_CALL3(e, f, p1, p2, p3)		SBI_CALL5(e, f, p1, p2, p3, 0, 0)
#define	SBI_CALL4(e, f, p1, p2, p3, p4)		SBI_CALL5(e, f, p1, p2, p3, p4, 0)
#define	SBI_CALL5(e, f, p1, p2, p3, p4, p5)	sbi_call(e, f, p1, p2, p3, p4, p5)

/*
 * Documentation available at
 * https://github.com/riscv/riscv-sbi-doc/blob/master/riscv-sbi.adoc
 */

struct sbi_ret {
	long error;
	long value;
};

static __inline struct sbi_ret
sbi_call(uint64_t arg7, uint64_t arg6, uint64_t arg0, uint64_t arg1,
    uint64_t arg2, uint64_t arg3, uint64_t arg4)
{
	struct sbi_ret ret;

	register uintptr_t a0 __asm ("a0") = (uintptr_t)(arg0);
	register uintptr_t a1 __asm ("a1") = (uintptr_t)(arg1);
	register uintptr_t a2 __asm ("a2") = (uintptr_t)(arg2);
	register uintptr_t a3 __asm ("a3") = (uintptr_t)(arg3);
	register uintptr_t a4 __asm ("a4") = (uintptr_t)(arg4);
	register uintptr_t a6 __asm ("a6") = (uintptr_t)(arg6);
	register uintptr_t a7 __asm ("a7") = (uintptr_t)(arg7);

	__asm __volatile(			\
		"ecall"				\
		:"+r"(a0), "+r"(a1)		\
		:"r"(a2), "r"(a3), "r"(a4), "r"(a6), "r"(a7)	\
		:"memory");

	ret.error = a0;
	ret.value = a1;
	return (ret);
}

/* Base extension functions. */
static __inline long
sbi_probe_extension(long id)
{
	return (SBI_CALL1(SBI_EXT_ID_BASE, SBI_BASE_PROBE_EXTENSION, id).value);
}

/* TIME extension functions. */
void sbi_set_timer(uint64_t val);

/* IPI extension functions. */
void sbi_send_ipi(const u_long *hart_mask);

/* RFENCE extension functions. */
void sbi_remote_fence_i(const u_long *hart_mask);
void sbi_remote_sfence_vma(const u_long *hart_mask, u_long start, u_long size);
void sbi_remote_sfence_vma_asid(const u_long *hart_mask, u_long start,
    u_long size, u_long asid);

/* Hart State Management extension functions. */

/*
 * Start execution on the specified hart at physical address start_addr. The
 * register a0 will contain the hart's ID, and a1 will contain the value of
 * priv.
 */
int sbi_hsm_hart_start(u_long hart, u_long start_addr, u_long priv);

/*
 * Stop execution on the current hart. Interrupts should be disabled, or this
 * function may return.
 */
void sbi_hsm_hart_stop(void);

/*
 * Get the execution status of the specified hart. The status will be one of:
 *  - SBI_HSM_STATUS_STARTED
 *  - SBI_HSM_STATUS_STOPPED
 *  - SBI_HSM_STATUS_START_PENDING
 *  - SBI_HSM_STATUS_STOP_PENDING
 */
int sbi_hsm_hart_status(u_long hart);

/* System Reset extension functions. */

/*
 * Reset the system based on the following 'type' and 'reason' chosen from:
 *  - SBI_SRST_TYPE_SHUTDOWN
 *  - SBI_SRST_TYPE_COLD_REBOOT
 *  - SBI_SRST_TYPE_WARM_REBOOT
 *  - SBI_SRST_REASON_NONE
 *  - SBI_SRST_REASON_SYSTEM_FAILURE
 */
void sbi_system_reset(u_long reset_type, u_long reset_reason);

/* Legacy extension functions. */
static __inline void
sbi_console_putchar(int ch)
{

	(void)SBI_CALL1(SBI_CONSOLE_PUTCHAR, 0, ch);
}

static __inline int
sbi_console_getchar(void)
{

	/*
	 * XXX: The "error" is returned here because legacy SBI functions
	 * continue to return their value in a0.
	 */
	return (SBI_CALL0(SBI_CONSOLE_GETCHAR, 0).error);
}

void sbi_print_version(void);
void sbi_init(void);

#endif /* !_MACHINE_SBI_H_ */