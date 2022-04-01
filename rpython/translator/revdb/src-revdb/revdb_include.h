#include <string.h>
#include "src/thread.h"

/************************************************************
 ***  RevDB --- record and replay debugging               ***
 ************************************************************/


typedef struct {
#ifndef RPY_RDB_REPLAY
    bool_t replay;
#define RPY_RDB_REPLAY   rpy_revdb.replay
#define RPY_RDB_DYNAMIC_REPLAY
#else
# error "explicit RPY_RDB_REPLAY: not really supported"
#endif
    bool_t watch_enabled;
    Signed lock;
    char *buf_p;  /* NULL during recording if recording is actually disabled */
    char *buf_limit, *buf_readend;
    uint64_t stop_point_seen, stop_point_break;
    uint64_t unique_id_seen, unique_id_break;
} rpy_revdb_t;

RPY_EXTERN rpy_revdb_t rpy_revdb;
RPY_EXTERN int rpy_rev_fileno;
RPY_EXTERN __thread int rpy_active_thread;


/* ------------------------------------------------------------ */

RPY_EXTERN void rpy_reverse_db_setup(int *argc_p, char **argv_p[]);
RPY_EXTERN int rpy_reverse_db_main(Signed entry_point(Signed, char**),
                                   int argc, char **argv);

/* enable to print locations to stderr of all the EMITs */
#ifdef RPY_REVDB_PRINT_ALL
#  define _RPY_REVDB_PRINT(mode, _e)                                    \
    if (rpy_rev_fileno >= 0) {                                          \
        fprintf(stderr,                                                 \
                "%s %s:%d: %0*llx\n",                                   \
                mode, __FILE__, (int)__LINE__, (int)(2 * sizeof(_e)),   \
                ((unsigned long long)_e) & ((2ULL << (8*sizeof(_e)-1)) - 1)); \
    }
#endif

/* enable to print all mallocs to stderr */
#ifdef RPY_REVDB_PRINT_ALL
RPY_EXTERN void seeing_uid(uint64_t uid);
#  define _RPY_REVDB_PRUID()                                            \
    if (rpy_rev_fileno >= 0) {                                          \
        seeing_uid(uid);                                                \
        fprintf(stderr,                                                 \
                "[nobj] %s:%d: obj %llu\n",                             \
                __FILE__, (int)__LINE__, (unsigned long long) uid);     \
    }
#endif

#ifndef _RPY_REVDB_PRINT
#  define _RPY_REVDB_PRINT(mode, _e)  /* nothing */
#endif
#ifndef _RPY_REVDB_PRUID
#  define _RPY_REVDB_PRUID()      /* nothing */
#endif


/* Acquire/release the lock around EMIT_RECORD, because it may be
   called without holding the GIL.  Note that we're always
   single-threaded during replaying: the lock is only useful during
   recording.  

   Implementation trick: use 'a >= b' to mean 'a || !b' (the two
   variables can only take the values 0 or 1).
*/
#define _RPY_REVDB_LOCK()                                               \
    {                                                                   \
        int _lock_contention = pypy_lock_test_and_set(&rpy_revdb.lock, 1); \
        if (_lock_contention >= rpy_active_thread)                      \
            rpy_reverse_db_lock_acquire(_lock_contention);              \
    }
#define _RPY_REVDB_UNLOCK()                                             \
    pypy_lock_release(&rpy_revdb.lock)


#define _RPY_REVDB_EMIT_RECORD_L(decl_e, variable)                      \
        {                                                               \
            decl_e = variable;                                          \
            _RPY_REVDB_PRINT("[ wr ]", _e);                             \
            char *_dst = rpy_revdb.buf_p;                               \
            if (_dst) {                                                 \
                memcpy(_dst, &_e, sizeof(_e));                          \
                if ((rpy_revdb.buf_p = _dst + sizeof(_e))               \
                        > rpy_revdb.buf_limit)                          \
                    rpy_reverse_db_flush();                             \
            }                                                           \
        }

