#ifndef _MALLOC_H
#define _MALLOC_H

#ifdef __cplusplus
extern "C" {
#endif

#define __NEED_size_t

#include <bits/alltypes.h>

#define M_SET_THREAD_CACHE (-1001)
#define M_THREAD_CACHE_ENABLE 1
#define M_THREAD_CACHE_DISABLE 0

#define M_FLUSH_THREAD_CACHE (-1002)

#define M_DELAYED_FREE (-1003)
#define M_DELAYED_FREE_ENABLE 1
#define M_DELAYED_FREE_DISABLE 0

#define M_OHOS_CONFIG (-1004)
#define M_DISABLE_OPT_TCACHE 100
#define M_ENABLE_OPT_TCACHE 101
#define M_TCACHE_PERFORMANCE_MODE 102
#define M_TCACHE_NORMAL_MODE 103

void *malloc (size_t);
void *calloc (size_t, size_t);
void *realloc (void *, size_t);
void free (void *);
void *valloc (size_t);
void *memalign(size_t, size_t);

size_t malloc_usable_size(void *);
int mallopt(int param, int value);

struct mallinfo {
  int arena;
  int ordblks;
  int smblks;
  int hblks;
  int hblkhd;
  int usmblks;
  int fsmblks;
  int uordblks;
  int fordblks;
  int keepcost;
};

struct mallinfo2 {
  size_t arena;
  size_t ordblks;
  size_t smblks;
  size_t hblks;
  size_t hblkhd;
  size_t usmblks;
  size_t fsmblks;
  size_t uordblks;
  size_t fordblks;
  size_t keepcost;
};

#ifdef __cplusplus
}
#endif

#endif
