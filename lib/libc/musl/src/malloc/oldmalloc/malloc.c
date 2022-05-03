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
#include "fork_impl.h"

#define malloc __libc_malloc_impl
#define realloc __libc_realloc
#define free __libc_free

#if defined(__GNUC__) && defined(__PIC__)
#define inline inline __attribute__((always_inline))
#endif

static struct {
	volatile uint64_t binmap;
	struct bin bins[64];
	volatile int split_merge_lock[2];
} mal;

/* Synchronization tools */

static inline void lock(volatile int *lk)
{
	int need_locks = libc.need_locks;
	if (need_locks) {
		while(a_swap(lk, 1)) __wait(lk, lk+1, 1, 1);
		if (need_locks < 0) libc.need_locks = 0;
	}
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

/* This function returns true if the interval [old,new]
 * intersects the 'len'-sized interval below &libc.auxv
 * (interpreted as the main-thread stack) or below &b
 * (the current stack). It is used to defend against
 * buggy brk implementations that can cross the stack. */

static int traverses_stack_p(uintptr_t old, uintptr_t new)
{
	const uintptr_t len = 8<<20;
	uintptr_t a, b;

	b = (uintptr_t)libc.auxv;
	a = b > len ? b-len : 0;
	if (new>a && old<b) return 1;

	b = (uintptr_t)&b;
	a = b > len ? b-len : 0;
	if (new>a && old<b) return 1;

	return 0;
}

/* Expand the heap in-place if brk can be used, or otherwise via mmap,
 * using an exponential lower bound on growth by mmap to make
 * fragmentation asymptotically irrelevant. The size argument is both
 * an input and an output, since the caller needs to know the size
 * allocated, which will be larger than requested due to page alignment
 * and mmap minimum size rules. The caller is responsible for locking
 * to prevent concurrent calls. */

static void *__expand_heap(size_t *pn)
{
	static uintptr_t brk;
	static unsigned mmap_step;
	size_t n = *pn;

	if (n > SIZE_MAX/2 - PAGE_SIZE) {
		errno = ENOMEM;
		return 0;
	}
	n += -n & PAGE_SIZE-1;

	if (!brk) {
		brk = __syscall(SYS_brk, 0);
		brk += -brk & PAGE_SIZE-1;
	}

	if (n < SIZE_MAX-brk && !traverses_stack_p(brk, brk+n)
	    && __syscall(SYS_brk, brk+n)==brk+n) {
		*pn = n;
		brk += n;
		return (void *)(brk-n);
	}

	size_t min = (size_t)PAGE_SIZE << mmap_step/2;
	if (n < min) n = min;
	void *area = __mmap(0, n, PROT_READ|PROT_WRITE,
		MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
	if (area == MAP_FAILED) return 0;
	*pn = n;
	mmap_step++;
	return area;
}

static struct chunk *expand_heap(size_t n)
{
	static void *end;
	void *p;
	struct chunk *w;

	/* The argument n already accounts for the caller's chunk
	 * overhead needs, but if the heap can't be extended in-place,
	 * we need room for an extra zero-sized sentinel chunk. */
	n += SIZE_ALIGN;

	p = __expand_heap(&n);
	if (!p) return 0;

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

static void bin_chunk(struct chunk *self, int i)
{
	self->next = BIN_TO_CHUNK(i);
	self->prev = mal.bins[i].tail;
	self->next->prev = self;
	self->prev->next = self;
	if (self->prev == BIN_TO_CHUNK(i))
		a_or_64(&mal.binmap, 1ULL<<i);
}

static void trim(struct chunk *self, size_t n)
{
	size_t n1 = CHUNK_SIZE(self);
	struct chunk *next, *split;

	if (n >= n1 - DONTCARE) return;

	next = NEXT_CHUNK(self);
	split = (void *)((char *)self + n);

	split->psize = n | C_INUSE;
	split->csize = n1-n;
	next->psize = n1-n;
	self->csize = n | C_INUSE;

	int i = bin_index(n1-n);
	lock_bin(i);

	bin_chunk(split, i);

	unlock_bin(i);
}

void *malloc(size_t n)
{
	struct chunk *c;
	int i, j;
	uint64_t mask;

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
	if (i<63 && (mal.binmap & (1ULL<<i))) {
		lock_bin(i);
		c = mal.bins[i].head;
		if (c != BIN_TO_CHUNK(i) && CHUNK_SIZE(c)-n <= DONTCARE) {
			unbin(c, i);
			unlock_bin(i);
			return CHUNK_TO_MEM(c);
		}
		unlock_bin(i);
	}
	lock(mal.split_merge_lock);
	for (mask = mal.binmap & -(1ULL<<i); mask; mask -= (mask&-mask)) {
		j = first_set(mask);
		lock_bin(j);
		c = mal.bins[j].head;
		if (c != BIN_TO_CHUNK(j)) {
			unbin(c, j);
			unlock_bin(j);
			break;
		}
		unlock_bin(j);
	}
	if (!mask) {
		c = expand_heap(n);
		if (!c) {
			unlock(mal.split_merge_lock);
			return 0;
		}
	}
	trim(c, n);
	unlock(mal.split_merge_lock);
	return CHUNK_TO_MEM(c);
}

int __malloc_allzerop(void *p)
{
	return IS_MMAPPED(MEM_TO_CHUNK(p));
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

	if (n<=n0 && n0-n<=DONTCARE) return p;

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

	if (n < n0) {
		int i = bin_index_up(n);
		int j = bin_index(n0);
		if (i<j && (mal.binmap & (1ULL << i)))
			goto copy_realloc;
		struct chunk *split = (void *)((char *)self + n);
		self->csize = split->psize = n | C_INUSE;
		split->csize = next->psize = n0-n | C_INUSE;
		__bin_chunk(split);
		return CHUNK_TO_MEM(self);
	}

	lock(mal.split_merge_lock);

	size_t nsize = next->csize & C_INUSE ? 0 : CHUNK_SIZE(next);
	if (n0+nsize >= n) {
		int i = bin_index(nsize);
		lock_bin(i);
		if (!(next->csize & C_INUSE)) {
			unbin(next, i);
			unlock_bin(i);
			next = NEXT_CHUNK(next);
			self->csize = next->psize = n0+nsize | C_INUSE;
			trim(self, n);
			unlock(mal.split_merge_lock);
			return CHUNK_TO_MEM(self);
		}
		unlock_bin(i);
	}
	unlock(mal.split_merge_lock);

copy_realloc:
	/* As a last resort, allocate a new chunk and copy to it. */
	new = malloc(n-OVERHEAD);
	if (!new) return 0;
copy_free_ret:
	memcpy(new, p, (n<n0 ? n : n0) - OVERHEAD);
	free(CHUNK_TO_MEM(self));
	return new;
}

void __bin_chunk(struct chunk *self)
{
	struct chunk *next = NEXT_CHUNK(self);

	/* Crash on corrupted footer (likely from buffer overflow) */
	if (next->psize != self->csize) a_crash();

	lock(mal.split_merge_lock);

	size_t osize = CHUNK_SIZE(self), size = osize;

	/* Since we hold split_merge_lock, only transition from free to
	 * in-use can race; in-use to free is impossible */
	size_t psize = self->psize & C_INUSE ? 0 : CHUNK_PSIZE(self);
	size_t nsize = next->csize & C_INUSE ? 0 : CHUNK_SIZE(next);

	if (psize) {
		int i = bin_index(psize);
		lock_bin(i);
		if (!(self->psize & C_INUSE)) {
			struct chunk *prev = PREV_CHUNK(self);
			unbin(prev, i);
			self = prev;
			size += psize;
		}
		unlock_bin(i);
	}
	if (nsize) {
		int i = bin_index(nsize);
		lock_bin(i);
		if (!(next->csize & C_INUSE)) {
			unbin(next, i);
			next = NEXT_CHUNK(next);
			size += nsize;
		}
		unlock_bin(i);
	}

	int i = bin_index(size);
	lock_bin(i);

	self->csize = size;
	next->psize = size;
	bin_chunk(self, i);
	unlock(mal.split_merge_lock);

	/* Replace middle of large chunks with fresh zero pages */
	if (size > RECLAIM && (size^(size-osize)) > size-osize) {
		uintptr_t a = (uintptr_t)self + SIZE_ALIGN+PAGE_SIZE-1 & -PAGE_SIZE;
		uintptr_t b = (uintptr_t)next - SIZE_ALIGN & -PAGE_SIZE;
		int e = errno;
#if 1
		__madvise((void *)a, b-a, MADV_DONTNEED);
#else
		__mmap((void *)a, b-a, PROT_READ|PROT_WRITE,
			MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED, -1, 0);
#endif
		errno = e;
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
	int e = errno;
	__munmap(base, len);
	errno = e;
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

void __malloc_atfork(int who)
{
	if (who<0) {
		lock(mal.split_merge_lock);
		for (int i=0; i<64; i++)
			lock(mal.bins[i].lock);
	} else if (!who) {
		for (int i=0; i<64; i++)
			unlock(mal.bins[i].lock);
		unlock(mal.split_merge_lock);
	} else {
		for (int i=0; i<64; i++)
			mal.bins[i].lock[0] = mal.bins[i].lock[1] = 0;
		mal.split_merge_lock[1] = 0;
		mal.split_merge_lock[0] = 0;
	}
}