#define _RPY_REVDB_EMIT_REPLAY(decl_e, variable)                        \
        {                                                               \
            decl_e;                                                     \
            char *_src = rpy_revdb.buf_p;                               \
            char *_end1 = _src + sizeof(_e);                            \
            memcpy(&_e, _src, sizeof(_e));                              \
            rpy_revdb.buf_p = _end1;                                    \
            _RPY_REVDB_PRINT("[ rd ]", _e);                             \
            if (_end1 >= rpy_revdb.buf_limit)                           \
                rpy_reverse_db_fetch(__FILE__, __LINE__);               \
            variable = _e;                                              \
        }

#define _RPY_REVDB_EMIT_L(normal_code, decl_e, variable)                \
    if (!RPY_RDB_REPLAY) {                                              \
        normal_code                                                     \
        _RPY_REVDB_EMIT_RECORD_L(decl_e, variable)                      \
    } else                                                              \
        _RPY_REVDB_EMIT_REPLAY(decl_e, variable)

#define RPY_REVDB_EMIT(normal_code, decl_e, variable)                   \
    if (!RPY_RDB_REPLAY) {                                              \
        normal_code                                                     \
        _RPY_REVDB_LOCK();                                              \
        _RPY_REVDB_EMIT_RECORD_L(decl_e, variable)                      \
        _RPY_REVDB_UNLOCK();                                            \
    } else                                                              \
        _RPY_REVDB_EMIT_REPLAY(decl_e, variable)

#define RPY_REVDB_EMIT_VOID(normal_code)                                \
    if (!RPY_RDB_REPLAY) { normal_code } else { }

#define RPY_REVDB_CALL(call_code, decl_e, variable)                     \
    if (!RPY_RDB_REPLAY) {                                              \
        call_code                                                       \
        _RPY_REVDB_LOCK();                                              \
        _RPY_REVDB_EMIT_RECORD_L(unsigned char _e, 0xFC)                \
        _RPY_REVDB_EMIT_RECORD_L(decl_e, variable)                      \
        _RPY_REVDB_UNLOCK();                                            \
    } else {                                                            \
        unsigned char _re;                                              \
        _RPY_REVDB_EMIT_REPLAY(unsigned char _e, _re)                   \
        if (_re != 0xFC)                                                \
            rpy_reverse_db_invoke_callback(_re);                        \
        _RPY_REVDB_EMIT_REPLAY(decl_e, variable)                        \
    }

#define RPY_REVDB_CALL_VOID(call_code)                                  \
    if (!RPY_RDB_REPLAY) {                                              \
        call_code                                                       \
        _RPY_REVDB_LOCK();                                              \
        _RPY_REVDB_EMIT_RECORD_L(unsigned char _e, 0xFC)                \
        _RPY_REVDB_UNLOCK();                                            \
    }                                                                   \
    else {                                                              \
        unsigned char _re;                                              \
        _RPY_REVDB_EMIT_REPLAY(unsigned char _e, _re)                   \
        if (_re != 0xFC)                                                \
            rpy_reverse_db_invoke_callback(_re);                        \
    }

#define RPY_REVDB_CALL_GIL_ACQUIRE()                                    \
    if (!RPY_RDB_REPLAY) {                                              \
        RPyGilAcquire();                                                \
        _RPY_REVDB_LOCK();                                              \
        _RPY_REVDB_EMIT_RECORD_L(unsigned char _e, 0xFD)                \
        _RPY_REVDB_UNLOCK();                                            \
    }                                                                   \
    else {                                                              \
        unsigned char _re;                                              \
        _RPY_REVDB_EMIT_REPLAY(unsigned char _e, _re)                   \
        if (_re != 0xFD)                                                \
            rpy_reverse_db_bad_acquire_gil("acquire");                  \
    }

