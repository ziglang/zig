#include <stdlib.h>
#include <stdint.h>
#include <limits.h>
#include <errno.h>
#include <sys/mman.h>
#include "libc.h"
#include "lock.h"
#include "syscall.h"
#include "fork_impl.h"

#define ALIGN 16

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

static volatile int lock[1];
volatile int *const __bump_lockptr = lock;

static void *__simple_malloc(size_t n)
{
	static uintptr_t brk, cur, end;
	static unsigned mmap_step;
	size_t align=1;
	void *p;

	if (n > SIZE_MAX/2) {
		errno = ENOMEM;
		return 0;
	}

	if (!n) n++;
	while (align<n && align<ALIGN)
		align += align;

	LOCK(lock);

	cur += -cur & align-1;

	if (n > end-cur) {
		size_t req = n - (end-cur) + PAGE_SIZE-1 & -PAGE_SIZE;

		if (!cur) {
			brk = __syscall(SYS_brk, 0);
			brk += -brk & PAGE_SIZE-1;
			cur = end = brk;
		}

		if (brk == end && req < SIZE_MAX-brk
		    && !traverses_stack_p(brk, brk+req)
		    && __syscall(SYS_brk, brk+req)==brk+req) {
			brk = end += req;
		} else {
			int new_area = 0;
			req = n + PAGE_SIZE-1 & -PAGE_SIZE;
			/* Only make a new area rather than individual mmap
			 * if wasted space would be over 1/8 of the map. */
			if (req-n > req/8) {
				/* Geometric area size growth up to 64 pages,
				 * bounding waste by 1/8 of the area. */
				size_t min = PAGE_SIZE<<(mmap_step/2);
				if (min-n > end-cur) {
					if (req < min) {
						req = min;
						if (mmap_step < 12)
							mmap_step++;
					}
					new_area = 1;
				}
			}
			void *mem = __mmap(0, req, PROT_READ|PROT_WRITE,
				MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
			if (mem == MAP_FAILED || !new_area) {
				UNLOCK(lock);
				return mem==MAP_FAILED ? 0 : mem;
			}
			cur = (uintptr_t)mem;
			end = cur + req;
		}
	}

	p = (void *)cur;
	cur += n;
	UNLOCK(lock);
	return p;
}

weak_alias(__simple_malloc, __libc_malloc_impl);

void *__libc_malloc(size_t n)
{
	return __libc_malloc_impl(n);
}

static void *default_malloc(size_t n)
{
	return __libc_malloc_impl(n);
}

weak_alias(default_malloc, malloc);
