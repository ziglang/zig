
/************************************************************/
/***  C header subsection: operations on LowLevelTypes    ***/

#include <string.h>

/* used by rpython.rlib.rstack */
#define OP_STACK_CURRENT(r)  r = (Signed)&r


#define OP_RAW_MALLOC(size, zero, result)  {    \
        if (zero)                               \
            result = calloc(size, 1);           \
        else                                    \
            result = malloc(size);              \
        if (result != NULL) {                   \
            COUNT_MALLOC;                       \
        }                                       \
    }

#define OP_RAW_FREE(p, r) free(p); COUNT_FREE;

#define OP_RAW_MEMCLEAR(p, size, r) memset((void*)p, 0, size)
#define OP_RAW_MEMSET(p, byte, size, r) memset((void*)p, byte, size)

#define OP_RAW_MALLOC_USAGE(size, r) r = size

#if defined(MS_WINDOWS) && !defined(__MINGW32__)
#define alloca  _alloca
#endif

#define OP_RAW_MEMCOPY(x,y,size,r) memcpy(y,x,size);
#define OP_RAW_MEMMOVE(x,y,size,r) memmove(y,x,size);

/************************************************************/

#define OP_FREE(p)	OP_RAW_FREE(p, do_not_use)

#ifndef COUNT_OP_MALLOCS

#define COUNT_MALLOC	/* nothing */
#define COUNT_FREE	/* nothing */
#define pypy_malloc_counters_results()  /* nothing */

#else /* COUNT_OP_MALLOCS */

static int count_mallocs=0, count_frees=0;

#define COUNT_MALLOC	count_mallocs++
#define COUNT_FREE	count_frees++

#define pypy_malloc_counters_results()  \
    printf("MALLOC COUNTERS: %d %d\n", count_mallocs, count_frees)

#endif /* COUNT_OP_MALLOCS */


/*** tracking raw mallocs and frees for debugging ***/

#ifndef RPY_ASSERT

#  define OP_TRACK_ALLOC_START(addr, r)   /* nothing */
#  define OP_TRACK_ALLOC_STOP(addr, r)    /* nothing */
#  define pypy_debug_alloc_results() /* nothing */

#else /* RPY_ASSERT */

#  define OP_TRACK_ALLOC_START(addr, r)  pypy_debug_alloc_start(addr, \
                                                                __FUNCTION__)
#  define OP_TRACK_ALLOC_STOP(addr, r)   pypy_debug_alloc_stop(addr)

RPY_EXTERN void pypy_debug_alloc_start(void*, const char*);
RPY_EXTERN void pypy_debug_alloc_stop(void*);
RPY_EXTERN void pypy_debug_alloc_results(void);

#endif /* RPY_ASSERT */

/* for Boehm GC */

#ifdef PYPY_USING_BOEHM_GC

#define BOEHM_MALLOC_0_0   GC_MALLOC
#define BOEHM_MALLOC_1_0   GC_MALLOC_ATOMIC
#define BOEHM_MALLOC_0_1   GC_MALLOC
#define BOEHM_MALLOC_1_1   GC_MALLOC_ATOMIC
/* #define BOEHM_MALLOC_0_1   GC_MALLOC_IGNORE_OFF_PAGE */
/* #define BOEHM_MALLOC_1_1   GC_MALLOC_ATOMIC_IGNORE_OFF_PAGE */

#define OP_BOEHM_ZERO_MALLOC(size, r, restype, is_atomic, is_varsize) { \
	r = (restype) BOEHM_MALLOC_ ## is_atomic ## _ ## is_varsize (size); \
	if (r && is_atomic)  /* the non-atomic versions return cleared memory */ \
	    memset((void*) r, 0, size);					\
    }

#define OP_BOEHM_DISAPPEARING_LINK(link, obj, r)			\
    if (GC_base(obj) == NULL)						\
	; /* 'obj' is probably a prebuilt object - it makes no */	\
    /* sense to register it then, and it crashes Boehm in */		\
    /* quite obscure ways */						\
    else								\
	GC_GENERAL_REGISTER_DISAPPEARING_LINK(link, obj)