#define RPY_REVDB_CALL_GIL_RELEASE()                                    \
    if (!RPY_RDB_REPLAY) {                                              \
        _RPY_REVDB_LOCK();                                              \
        _RPY_REVDB_EMIT_RECORD_L(unsigned char _e, 0xFE)                \
        _RPY_REVDB_UNLOCK();                                            \
        RPyGilRelease();                                                \
    }                                                                   \
    else {                                                              \
        unsigned char _re;                                              \
        _RPY_REVDB_EMIT_REPLAY(unsigned char _e, _re)                   \
        if (_re != 0xFE)                                                \
            rpy_reverse_db_bad_acquire_gil("release");                  \
    }

#define RPY_REVDB_C_ONLY_ENTER                                          \
    char *saved_bufp = rpy_revdb.buf_p;                                 \
    rpy_revdb.buf_p = NULL;

#define RPY_REVDB_C_ONLY_LEAVE                                          \
    rpy_revdb.buf_p = saved_bufp;

#define RPY_REVDB_CALLBACKLOC(locnum)                                   \
    rpy_reverse_db_callback_loc(locnum)

#define RPY_REVDB_REC_UID(expr)                                         \
    do {                                                                \
        uint64_t uid = rpy_revdb.unique_id_seen;                        \
        if (uid == rpy_revdb.unique_id_break || !expr)                  \
            uid = rpy_reverse_db_unique_id_break(expr);                 \
        rpy_revdb.unique_id_seen = uid + 1;                             \
        ((struct pypy_header0 *)expr)->h_uid = uid;                     \
        _RPY_REVDB_PRUID();                                             \
    } while (0)

#define OP_REVDB_STOP_POINT(place, r)                                   \
    if (++rpy_revdb.stop_point_seen == rpy_revdb.stop_point_break)      \
        rpy_reverse_db_stop_point(place)

#define OP_REVDB_SEND_ANSWER(cmd, arg1, arg2, arg3, ll_string, r)       \
    rpy_reverse_db_send_answer(cmd, arg1, arg2, arg3, ll_string)

#define OP_REVDB_BREAKPOINT(num, r)                                     \
    rpy_reverse_db_breakpoint(num)

#define OP_REVDB_GET_VALUE(value_id, r)                                 \
    r = rpy_reverse_db_get_value(value_id)

#define OP_REVDB_IDENTITYHASH(obj, r)                                   \
    r = rpy_reverse_db_identityhash((struct pypy_header0 *)(obj))

#define OP_REVDB_GET_UNIQUE_ID(x, r)                                    \
    r = ((struct pypy_header0 *)x)->h_uid

#define OP_REVDB_TRACK_OBJECT(uid, callback, r)                         \
    rpy_reverse_db_track_object(uid, callback)

#define OP_REVDB_WATCH_SAVE_STATE(force, r)   do {                      \
        r = rpy_revdb.watch_enabled;                                    \
        if ((force) || r) rpy_reverse_db_watch_save_state();            \
    } while (0)

#define OP_REVDB_WATCH_RESTORE_STATE(any_watch_point, r)                \
    rpy_reverse_db_watch_restore_state(any_watch_point)

#define OP_REVDB_WEAKREF_CREATE(target, r)                              \
    r = rpy_reverse_db_weakref_create(target)

#define OP_REVDB_WEAKREF_DEREF(weakref, r)                              \
    r = rpy_reverse_db_weakref_deref(weakref)

#define OP_REVDB_CALL_DESTRUCTOR(obj, r)                                \
    rpy_reverse_db_call_destructor(obj)

#define RPY_REVDB_CAST_PTR_TO_INT(obj)                                  \
    rpy_reverse_db_cast_ptr_to_int((struct pypy_header0 *)(obj))

#define OP_REVDB_SET_THREAD_BREAKPOINT(tnum, r)                         \
    rpy_reverse_db_set_thread_breakpoint(tnum)

#define OP_REVDB_STRTOD(s, r)                                           \
    r = rpy_reverse_db_strtod(s)

#define OP_REVDB_DTOA(d, r)                                             \
    r = rpy_reverse_db_dtoa(d)

#define OP_REVDB_MODF(x, index, r)                                      \
    do {                                                                \
        double _r0, _r1;                                                \
        _r0 = modf(x, &_r1);                                            \
        r = (index == 0) ? _r0 : _r1;                                   \
    } while (0)

