#ifndef __tim_filter_h__
#define __tim_filter_h__
/*-
 * Copyright (c) 2016-9 Netflix, Inc.
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
/*
 * Author: Randall Stewart <rrs@netflix.com>
 */

#include <sys/types.h>
#include <machine/param.h>
/* 
 * Do not change the size unless you know what you are
 * doing, the current size of 5 is designed around
 * the cache-line size for an amd64 processor. Other processors
 * may need other sizes.
 */
#define NUM_FILTER_ENTRIES 3

struct filter_entry {
	uint64_t value;		/* Value */
	uint32_t time_up;	/* Time updated */
} __packed ;

struct filter_entry_small {
	uint32_t value;		/* Value */
	uint32_t time_up;	/* Time updated */
};

struct time_filter {
	uint32_t cur_time_limit;
	struct filter_entry entries[NUM_FILTER_ENTRIES];
#ifdef _KERNEL
} __aligned(CACHE_LINE_SIZE);
#else	
};
#endif
struct time_filter_small {
	uint32_t cur_time_limit;
	struct filter_entry_small entries[NUM_FILTER_ENTRIES];
};

/*
 * To conserve on space there is a code duplication here (this
 * is where polymophism would be nice in the kernel). Everything
 * is duplicated to have a filter with a value of uint32_t instead
 * of a uint64_t. This saves 20 bytes and the structure size
 * drops to 44 from 64. The bad part about this is you end
 * up with two sets of functions. The xxx_small() access
 * the uint32_t value's where the xxx() the uint64_t values.
 * This forces the user to keep straight which type of structure
 * they allocated and which call they need to make. crossing
 * over calls will create either invalid memory references or
 * very bad results :)
 */

#define FILTER_TYPE_MIN 1
#define FILTER_TYPE_MAX 2

#ifdef _KERNEL
int setup_time_filter(struct time_filter *tf, int fil_type, uint32_t time_len);
void reset_time(struct time_filter *tf, uint32_t time_len);
void forward_filter_clock(struct time_filter *tf, uint32_t ticks_forward);
void tick_filter_clock(struct time_filter *tf, uint32_t now);
uint32_t apply_filter_min(struct time_filter *tf, uint64_t value, uint32_t now);
uint32_t apply_filter_max(struct time_filter *tf, uint64_t value, uint32_t now);
void filter_reduce_by(struct time_filter *tf, uint64_t reduce_by, uint32_t now);
void filter_increase_by(struct time_filter *tf, uint64_t incr_by, uint32_t now);
static uint64_t inline
get_filter_value(struct time_filter *tf)
{
	return(tf->entries[0].value);
}

static uint32_t inline
get_cur_timelim(struct time_filter *tf)
{
	return(tf->cur_time_limit);
}

int setup_time_filter_small(struct time_filter_small *tf,
			    int fil_type, uint32_t time_len);
void reset_time_small(struct time_filter_small *tf, uint32_t time_len);
void forward_filter_clock_small(struct time_filter_small *tf,
				uint32_t ticks_forward);
void tick_filter_clock_small(struct time_filter_small *tf, uint32_t now);
uint32_t apply_filter_min_small(struct time_filter_small *tf,
				uint32_t value, uint32_t now);
uint32_t apply_filter_max_small(struct time_filter_small *tf,
				uint32_t value, uint32_t now);
void filter_reduce_by_small(struct time_filter_small *tf,
			    uint32_t reduce_by, uint32_t now);
void filter_increase_by_small(struct time_filter_small *tf,
			      uint32_t incr_by, uint32_t now);
static uint64_t inline
get_filter_value_small(struct time_filter_small *tf)
{
	return(tf->entries[0].value);
}

static uint32_t inline
get_cur_timelim_small(struct time_filter_small *tf)
{
	return(tf->cur_time_limit);
}

#endif
#endif