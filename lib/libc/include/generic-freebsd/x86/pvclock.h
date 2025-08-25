/*-
 * Copyright (c) 2014, Bryan Venteicher <bryanv@FreeBSD.org>
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

#ifndef X86_PVCLOCK
#define X86_PVCLOCK

#include <sys/types.h>

#ifdef _KERNEL
#include <sys/timetc.h>
#endif /* _KERNEL */

#define	PVCLOCK_CDEVNAME		"pvclock"

struct pvclock_vcpu_time_info {
	uint32_t	version;
	uint32_t	pad0;
	uint64_t	tsc_timestamp;
	uint64_t	system_time;
	uint32_t	tsc_to_system_mul;
	int8_t		tsc_shift;
	uint8_t		flags;
	uint8_t		pad[2];
};

#define PVCLOCK_FLAG_TSC_STABLE		0x01
#define PVCLOCK_FLAG_GUEST_PASUED	0x02

/*
 * Scale a 64-bit delta by scaling and multiplying by a 32-bit fraction,
 * yielding a 64-bit result.
 */
static inline uint64_t
pvclock_scale_delta(uint64_t delta, uint32_t mul_frac, int shift)
{
	uint64_t product;

	if (shift < 0)
		delta >>= -shift;
	else
		delta <<= shift;
#if defined(__i386__)
	{
		uint32_t tmp1, tmp2;

		/**
		 * For i386, the formula looks like:
		 *
		 *   lower = (mul_frac * (delta & UINT_MAX)) >> 32
		 *   upper = mul_frac * (delta >> 32)
		 *   product = lower + upper
		 */
		__asm__ (
			"mul  %5       ; "
			"mov  %4,%%eax ; "
			"mov  %%edx,%4 ; "
			"mul  %5       ; "
			"xor  %5,%5    ; "
			"add  %4,%%eax ; "
			"adc  %5,%%edx ; "
			: "=A" (product), "=r" (tmp1), "=r" (tmp2)
			: "a" ((uint32_t)delta), "1" ((uint32_t)(delta >> 32)),
			  "2" (mul_frac) );
	}
#elif defined(__amd64__)
	{
		unsigned long tmp;

		__asm__ (
			"mulq %[mul_frac] ; shrd $32, %[hi], %[lo]"
			: [lo]"=a" (product), [hi]"=d" (tmp)
			: "0" (delta), [mul_frac]"rm"((uint64_t)mul_frac));
	}
#else
#error "pvclock: unsupported x86 architecture?"
#endif
	return (product);
}

#ifdef _KERNEL

typedef struct pvclock_wall_clock *pvclock_get_wallclock_t(void *arg);

struct pvclock_wall_clock {
	uint32_t	version;
	uint32_t	sec;
	uint32_t	nsec;
};

struct pvclock {
	/* Public; initialized by the caller of 'pvclock_init()': */
	pvclock_get_wallclock_t		*get_wallclock;
	void				*get_wallclock_arg;
	struct pvclock_vcpu_time_info	*timeinfos;
	bool				 stable_flag_supported;

	/* Private; initialized by the 'pvclock' API: */
	bool				 vdso_force_unstable;
	bool				 vdso_enable_without_rdtscp;
	struct timecounter		 tc;
	struct cdev			*cdev;
};

/*
 * NOTE: 'pvclock_get_timecount()' and 'pvclock_get_wallclock()' are purely
 * transitional; they should be removed after 'dev/xen/timer/timer.c' has been
 * migrated to the 'struct pvclock' API.
 */
void		pvclock_resume(void);
uint64_t	pvclock_tsc_freq(struct pvclock_vcpu_time_info *ti);
uint64_t	pvclock_get_timecount(struct pvclock_vcpu_time_info *ti);
void		pvclock_get_wallclock(struct pvclock_wall_clock *wc,
		    struct timespec *ts);

void		pvclock_init(struct pvclock *pvc, device_t dev,
		    const char *tc_name, int tc_quality, u_int tc_flags);
void		pvclock_gettime(struct pvclock *pvc, struct timespec *ts);
int		pvclock_destroy(struct pvclock *pvc);

#endif /* _KERNEL */

#endif