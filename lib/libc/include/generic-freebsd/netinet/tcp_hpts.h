/*-
 * Copyright (c) 2016-2018 Netflix, Inc.
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

#ifndef __tcp_hpts_h__
#define __tcp_hpts_h__

/* Number of useconds in a hpts tick */
#define HPTS_TICKS_PER_SLOT 10
#define HPTS_MS_TO_SLOTS(x) ((x * 100) + 1)
#define HPTS_USEC_TO_SLOTS(x) ((x+9) /10)
#define HPTS_USEC_IN_SEC 1000000
#define HPTS_MSEC_IN_SEC 1000
#define HPTS_USEC_IN_MSEC 1000

struct hpts_diag {
	uint32_t p_hpts_active; 	/* bbr->flex7 x */
	uint32_t p_nxt_slot;		/* bbr->flex1 x */
	uint32_t p_cur_slot;		/* bbr->flex2 x */
	uint32_t p_prev_slot;		/* bbr->delivered */
	uint32_t p_runningslot;		/* bbr->inflight */
	uint32_t slot_req;		/* bbr->flex3 x */
	uint32_t inp_hptsslot;		/* bbr->flex4 x */
	uint32_t slot_remaining;	/* bbr->flex5 x */
	uint32_t have_slept;		/* bbr->epoch x */
	uint32_t hpts_sleep_time;	/* bbr->applimited x */
	uint32_t yet_to_sleep;		/* bbr->lt_epoch x */
	uint32_t need_new_to;		/* bbr->flex6 x  */
	uint32_t wheel_slot;		/* bbr->bw_inuse x */
	uint32_t maxslots;		/* bbr->delRate x */
	uint32_t wheel_cts;		/* bbr->rttProp x */
	int32_t co_ret; 		/* bbr->pkts_out x */
	uint32_t p_curtick;		/* upper bbr->cur_del_rate */
	uint32_t p_lasttick;		/* lower bbr->cur_del_rate */
	uint8_t p_on_min_sleep; 	/* bbr->flex8 x */
};

/* Magic flags to tell whats cooking on the pacing wheel */
#define PACE_TMR_DELACK 0x01	/* Delayed ack timer running */
#define PACE_TMR_RACK   0x02	/* RACK timer running */
#define PACE_TMR_TLP    0x04	/* TLP timer running */
#define PACE_TMR_RXT    0x08	/* Retransmit timer running */
#define PACE_TMR_PERSIT 0x10	/* Persists timer running */
#define PACE_TMR_KEEP   0x20	/* Keep alive timer running */
#define PACE_PKT_OUTPUT 0x40	/* Output Packets being paced */
#define PACE_TMR_MASK   (PACE_TMR_KEEP|PACE_TMR_PERSIT|PACE_TMR_RXT|PACE_TMR_TLP|PACE_TMR_RACK|PACE_TMR_DELACK)

#define DEFAULT_CONNECTION_THESHOLD 100

/*
 * When using the hpts, a TCP stack must make sure
 * that once a INP_DROPPED flag is applied to a INP
 * that it does not expect tcp_output() to ever be
 * called by the hpts. The hpts will *not* call
 * any output (or input) functions on a TCB that
 * is in the DROPPED state.
 *
 * This implies final ACK's and RST's that might
 * be sent when a TCB is still around must be
 * sent from a routine like tcp_respond().
 */
#define LOWEST_SLEEP_ALLOWED 50
#define DEFAULT_MIN_SLEEP 250	/* How many usec's is default for hpts sleep
				 * this determines min granularity of the
				 * hpts. If 1, granularity is 10useconds at
				 * the cost of more CPU (context switching).
				 * Note do not set this to 0.
				 */
#define DYNAMIC_MIN_SLEEP DEFAULT_MIN_SLEEP
#define DYNAMIC_MAX_SLEEP 5000	/* 5ms */

/* Thresholds for raising/lowering sleep */
#define TICKS_INDICATE_MORE_SLEEP 100		/* This would be 1ms */
#define TICKS_INDICATE_LESS_SLEEP 1000		/* This would indicate 10ms */
/**
 *
 * Dynamic adjustment of sleeping times is done in "new" mode
 * where we are depending on syscall returns and lro returns
 * to push hpts forward mainly and the timer is only a backstop.
 *
 * When we are in the "new" mode i.e. conn_cnt > conn_cnt_thresh
 * then we do a dynamic adjustment on the time we sleep.
 * Our threshold is if the lateness of the first client served (in ticks) is
 * greater than or equal too ticks_indicate_more_sleep (10ms
 * or 10000 ticks). If we were that late, the actual sleep time
 * is adjusted down by 50%. If the ticks_ran is less than
 * ticks_indicate_more_sleep (100 ticks or 1000usecs).
 *
 */