#define OP_REVDB_FREXP(x, index, r)                                     \
    do {                                                                \
        double _r0; int _r1;                                            \
        _r0 = frexp(x, &_r1);                                           \
        r = (index == 0) ? _r0 : _r1;                                   \
    } while (0)


#define OP_GC_RAWREFCOUNT_CREATE_LINK_PYPY(gcobj, pyobj, r)   \
    rpy_reverse_db_rawrefcount_create_link_pypy(gcobj, pyobj)

#define OP_GC_RAWREFCOUNT_CREATE_LINK_PYOBJ(gcobj, pyobj, r)   \
    rpy_reverse_db_rawrefcount_create_link_pypy(gcobj, pyobj)

#define OP_GC_RAWREFCOUNT_FROM_OBJ(gcobj, r)   \
    r = rpy_reverse_db_rawrefcount_from_obj(gcobj)

#define OP_GC_RAWREFCOUNT_TO_OBJ(pyobj, r)   \
    r = rpy_reverse_db_rawrefcount_to_obj(pyobj)

#define OP_GC_RAWREFCOUNT_NEXT_DEAD(r)   \
    r = rpy_reverse_db_rawrefcount_next_dead()

#define OP_GC_INCREASE_ROOT_STACK_DEPTH(depth, r)   /* nothing */


RPY_EXTERN void rpy_reverse_db_flush(void);  /* must be called with the lock */
RPY_EXTERN void rpy_reverse_db_fetch(const char *file, int line);
RPY_EXTERN void rpy_reverse_db_stop_point(long place);
RPY_EXTERN void rpy_reverse_db_send_answer(int cmd, int64_t arg1, int64_t arg2,
                                           int64_t arg3, RPyString *extra);
RPY_EXTERN Signed rpy_reverse_db_identityhash(struct pypy_header0 *obj);
RPY_EXTERN Signed rpy_reverse_db_cast_ptr_to_int(struct pypy_header0 *obj);
RPY_EXTERN void rpy_reverse_db_breakpoint(int64_t num);
RPY_EXTERN long long rpy_reverse_db_get_value(char value_id);
RPY_EXTERN uint64_t rpy_reverse_db_unique_id_break(void *new_object);
RPY_EXTERN void rpy_reverse_db_watch_save_state(void);
RPY_EXTERN void rpy_reverse_db_watch_restore_state(bool_t any_watch_point);
RPY_EXTERN void *rpy_reverse_db_weakref_create(void *target);
RPY_EXTERN void *rpy_reverse_db_weakref_deref(void *weakref);
RPY_EXTERN int rpy_reverse_db_fq_register(void *obj);
RPY_EXTERN void *rpy_reverse_db_next_dead(void *result);
RPY_EXTERN void rpy_reverse_db_register_destructor(void *obj, void(*)(void *));
RPY_EXTERN void rpy_reverse_db_call_destructor(void *obj);
RPY_EXTERN void rpy_reverse_db_invoke_callback(unsigned char);
RPY_EXTERN void rpy_reverse_db_callback_loc(int);
RPY_EXTERN void rpy_reverse_db_lock_acquire(bool_t lock_contention);
RPY_EXTERN void rpy_reverse_db_bad_acquire_gil(const char *name);
RPY_EXTERN void rpy_reverse_db_set_thread_breakpoint(int64_t tnum);
RPY_EXTERN double rpy_reverse_db_strtod(RPyString *s);
RPY_EXTERN RPyString *rpy_reverse_db_dtoa(double d);
RPY_EXTERN void rpy_reverse_db_rawrefcount_create_link_pypy(void *gcobj, 
                                                            void *pyobj);
RPY_EXTERN void *rpy_reverse_db_rawrefcount_from_obj(void *gcobj);
RPY_EXTERN void *rpy_reverse_db_rawrefcount_to_obj(void *pyobj);
RPY_EXTERN void *rpy_reverse_db_rawrefcount_next_dead(void);

/* ------------------------------------------------------------ */
