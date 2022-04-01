
/* Missing:
   OP_GC_RAWREFCOUNT_INIT(callback, r): the callback is not supported here
   OP_GC_RAWREFCOUNT_CREATE_LINK_PYOBJ(): not implemented, maybe not needed
*/
#define RPY_USES_RAWREFCOUNT

#ifdef RPY_REVERSE_DEBUGGER
/* these macros are defined in src-revdb/revdb_include.h */
#else
#define OP_GC_RAWREFCOUNT_CREATE_LINK_PYPY(gcobj, pyobj, r)   \
    gc_rawrefcount_create_link_pypy(gcobj, pyobj)

#define OP_GC_RAWREFCOUNT_FROM_OBJ(gcobj, r)   \
    r = gc_rawrefcount_from_obj(gcobj)

#define OP_GC_RAWREFCOUNT_TO_OBJ(pyobj, r)   \
    r = gc_rawrefcount_to_obj(pyobj)

#define OP_GC_RAWREFCOUNT_NEXT_DEAD(r)   \
    r = gc_rawrefcount_next_dead()
#endif

#define OP_GC_RAWREFCOUNT_MARK_DEALLOCATING(gcobj, pyobj, r)  /* nothing */


RPY_EXTERN void gc_rawrefcount_create_link_pypy(/*gcobj_t*/void *gcobj, 
                                                /*pyobj_t*/void *pyobj);
RPY_EXTERN /*pyobj_t*/void *gc_rawrefcount_from_obj(/*gcobj_t*/void *gcobj);
RPY_EXTERN /*gcobj_t*/void *gc_rawrefcount_to_obj(/*pyobj_t*/void *pyobj);
RPY_EXTERN /*pyobj_t*/void *gc_rawrefcount_next_dead(void);
