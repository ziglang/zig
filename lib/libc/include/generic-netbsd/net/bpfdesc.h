/*	$NetBSD: bpfdesc.h,v 1.48.10.1 2024/09/13 14:13:05 martin Exp $	*/

/*
 * Copyright (c) 1990, 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from the Stanford/CMU enet packet filter,
 * (net/enet.c) distributed as part of 4.3BSD, and code contributed
 * to Berkeley by Steven McCanne and Van Jacobson both of Lawrence
 * Berkeley Laboratory.
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
 *	@(#)bpfdesc.h	8.1 (Berkeley) 6/10/93
 *
 * @(#) Header: bpfdesc.h,v 1.14 96/06/16 22:28:07 leres Exp  (LBL)
 */

#ifndef _NET_BPFDESC_H_
#define _NET_BPFDESC_H_

#include <sys/callout.h>
#include <sys/selinfo.h>		/* for struct selinfo */
#include <net/if.h>			/* for IFNAMSIZ */
#include <net/bpfjit.h>			/* for bpfjit_function_t */
#ifdef _KERNEL
#include <sys/pslist.h>
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/psref.h>
#endif

struct bpf_filter {
	struct bpf_insn *bf_insn; 	/* filter code */
	size_t		bf_size;
	bpfjit_func_t	bf_jitcode;	/* compiled filter program */
};

/*
 * Descriptor associated with each open bpf file.
 */
struct bpf_d {
	/* DEPRECATED. Keep it to avoid breaking kvm(3) users */
	struct bpf_d	*_bd_next;	/* Linked list of descriptors */
	/*
	 * Buffer slots: two mbuf clusters buffer the incoming packets.
	 *   The model has three slots.  Sbuf is always occupied.
	 *   sbuf (store) - Receive interrupt puts packets here.
	 *   hbuf (hold) - When sbuf is full, put cluster here and
	 *                 wakeup read (replace sbuf with fbuf).
	 *   fbuf (free) - When read is done, put cluster here.
	 * On receiving, if sbuf is full and fbuf is 0, packet is dropped.
	 */
	void *		bd_sbuf;	/* store slot */
	void *		bd_hbuf;	/* hold slot */
	void *		bd_fbuf;	/* free slot */
	int 		bd_slen;	/* current length of store buffer */
	int 		bd_hlen;	/* current length of hold buffer */

	int		bd_bufsize;	/* absolute length of buffers */

	struct bpf_if *	bd_bif;		/* interface descriptor */
	u_long		bd_rtout;	/* Read timeout in 'ticks' */
	/* DEPRECATED. Keep it to avoid breaking kvm(3) users */
	struct bpf_insn *_bd_filter; 	/* filter code */
	/*
	 * XXX we should make the counters per-CPU once we retire kvm(3) users
	 * that directly access them.
	 */
	u_long		bd_rcount;	/* number of packets received */
	u_long		bd_dcount;	/* number of packets dropped */
	u_long		bd_ccount;	/* number of packets captured */

	u_char		bd_promisc;	/* true if listening promiscuously */
	u_char		bd_state;	/* idle, waiting, or timed out */
	u_char		bd_immediate;	/* true to return on packet arrival */
	int		bd_hdrcmplt;	/* false to fill in src lladdr */
	u_int		bd_direction;	/* select packet direction */
	int 		bd_feedback;	/* true to feed back sent packets */
	int		bd_async;	/* non-zero if packet reception should generate signal */
	pid_t		bd_pgid;	/* process or group id for signal */
#if BSD < 199103
	u_char		bd_selcoll;	/* true if selects collide */
	int		bd_timedout;
	struct proc *	bd_selproc;	/* process that last selected us */
#else
	u_char		bd_pad;		/* explicit alignment */
	struct selinfo	bd_sel;		/* bsd select info */
#endif
	callout_t	bd_callout;	/* for BPF timeouts with select */
	pid_t		bd_pid;		/* corresponding PID */
	/* DEPRECATED. Keep it to avoid breaking kvm(3) users */
	LIST_ENTRY(bpf_d) _bd_list;	/* list of all BPF's */
	void		*bd_sih;	/* soft interrupt handle */
	struct timespec bd_atime;	/* access time */
	struct timespec bd_mtime;	/* modification time */
	struct timespec bd_btime;	/* birth time */
#ifdef _LP64
	int		bd_compat32;	/* 32-bit stream on LP64 system */
#endif
	/* DEPRECATED. Keep it to avoid breaking kvm(3) users */
	bpfjit_func_t	bd_jitcode;	/* compiled filter program */
	struct bpf_filter *bd_rfilter;
	struct bpf_filter *bd_wfilter;
	int		bd_locked;
#ifdef _KERNEL
	struct pslist_entry	bd_bif_dlist_entry; /* For bpf_if */
	struct pslist_entry	bd_bpf_dlist_entry; /* For the global list */
	kmutex_t	*bd_mtx;
	kmutex_t	*bd_buf_mtx;	/* For buffers, bd_state, bd_sel and bd_cv */
	kcondvar_t	bd_cv;
#endif
};


/* Values for bd_state */
#define BPF_IDLE	0		/* no select in progress */
#define BPF_WAITING	1		/* waiting for read timeout in select */
#define BPF_TIMED_OUT	2		/* read timeout has expired in select */

/*
 * Description associated with the external representation of each
 * open bpf file.
 */
struct bpf_d_ext {
	int32_t		bde_bufsize;
	uint8_t		bde_promisc;
	uint8_t		bde_state;
	uint8_t		bde_immediate;
	int32_t		bde_hdrcmplt;
	uint32_t	bde_direction;
	pid_t		bde_pid;
	uint64_t	bde_rcount;		/* number of packets received */
	uint64_t	bde_dcount;		/* number of packets dropped */
	uint64_t	bde_ccount;		/* number of packets captured */
	char		bde_ifname[IFNAMSIZ];
	int		bde_locked;
};


/*
 * Record for each event tracker watching a tap point
 */
struct bpf_event_tracker {
	SLIST_ENTRY(bpf_event_tracker) bet_entries;
	void (*bet_notify)(struct bpf_if *, struct ifnet *, int, int);
};

/*
 * Descriptor associated with each attached hardware interface.
 */
struct bpf_if {
	/* DEPRECATED. Keep it to avoid breaking kvm(3) users */
	struct bpf_if *_bif_next;	/* list of all interfaces */
	struct bpf_d *_bif_dlist;	/* descriptor list */
	struct bpf_if **bif_driverp;	/* pointer into softc */
	u_int bif_dlt;			/* link layer type */
	u_int bif_hdrlen;		/* length of header (with padding) */
	struct ifnet *bif_ifp;		/* corresponding interface */
	void *bif_si;
	struct mbuf *bif_mbuf_head;
	struct mbuf *bif_mbuf_tail;
#ifdef _KERNEL
	struct pslist_entry bif_iflist_entry;
	struct pslist_head bif_dlist_head;
	struct psref_target bif_psref;
	SLIST_HEAD(, bpf_event_tracker) bif_trackers;
#endif
};

#endif /* !_NET_BPFDESC_H_ */