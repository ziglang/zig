#ifndef MALLOC_GLUE_H
#define MALLOC_GLUE_H

#include <stdint.h>
#include <sys/mman.h>
#include <pthread.h>
#include <unistd.h>
#include <elf.h>
#include <string.h>
#include "atomic.h"
#include "syscall.h"
#include "libc.h"
#include "lock.h"
#include "dynlink.h"

// use macros to appropriately namespace these.
#define size_classes __malloc_size_classes
#define ctx __malloc_context
#define alloc_meta __malloc_alloc_meta
#define is_allzero __malloc_allzerop
#define dump_heap __dump_heap

#if USE_REAL_ASSERT
#include <assert.h>
#else
#undef assert
#define assert(x) do { if (!(x)) a_crash(); } while(0)
#endif

#define brk(p) ((uintptr_t)__syscall(SYS_brk, p))

#define mmap __mmap
#define madvise __madvise
#define mremap __mremap

#define DISABLE_ALIGNED_ALLOC (__malloc_replaced && !__aligned_alloc_replaced)

static inline uint64_t get_random_secret()
{
	uint64_t secret = (uintptr_t)&secret * 1103515245;
	for (size_t i=0; libc.auxv[i]; i+=2)
		if (libc.auxv[i]==AT_RANDOM)
			memcpy(&secret, (char *)libc.auxv[i+1]+8, sizeof secret);
	return secret;
}

#ifndef PAGESIZE
#define PAGESIZE PAGE_SIZE
#endif

#define MT (libc.need_locks)

#define RDLOCK_IS_EXCLUSIVE 1

__attribute__((__visibility__("hidden")))
extern int __malloc_lock[1];

#define LOCK_OBJ_DEF \
int __malloc_lock[1];

static inline void rdlock()
{
	if (MT) LOCK(__malloc_lock);
}
static inline void wrlock()
{
	if (MT) LOCK(__malloc_lock);
}
static inline void unlock()
{
	UNLOCK(__malloc_lock);
}
static inline void upgradelock()
{
}

#endif
