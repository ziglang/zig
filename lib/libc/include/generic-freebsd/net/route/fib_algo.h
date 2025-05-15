/*-
 * Copyright (c) 2020
 * 	Alexander V. Chernikov <melifaro@FreeBSD.org>
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


struct fib_data;
struct fib_dp;
enum flm_op_result {
	FLM_SUCCESS,	/* No errors, operation successful */
	FLM_REBUILD,	/* Operation cannot be completed, schedule algorithm rebuild */
	FLM_ERROR,	/* Operation failed, this algo cannot be used */
	FLM_BATCH,	/* Operation cannot be completed, algorithm asks to batch changes */
};

struct rib_rtable_info {
	uint32_t num_prefixes;
	uint32_t num_nhops;
	uint32_t num_nhgrp;
};

struct flm_lookup_key {
	union {
		const struct in6_addr *addr6;
		struct in_addr addr4;
	};
};

struct fib_change_entry {
	union {
		struct in_addr	addr4;
		struct in6_addr	addr6;
	};
	uint32_t		scopeid;
	uint8_t			plen;
	struct nhop_object	*nh_old;
	struct nhop_object	*nh_new;
};

struct fib_change_queue {
	uint32_t 		count;
	uint32_t		size;
	struct fib_change_entry	*entries;
};


typedef struct nhop_object *flm_lookup_t(void *algo_data,
    const struct flm_lookup_key key, uint32_t scopeid);
typedef enum flm_op_result flm_init_t (uint32_t fibnum, struct fib_data *fd,
    void *_old_data, void **new_data);
typedef void flm_destroy_t(void *data);
typedef enum flm_op_result flm_dump_t(struct rtentry *rt, void *data);
typedef enum flm_op_result flm_dump_end_t(void *data, struct fib_dp *dp);
typedef enum flm_op_result flm_change_t(struct rib_head *rnh,
    struct rib_cmd_info *rc, void *data);
typedef enum flm_op_result flm_change_batch_t(struct rib_head *rnh,
    struct fib_change_queue *q, void *data);
typedef uint8_t flm_get_pref_t(const struct rib_rtable_info *rinfo);

struct fib_lookup_module {
	char		*flm_name;		/* algo name */
	int		flm_family;		/* address family this module supports */
	int		flm_refcount;		/* # of references */
	uint32_t	flm_flags;		/* flags */
	uint8_t		flm_index;		/* internal algo index */
	flm_init_t	*flm_init_cb;		/* instance init */
	flm_destroy_t	*flm_destroy_cb;	/* destroy instance */
	flm_change_t	*flm_change_rib_item_cb;/* routing table change hook */
	flm_dump_t	*flm_dump_rib_item_cb;	/* routing table dump cb */
	flm_dump_end_t	*flm_dump_end_cb;	/* end of dump */
	flm_lookup_t	*flm_lookup;		/* lookup function */
	flm_get_pref_t	*flm_get_pref;		/* get algo preference */
	flm_change_batch_t	*flm_change_rib_items_cb;/* routing table change hook */
	void		*spare[8];		/* Spare callbacks */
	TAILQ_ENTRY(fib_lookup_module)	entries;
};

/* Datapath lookup data */
struct fib_dp {
	flm_lookup_t	*f;
	void		*arg;
};

VNET_DECLARE(struct fib_dp *, inet_dp);
#define	V_inet_dp	VNET(inet_dp)
VNET_DECLARE(struct fib_dp *, inet6_dp);
#define	V_inet6_dp	VNET(inet6_dp)

#define	FIB_PRINTF(_l, _fd, _fmt, ...)	fib_printf(_l, _fd, __func__, _fmt, ##__VA_ARGS__)

void fib_printf(int level, struct fib_data *fd, const char *func, char *fmt, ...);
int fib_module_init(struct fib_lookup_module *flm, uint32_t fibnum,
    int family);
int fib_module_clone(const struct fib_lookup_module *flm_orig,
    struct fib_lookup_module *flm, bool waitok);
int fib_module_dumptree(struct fib_lookup_module *flm,
    enum rib_subscription_type subscription_type);
int fib_module_register(struct fib_lookup_module *flm);
int fib_module_unregister(struct fib_lookup_module *flm);

uint32_t fib_get_nhop_idx(struct fib_data *fd, struct nhop_object *nh);
struct nhop_object **fib_get_nhop_array(struct fib_data *fd);
void fib_get_rtable_info(struct rib_head *rh, struct rib_rtable_info *rinfo);
struct rib_head *fib_get_rh(struct fib_data *fd);
bool fib_set_datapath_ptr(struct fib_data *fd, struct fib_dp *dp);
void fib_set_algo_ptr(struct fib_data *fd, void *algo_data);
void fib_epoch_call(epoch_callback_t callback, epoch_context_t ctx);