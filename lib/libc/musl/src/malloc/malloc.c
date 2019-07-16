#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <stdint.h>
#include <errno.h>
#include <sys/mman.h>
#include "libc.h"
#include "atomic.h"
#include "pthread_impl.h"
#include "malloc_impl.h"

#if defined(__GNUC__) && defined(__PIC__)
#define inline inline __attribute__((always_inline))
#endif

static struct {
	volatile uint64_t binmap;
	struct bin bins[64];
	volatile int free_lock[2];
} mal;

int __malloc_replaced;

/* Synchronization tools */

static inline void lock(volatile int *lk)
{
	if (libc.threads_minus_1)
		while(a_swap(lk, 1)) __wait(lk, lk+1, 1, 1);
}

static inline void unlock(volatile int *lk)
{
	if (lk[0]) {
		a_store(lk, 0);
		if (lk[1]) __wake(lk, 1, 1);
	}
}

static inline void lock_bin(int i)
{
	lock(mal.bins[i].lock);
	if (!mal.bins[i].head)
		mal.bins[i].head = mal.bins[i].tail = BIN_TO_CHUNK(i);
}

static inline void unlock_bin(int i)
{
	unlock(mal.bins[i].lock);
}

static int first_set(uint64_t x)
{
#if 1
	return a_ctz_64(x);
#else
	static const char debruijn64[64] = {
		0, 1, 2, 53, 3, 7, 54, 27, 4, 38, 41, 8, 34, 55, 48, 28,
		62, 5, 39, 46, 44, 42, 22, 9, 24, 35, 59, 56, 49, 18, 29, 11,
		63, 52, 6, 26, 37, 40, 33, 47, 61, 45, 43, 21, 23, 58, 17, 10,
		51, 25, 36, 32, 60, 20, 57, 16, 50, 31, 19, 15, 30, 14, 13, 12
	};
	static const char debruijn32[32] = {
		0, 1, 23, 2, 29, 24, 19, 3, 30, 27, 25, 11, 20, 8, 4, 13,
		31, 22, 28, 18, 26, 10, 7, 12, 21, 17, 9, 6, 16, 5, 15, 14
	};
	if (sizeof(long) < 8) {
		uint32_t y = x;
		if (!y) {
			y = x>>32;
			return 32 + debruijn32[(y&-y)*0x076be629 >> 27];
		}
		return debruijn32[(y&-y)*0x076be629 >> 27];
	}
	return debruijn64[(x&-x)*0x022fdd63cc95386dull >> 58];
#endif
}

static const unsigned char bin_tab[60] = {
	            32,33,34,35,36,36,37,37,38,38,39,39,
	40,40,40,40,41,41,41,41,42,42,42,42,43,43,43,43,
	44,44,44,44,44,44,44,44,45,45,45,45,45,45,45,45,
	46,46,46,46,46,46,46,46,47,47,47,47,47,47,47,47,
};

static int bin_index(size_t x)
{
	x = x / SIZE_ALIGN - 1;
	if (x <= 32) return x;
	if (x < 512) return bin_tab[x/8-4];
	if (x > 0x1c00) return 63;
	return bin_tab[x/128-4] + 16;
}

static int bin_index_up(size_t x)
{
	x = x / SIZE_ALIGN - 1;
	if (x <= 32) return x;
	x--;
	if (x < 512) return bin_tab[x/8-4] + 1;
	return bin_tab[x/128-4] + 17;
}

#if 0
void __dump_heap(int x)
{
	struct chunk *c;
	int i;
	for (c = (void *)mal.heap; CHUNK_SIZE(c); c = NEXT_CHUNK(c))
		fprintf(stderr, "base %p size %zu (%d) flags %d/%d\n",
			c, CHUNK_SIZE(c), bin_index(CHUNK_SIZE(c)),
			c->csize & 15,
			NEXT_CHUNK(c)->psize & 15);
	for (i=0; i<64; i++) {
		if (mal.bins[i].head != BIN_TO_CHUNK(i) && mal.bins[i].head) {
			fprintf(stderr, "bin %d: %p\n", i, mal.bins[i].head);
			if (!(mal.binmap & 1ULL<<i))
				fprintf(stderr, "missing from binmap!\n");
		} else if (mal.binmap & 1ULL<<i)
			fprintf(stderr, "binmap wrongly contains %d!\n", i);
	}
}
#endif

