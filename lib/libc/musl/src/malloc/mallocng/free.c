#define _BSD_SOURCE
#include <stdlib.h>
#include <sys/mman.h>

#include "meta.h"

struct mapinfo {
	void *base;
	size_t len;
};

static struct mapinfo nontrivial_free(struct meta *, int);

static struct mapinfo free_group(struct meta *g)
{
	struct mapinfo mi = { 0 };
	int sc = g->sizeclass;
	if (sc < 48) {
		ctx.usage_by_class[sc] -= g->last_idx+1;
	}
	if (g->maplen) {
		step_seq();
		record_seq(sc);
		mi.base = g->mem;
		mi.len = g->maplen*4096UL;
	} else {
		void *p = g->mem;
		struct meta *m = get_meta(p);
		int idx = get_slot_index(p);
		g->mem->meta = 0;
		// not checking size/reserved here; it's intentionally invalid
		mi = nontrivial_free(m, idx);
	}
	free_meta(g);
	return mi;
}

static int okay_to_free(struct meta *g)
{
	int sc = g->sizeclass;

	if (!g->freeable) return 0;

	// always free individual mmaps not suitable for reuse
	if (sc >= 48 || get_stride(g) < UNIT*size_classes[sc])
		return 1;

	// always free groups allocated inside another group's slot
	// since recreating them should not be expensive and they
	// might be blocking freeing of a much larger group.
	if (!g->maplen) return 1;

	// if there is another non-full group, free this one to
	// consolidate future allocations, reduce fragmentation.
	if (g->next != g) return 1;

	// free any group in a size class that's not bouncing
	if (!is_bouncing(sc)) return 1;

	size_t cnt = g->last_idx+1;
	size_t usage = ctx.usage_by_class[sc];

	// if usage is high enough that a larger count should be
	// used, free the low-count group so a new one will be made.
	if (9*cnt <= usage && cnt < 20)
		return 1;

	// otherwise, keep the last group in a bouncing class.
	return 0;
}

static struct mapinfo nontrivial_free(struct meta *g, int i)
{
	uint32_t self = 1u<<i;
	int sc = g->sizeclass;
	uint32_t mask = g->freed_mask | g->avail_mask;

	if (mask+self == (2u<<g->last_idx)-1 && okay_to_free(g)) {
		// any multi-slot group is necessarily on an active list
		// here, but single-slot groups might or might not be.
		if (g->next) {
			assert(sc < 48);
			int activate_new = (ctx.active[sc]==g);
			dequeue(&ctx.active[sc], g);
			if (activate_new && ctx.active[sc])
				activate_group(ctx.active[sc]);
		}
		return free_group(g);
	} else if (!mask) {
		assert(sc < 48);
		// might still be active if there were no allocations
		// after last available slot was taken.
		if (ctx.active[sc] != g) {
			queue(&ctx.active[sc], g);
		}
	}
	a_or(&g->freed_mask, self);
	return (struct mapinfo){ 0 };
}

void free(void *p)
{
	if (!p) return;

	struct meta *g = get_meta(p);
	int idx = get_slot_index(p);
	size_t stride = get_stride(g);
	unsigned char *start = g->mem->storage + stride*idx;
	unsigned char *end = start + stride - IB;
	get_nominal_size(p, end);
	uint32_t self = 1u<<idx, all = (2u<<g->last_idx)-1;
	((unsigned char *)p)[-3] = 255;
	// invalidate offset to group header, and cycle offset of
	// used region within slot if current offset is zero.
	*(uint16_t *)((char *)p-2) = 0;

	// release any whole pages contained in the slot to be freed
	// unless it's a single-slot group that will be unmapped.
	if (((uintptr_t)(start-1) ^ (uintptr_t)end) >= 2*PGSZ && g->last_idx) {
		unsigned char *base = start + (-(uintptr_t)start & (PGSZ-1));
		size_t len = (end-base) & -PGSZ;
		if (len && USE_MADV_FREE) {
			int e = errno;
			madvise(base, len, MADV_FREE);
			errno = e;
		}
	}

	// atomic free without locking if this is neither first or last slot
	for (;;) {
		uint32_t freed = g->freed_mask;
		uint32_t avail = g->avail_mask;
		uint32_t mask = freed | avail;
		assert(!(mask&self));
		if (!freed || mask+self==all) break;
		if (!MT)
			g->freed_mask = freed+self;
		else if (a_cas(&g->freed_mask, freed, freed+self)!=freed)
			continue;
		return;
	}

	wrlock();
	struct mapinfo mi = nontrivial_free(g, idx);
	unlock();
	if (mi.len) {
		int e = errno;
		munmap(mi.base, mi.len);
		errno = e;
	}
}