RPY_EXTERN int boehm_gc_finalizer_lock;
RPY_EXTERN void boehm_gc_startup_code(void);
RPY_EXTERN void boehm_gc_finalizer_notifier(void);
struct boehm_fq_s;
RPY_EXTERN struct boehm_fq_s *boehm_fq_queues[];
RPY_EXTERN void (*boehm_fq_trigger[])(void);
RPY_EXTERN void boehm_fq_register(struct boehm_fq_s **, void *);
RPY_EXTERN void *boehm_fq_next_dead(struct boehm_fq_s **);

#define OP_GC__DISABLE_FINALIZERS(r)  boehm_gc_finalizer_lock++
#define OP_GC__ENABLE_FINALIZERS(r)  (boehm_gc_finalizer_lock--,	\
				      boehm_gc_finalizer_notifier())
#define OP_GC__DISABLE(r)             /* nothing */
#define OP_GC__ENABLE(r)              /* nothing */

#define OP_BOEHM_FQ_REGISTER(tagindex, obj, r)                          \
    boehm_fq_register(boehm_fq_queues + tagindex, obj)
#define OP_BOEHM_FQ_NEXT_DEAD(tagindex, r)                              \
    r = boehm_fq_next_dead(boehm_fq_queues + tagindex)

#endif /* PYPY_USING_BOEHM_GC */


#ifdef PYPY_USING_NO_GC_AT_ALL
#define OP_BOEHM_ZERO_MALLOC(size, r, restype, is_atomic, is_varsize)	\
    r = (restype) calloc(1, size);
#define OP_BOEHM_DISAPPEARING_LINK(link, obj, r)  /* nothing */
#define OP_GC__DISABLE_FINALIZERS(r)  /* nothing */
#define OP_GC__ENABLE_FINALIZERS(r)  /* nothing */
#define OP_GC__DISABLE(r)             /* nothing */
#define OP_GC__ENABLE(r)              /* nothing */
#define GC_REGISTER_FINALIZER(a, b, c, d, e)  /* nothing */
#define GC_gcollect()  /* nothing */
#define GC_set_max_heap_size(a)  /* nothing */
#define OP_GC_FQ_REGISTER(tag, obj, r)   /* nothing */
#define OP_GC_FQ_NEXT_DEAD(tag, r)       (r = NULL)
#endif

#if (defined(PYPY_USING_BOEHM_GC) || defined(PYPY_USING_NO_GC_AT_ALL)) && !defined(PYPY_BOEHM_WITH_HEADER)
#  define RPY_SIZE_OF_GCHEADER  0
#else
#  define RPY_SIZE_OF_GCHEADER  sizeof(struct pypy_header0)
#endif

/************************************************************/
/* weakref support */

#define OP_CAST_PTR_TO_WEAKREFPTR(x, r)  r = x
#define OP_CAST_WEAKREFPTR_TO_PTR(x, r)  r = x

/************************************************************/
/* dummy version of these operations, e.g. with Boehm */

#define OP_GC_GET_RPY_ROOTS(r)           r = 0
#define OP_GC_GET_RPY_REFERENTS(x, r)    r = 0
#define OP_GC_GET_RPY_MEMORY_USAGE(x, r) r = -1
#define OP_GC_GET_RPY_TYPE_INDEX(x, r)   r = -1
#define OP_GC_IS_RPY_INSTANCE(x, r)      r = 0
#define OP_GC_DUMP_RPY_HEAP(fd, r)       r = 0
#define OP_GC_SET_EXTRA_THRESHOLD(x, r)  /* nothing */
#define OP_GC_IGNORE_FINALIZER(x, r)     /* nothing */

/****************************/
/* misc stuff               */
/****************************/

#ifndef _MSC_VER
#  define pypy_asm_keepalive(v)  asm volatile ("/* keepalive %0 */" : : \
                                               "g" (v))
#else
#  ifndef _WIN64
#    define pypy_asm_keepalive(v)    __asm { }
#  else
     /* is there something cheaper? */
#    define pypy_asm_keepalive(v)    _ReadWriteBarrier();
#  endif
#endif