static struct chunk *expand_heap(size_t n)
{
	static int heap_lock[2];
	static void *end;
	void *p;
	struct chunk *w;

	/* The argument n already accounts for the caller's chunk
	 * overhead needs, but if the heap can't be extended in-place,
	 * we need room for an extra zero-sized sentinel chunk. */
	n += SIZE_ALIGN;

	lock(heap_lock);

	p = __expand_heap(&n);
	if (!p) {
		unlock(heap_lock);
		return 0;
	}

	/* If not just expanding existing space, we need to make a
	 * new sentinel chunk below the allocated space. */
	if (p != end) {
		/* Valid/safe because of the prologue increment. */
		n -= SIZE_ALIGN;
		p = (char *)p + SIZE_ALIGN;
		w = MEM_TO_CHUNK(p);
		w->psize = 0 | C_INUSE;
	}

	/* Record new heap end and fill in footer. */
	end = (char *)p + n;
	w = MEM_TO_CHUNK(end);
	w->psize = n | C_INUSE;
	w->csize = 0 | C_INUSE;

	/* Fill in header, which may be new or may be replacing a
	 * zero-size sentinel header at the old end-of-heap. */
	w = MEM_TO_CHUNK(p);
	w->csize = n | C_INUSE;

	unlock(heap_lock);

	return w;
}

static int adjust_size(size_t *n)
{
	/* Result of pointer difference must fit in ptrdiff_t. */
	if (*n-1 > PTRDIFF_MAX - SIZE_ALIGN - PAGE_SIZE) {
		if (*n) {
			errno = ENOMEM;
			return -1;
		} else {
			*n = SIZE_ALIGN;
			return 0;
		}
	}
	*n = (*n + OVERHEAD + SIZE_ALIGN - 1) & SIZE_MASK;
	return 0;
}

static void unbin(struct chunk *c, int i)
{
	if (c->prev == c->next)
		a_and_64(&mal.binmap, ~(1ULL<<i));
	c->prev->next = c->next;
	c->next->prev = c->prev;
	c->csize |= C_INUSE;
	NEXT_CHUNK(c)->psize |= C_INUSE;
}

static int alloc_fwd(struct chunk *c)
{
	int i;
	size_t k;
	while (!((k=c->csize) & C_INUSE)) {
		i = bin_index(k);
		lock_bin(i);
		if (c->csize == k) {
			unbin(c, i);
			unlock_bin(i);
			return 1;
		}
		unlock_bin(i);
	}
	return 0;
}

static int alloc_rev(struct chunk *c)
{
	int i;
	size_t k;
	while (!((k=c->psize) & C_INUSE)) {
		i = bin_index(k);
		lock_bin(i);
		if (c->psize == k) {
			unbin(PREV_CHUNK(c), i);
			unlock_bin(i);
			return 1;
		}
		unlock_bin(i);
	}
	return 0;
}


/* pretrim - trims a chunk _prior_ to removing it from its bin.
 * Must be called with i as the ideal bin for size n, j the bin
 * for the _free_ chunk self, and bin j locked. */
static int pretrim(struct chunk *self, size_t n, int i, int j)
{
	size_t n1;
	struct chunk *next, *split;

	/* We cannot pretrim if it would require re-binning. */
	if (j < 40) return 0;
	if (j < i+3) {
		if (j != 63) return 0;
		n1 = CHUNK_SIZE(self);
		if (n1-n <= MMAP_THRESHOLD) return 0;
	} else {
		n1 = CHUNK_SIZE(self);
	}
	if (bin_index(n1-n) != j) return 0;

	next = NEXT_CHUNK(self);
	split = (void *)((char *)self + n);

	split->prev = self->prev;
	split->next = self->next;
	split->prev->next = split;
	split->next->prev = split;
	split->psize = n | C_INUSE;
	split->csize = n1-n;
	next->psize = n1-n;
	self->csize = n | C_INUSE;
	return 1;
}

static void trim(struct chunk *self, size_t n)
{
	size_t n1 = CHUNK_SIZE(self);
	struct chunk *next, *split;

	if (n >= n1 - DONTCARE) return;

	next = NEXT_CHUNK(self);
	split = (void *)((char *)self + n);

	split->psize = n | C_INUSE;
	split->csize = n1-n | C_INUSE;
	next->psize = n1-n | C_INUSE;
	self->csize = n | C_INUSE;

	__bin_chunk(split);
}

