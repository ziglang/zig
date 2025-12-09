#ifndef __sack_filter_h__
#define __sack_filter_h__
/*-
 * Copyright (c) 2017-9 Netflix, Inc.
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

/**
 *
 * The Sack filter is designed to do two functions, first it trys to reduce
 * the processing of sacks. Consider that often times you get something like
 *
 * ack 1 (sack 100:200)
 * ack 1 (sack 100:300)
 * ack 1 (sack(100:400)
 *
 * You really want to process the 100:200 and then on the next sack process
 * only 200:300 (the new data) and then finally on the third 300:400. The filter
 * removes from your processing routines the already processed sack information so
 * that after the filter completes you only have "new" sacks that you have not
 * processed. This saves computation time so you do not need to worry about
 * previously processed sack information.
 *
 * The second thing that the sack filter does is help protect against malicious
 * attackers that are trying to attack any linked lists (or other data structures)
 * that are used in sack processing. Consider an attacker sending in sacks for
 * every other byte of data outstanding. This could in theory drastically split
 * up any scoreboard you are maintaining and make you search through a very large
 * linked list (or other structure) eating up CPU. If you split far enough and
 * fracture your data structure enough you could potentially be crippled by a malicious
 * peer. How the filter works here is it filters out sacks that are less than an MSS.
 * We do this because generally a packet (aka MSS) should be kept whole. The only place
 * we allow a smaller SACK is when the SACK touches the end of our socket buffer. This allows
 * TLP to still work properly and yet protects us from splitting. The filter also only allows
 * a set number of splits (defined in SACK_FILTER_BLOCKS). If more than that many sacks locations
 * are being sent we discard additional ones until the earlier holes are filled up. The maximum
 * the current filter can be is 15, which we have moved to since we want to be as generous as
 * possible with allowing for loss. However, in previous testing of the filter it was found
 * that there was very little benefit from moving from 7 to 15 sack points. Though at
 * that previous set of tests, we would just discard earlier information in the filter. Now
 * that we do not do that i.e. discard information and instead drop sack data we have raised
 * the value to the max i.e. 15. If you want to expand beyond 15 one would have to either increase
 * the size of the sf_bits to a uint32_t which could then get you a maximum of 31 splits or
 * move to a true bitstring. If this is done however it further increases your risk to
 * sack attacks, the bigger the number of splits (filter blocks) that are allowed
 * the larger your processing arrays will grow as well as the filter.
 *
 * Note that this protection does not prevent an attacker from asking for a 20 byte
 * MSS, that protection must be done elsewhere during the negotiation of the connection
 * and is done now by just ignoring sack's from connections with too small of MSS which
 * prevents sack from working and thus makes the connection less efficient but protects
 * the system from harm.
 *
 * We may actually want to consider dropping the size of the array back to 7 to further
 * protect the system which would be a more cautious approach.
 *
 * TCP Developer information:
 *
 * To use the sack filter its actually pretty simple. All you do is the normal sorting
 * and sanity checks of your sacks but then after that you call out to sack_filter_blks()
 * passing in the tcpcb, the sack-filter you are using (memory you have allocated) the
 * pointer to the sackblk array and how many sorted valid blocks there are as well
 * as what the new th_ack point is. The filter will return to you the number of
 * blocks left after filtering. It will reshape the blocks based on the previous
 * sacks you have received and processed. If sack_filter_blks() returns 0 then no
 * new sack data is present to be processed.
 *
 * Whenever you reach the point of snd_una == snd_max, you should call sack_filter_clear with
 * the snd_una point. You also need to call this if you invalidate your sack array for any
 * reason (such as RTO's or MTU changes or some other thing that makes you think all
 * data is now un-acknowledged). You can also pass in sack_filter_blks(tp, sf, NULL, 0, th_ack) to
 * advance the cum-ack point. You can use sack_filter_blks_used(sf) to determine if you have filter blocks as
 * well. So putting these two together, anytime the cum-ack moves forward you probably want to
 * do:
 * if (sack_filter_blks_used(sf))
 *    sack_filter_blks(tp, sf, NULL, 0, th_ack);
 *
 * If for some reason you have ran the sack-filter and something goes wrong (you can't allocate space
 * for example to split your sack-array. You can "undo" the data within the sack filter by calling
 * sack_filter_rject(sf, in) passing in the list of blocks to be "removed" from the sack-filter.
 * You can see an example of this use in bbr.c though rack.c has never found it needed.
 *
 */

#define SACK_FILTER_BLOCKS 15

struct sack_filter {
	tcp_seq sf_ack;
	uint16_t sf_bits;
	uint8_t sf_cur;
	uint8_t sf_used;
	struct sackblk sf_blks[SACK_FILTER_BLOCKS];
};
#ifdef _KERNEL
void sack_filter_clear(struct sack_filter *sf, tcp_seq seq);
int sack_filter_blks(struct tcpcb *tp, struct sack_filter *sf, struct sackblk *in, int numblks,
		     tcp_seq th_ack);
void sack_filter_reject(struct sack_filter *sf, struct sackblk *in);
static inline uint8_t sack_filter_blks_used(struct sack_filter *sf)
{
	return (sf->sf_used);
}

#endif
#endif