#ifdef _KERNEL
void tcp_hpts_init(struct tcpcb *);
void tcp_hpts_remove(struct tcpcb *);
static inline bool
tcp_in_hpts(struct tcpcb *tp)
{
	return ((tp->t_in_hpts == IHPTS_ONQUEUE) ||
		((tp->t_in_hpts == IHPTS_MOVING) &&
		 (tp->t_hpts_slot != -1)));
}

/*
 * To insert a TCB on the hpts you *must* be holding the
 * INP_WLOCK(). The hpts insert code will then acqurire
 * the hpts's lock and insert the TCB on the requested
 * slot possibly waking up the hpts if you are requesting
 * a time earlier than what the hpts is sleeping to (if
 * the hpts is sleeping). You may check the inp->inp_in_hpts
 * flag without the hpts lock. The hpts is the only one
 * that will clear this flag holding only the hpts lock. This
 * means that in your tcp_output() routine when you test for
 * it to be 1 (so you wont call output) it may be transitioning
 * to 0 (by the hpts). That will be fine since that will just
 * mean an extra call to tcp_output that most likely will find
 * the call you executed (when the mis-match occurred) will have
 * put the TCB back on the hpts and it will return. If your
 * call did not add it back to the hpts then you will either
 * over-send or the cwnd will block you from sending more.
 *
 * Note you should also be holding the INP_WLOCK() when you
 * call the remove from the hpts as well. Thoug usually
 * you are either doing this from a timer, where you need
 * that INP_WLOCK() or from destroying your TCB where again
 * you should already have the INP_WLOCK().
 */
uint32_t tcp_hpts_insert_diag(struct tcpcb *tp, uint32_t slot, int32_t line,
    struct hpts_diag *diag);
#define	tcp_hpts_insert(inp, slot)	\
	tcp_hpts_insert_diag((inp), (slot), __LINE__, NULL)

void __tcp_set_hpts(struct tcpcb *tp, int32_t line);
#define tcp_set_hpts(a) __tcp_set_hpts(a, __LINE__)

void tcp_set_inp_to_drop(struct inpcb *inp, uint16_t reason);

void tcp_lro_hpts_init(void);
void tcp_lro_hpts_uninit(void);

extern int32_t tcp_min_hptsi_time;

#endif /* _KERNEL */

/*
 * The following functions should also be available
 * to userspace as well.
 */
static __inline uint32_t
tcp_tv_to_hptstick(const struct timeval *sv)
{
	return ((sv->tv_sec * 100000) + (sv->tv_usec / HPTS_TICKS_PER_SLOT));
}

static __inline uint32_t
tcp_tv_to_usectick(const struct timeval *sv)
{
	return ((uint32_t) ((sv->tv_sec * HPTS_USEC_IN_SEC) + sv->tv_usec));
}

static __inline uint32_t
tcp_tv_to_mssectick(const struct timeval *sv)
{
	return ((uint32_t) ((sv->tv_sec * HPTS_MSEC_IN_SEC) + (sv->tv_usec/HPTS_USEC_IN_MSEC)));
}

static __inline uint64_t
tcp_tv_to_lusectick(const struct timeval *sv)
{
	return ((uint64_t)((sv->tv_sec * HPTS_USEC_IN_SEC) + sv->tv_usec));
}

#ifdef _KERNEL

extern int32_t tcp_min_hptsi_time;

static inline int32_t
get_hpts_min_sleep_time(void)
{
	return (tcp_min_hptsi_time + HPTS_TICKS_PER_SLOT);
}

static __inline uint32_t
tcp_gethptstick(struct timeval *sv)
{
	struct timeval tv;

	if (sv == NULL)
		sv = &tv;
	microuptime(sv);
	return (tcp_tv_to_hptstick(sv));
}

static __inline uint64_t
tcp_get_u64_usecs(struct timeval *tv)
{
	struct timeval tvd;

	if (tv == NULL)
		tv = &tvd;
	microuptime(tv);
	return (tcp_tv_to_lusectick(tv));
}

static __inline uint32_t
tcp_get_usecs(struct timeval *tv)
{
	struct timeval tvd;

	if (tv == NULL)
		tv = &tvd;
	microuptime(tv);
	return (tcp_tv_to_usectick(tv));
}

#endif /* _KERNEL */
#endif /* __tcp_hpts_h__ */