void *malloc(size_t n)
{
	struct chunk *c;
	int i, j;

	if (adjust_size(&n) < 0) return 0;

	if (n > MMAP_THRESHOLD) {
		size_t len = n + OVERHEAD + PAGE_SIZE - 1 & -PAGE_SIZE;
		char *base = __mmap(0, len, PROT_READ|PROT_WRITE,
			MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
		if (base == (void *)-1) return 0;
		c = (void *)(base + SIZE_ALIGN - OVERHEAD);
		c->csize = len - (SIZE_ALIGN - OVERHEAD);
		c->psize = SIZE_ALIGN - OVERHEAD;
		return CHUNK_TO_MEM(c);
	}

	i = bin_index_up(n);
	for (;;) {
		uint64_t mask = mal.binmap & -(1ULL<<i);
		if (!mask) {
			c = expand_heap(n);
			if (!c) return 0;
			if (alloc_rev(c)) {
				struct chunk *x = c;
				c = PREV_CHUNK(c);
				NEXT_CHUNK(x)->psize = c->csize =
					x->csize + CHUNK_SIZE(c);
			}
			break;
		}
		j = first_set(mask);
		lock_bin(j);
		c = mal.bins[j].head;
		if (c != BIN_TO_CHUNK(j)) {
			if (!pretrim(c, n, i, j)) unbin(c, j);
			unlock_bin(j);
			break;
		}
		unlock_bin(j);
	}

	/* Now patch up in case we over-allocated */
	trim(c, n);

	return CHUNK_TO_MEM(c);
}

static size_t mal0_clear(char *p, size_t pagesz, size_t n)
{
#ifdef __GNUC__
	typedef uint64_t __attribute__((__may_alias__)) T;
#else
	typedef unsigned char T;
#endif
	char *pp = p + n;
	size_t i = (uintptr_t)pp & (pagesz - 1);
	for (;;) {
		pp = memset(pp - i, 0, i);
		if (pp - p < pagesz) return pp - p;
		for (i = pagesz; i; i -= 2*sizeof(T), pp -= 2*sizeof(T))
		        if (((T *)pp)[-1] | ((T *)pp)[-2])
				break;
	}
}

void *calloc(size_t m, size_t n)
{
	if (n && m > (size_t)-1/n) {
		errno = ENOMEM;
		return 0;
	}
	n *= m;
	void *p = malloc(n);
	if (!p) return p;
	if (!__malloc_replaced) {
		if (IS_MMAPPED(MEM_TO_CHUNK(p)))
			return p;
		if (n >= PAGE_SIZE)
			n = mal0_clear(p, PAGE_SIZE, n);
	}
	return memset(p, 0, n);
}

void *realloc(void *p, size_t n)
{
	struct chunk *self, *next;
	size_t n0, n1;
	void *new;

	if (!p) return malloc(n);

	if (adjust_size(&n) < 0) return 0;

	self = MEM_TO_CHUNK(p);
	n1 = n0 = CHUNK_SIZE(self);

	if (IS_MMAPPED(self)) {
		size_t extra = self->psize;
		char *base = (char *)self - extra;
		size_t oldlen = n0 + extra;
		size_t newlen = n + extra;
		/* Crash on realloc of freed chunk */
		if (extra & 1) a_crash();
		if (newlen < PAGE_SIZE && (new = malloc(n-OVERHEAD))) {
			n0 = n;
			goto copy_free_ret;
		}
		newlen = (newlen + PAGE_SIZE-1) & -PAGE_SIZE;
		if (oldlen == newlen) return p;
		base = __mremap(base, oldlen, newlen, MREMAP_MAYMOVE);
		if (base == (void *)-1)
			goto copy_realloc;
		self = (void *)(base + extra);
		self->csize = newlen - extra;
		return CHUNK_TO_MEM(self);
	}

	next = NEXT_CHUNK(self);

	/* Crash on corrupted footer (likely from buffer overflow) */
	if (next->psize != self->csize) a_crash();

	/* Merge adjacent chunks if we need more space. This is not
	 * a waste of time even if we fail to get enough space, because our
	 * subsequent call to free would otherwise have to do the merge. */
	if (n > n1 && alloc_fwd(next)) {
		n1 += CHUNK_SIZE(next);
		next = NEXT_CHUNK(next);
	}
	/* FIXME: find what's wrong here and reenable it..? */
	if (0 && n > n1 && alloc_rev(self)) {
		self = PREV_CHUNK(self);
		n1 += CHUNK_SIZE(self);
	}
	self->csize = n1 | C_INUSE;
	next->psize = n1 | C_INUSE;

	/* If we got enough space, split off the excess and return */
	if (n <= n1) {
		//memmove(CHUNK_TO_MEM(self), p, n0-OVERHEAD);
		trim(self, n);
		return CHUNK_TO_MEM(self);
	}

copy_realloc:
	/* As a last resort, allocate a new chunk and copy to it. */
	new = malloc(n-OVERHEAD);
	if (!new) return 0;
copy_free_ret:
	memcpy(new, p, n0-OVERHEAD);
	free(CHUNK_TO_MEM(self));
	return new;
}

void __bin_chunk(struct chunk *self)
{
	struct chunk *next = NEXT_CHUNK(self);
	size_t final_size, new_size, size;
	int reclaim=0;
	int i;

	final_size = new_size = CHUNK_SIZE(self);

	/* Crash on corrupted footer (likely from buffer overflow) */
	if (next->psize != self->csize) a_crash();

	for (;;) {
		if (self->psize & next->csize & C_INUSE) {
			self->csize = final_size | C_INUSE;
			next->psize = final_size | C_INUSE;
			i = bin_index(final_size);
			lock_bin(i);
			lock(mal.free_lock);
			if (self->psize & next->csize & C_INUSE)
				break;
			unlock(mal.free_lock);
			unlock_bin(i);
		}

		if (alloc_rev(self)) {
			self = PREV_CHUNK(self);
			size = CHUNK_SIZE(self);
			final_size += size;
			if (new_size+size > RECLAIM && (new_size+size^size) > size)
				reclaim = 1;
		}

		if (alloc_fwd(next)) {
			size = CHUNK_SIZE(next);
			final_size += size;
			if (new_size+size > RECLAIM && (new_size+size^size) > size)
				reclaim = 1;
			next = NEXT_CHUNK(next);
		}
	}

	if (!(mal.binmap & 1ULL<<i))
		a_or_64(&mal.binmap, 1ULL<<i);

	self->csize = final_size;
	next->psize = final_size;
	unlock(mal.free_lock);

	self->next = BIN_TO_CHUNK(i);
	self->prev = mal.bins[i].tail;
	self->next->prev = self;
	self->prev->next = self;

	/* Replace middle of large chunks with fresh zero pages */
	if (reclaim) {
		uintptr_t a = (uintptr_t)self + SIZE_ALIGN+PAGE_SIZE-1 & -PAGE_SIZE;
		uintptr_t b = (uintptr_t)next - SIZE_ALIGN & -PAGE_SIZE;
#if 1
		__madvise((void *)a, b-a, MADV_DONTNEED);
#else
		__mmap((void *)a, b-a, PROT_READ|PROT_WRITE,
			MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED, -1, 0);
#endif
	}

	unlock_bin(i);
}

static void unmap_chunk(struct chunk *self)
{
	size_t extra = self->psize;
	char *base = (char *)self - extra;
	size_t len = CHUNK_SIZE(self) + extra;
	/* Crash on double free */
	if (extra & 1) a_crash();
	__munmap(base, len);
}

void free(void *p)
{
	if (!p) return;

	struct chunk *self = MEM_TO_CHUNK(p);

	if (IS_MMAPPED(self))
		unmap_chunk(self);
	else
		__bin_chunk(self);
}

void __malloc_donate(char *start, char *end)
{
	size_t align_start_up = (SIZE_ALIGN-1) & (-(uintptr_t)start - OVERHEAD);
	size_t align_end_down = (SIZE_ALIGN-1) & (uintptr_t)end;

	/* Getting past this condition ensures that the padding for alignment
	 * and header overhead will not overflow and will leave a nonzero
	 * multiple of SIZE_ALIGN bytes between start and end. */
	if (end - start <= OVERHEAD + align_start_up + align_end_down)
		return;
	start += align_start_up + OVERHEAD;
	end   -= align_end_down;

	struct chunk *c = MEM_TO_CHUNK(start), *n = MEM_TO_CHUNK(end);
	c->psize = n->csize = C_INUSE;
	c->csize = n->psize = C_INUSE | (end-start);
	__bin_chunk(c);
}
