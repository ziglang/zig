
/* Idea:

  0. "The GIL" is a composite concept.  There are two locks, and "the
     GIL is locked" when both are locked.

  1. The first lock is a simple global variable 'rpy_fastgil'.  0 means
     unlocked, != 0 means unlocked (see point (3).

  2. The second lock is a regular mutex called 'mutex_gil'.  In the fast path,
     it is never unlocked.  Remember that "the GIL is unlocked" means that
     either the first or the second lock is unlocked.  It should never be the
     case that both are unlocked at the same time.

  3. Whenever the GIL is locked, rpy_fastgil contains the thread ID of the
     thread holding the GIL. Note that there is a period of time in which
     rpy_fastgil contains a thread ID, but the GIL itself is not locked
     because the mutex in point (2) is unlocked: however, this happens only
     inside the functions RPyGilAcquireSlowPath and RPyGilYieldThread. So, for
     "general" code, you can easily check whether you are holding the GIL by
     doing: rpy_fastgil == rthread.get_ident()

With this setup, we have a very fast way to release/acquire the GIL:

  4. To release, you set rpy_fastgil=0; the invariant is that mutex_gil is
     still locked at this point.

  5. To acquire, you do a compare_and_swap on rpy_fastgil: if it was 0, then
     it means the mutex_gil was already locked, so you have the GIL and you
     are done. If rpy_fastgil was NOT 0, the compare_and_swap fails, so you
     must go through the slow path in RPyGilAcquireSlowPath

This fast path is implemented in two places:

  * RPyGilAcquire, to be called by general RPython code

  * By native code emitted by the JIT around external calls; look e.g. to
        rpython.jit.backend.x86.callbuilder:move_real_result_and_call_reacqgil_addr


The slow path works as follows:

  6. Suppose there are many threads which want the GIL: at any point in time,
     only one will actively try to acquire the GIL. This is called "the
     stealer".

  7. To become the stealer, you need to acquire 'mutex_gil_stealer'.

  8. Once you are the stealer, you try to acquire the GIL by running the
     following loop:

      A. We try again to lock the GIL using the fast-path.

      B. Try to acquire 'mutex_gil' with a timeout. If you succeed, you set
         rpy_fastgil and you are done.  If not, go to A.



To sum up, there are various possible patterns of interaction:

  - I release the GIL using the fast-path: the GIL will be acquired by a
    thread in the fast path in point (2) OR the fast path in point (8.A). Note
    that this could be myself a bit later

  - I want to explicitly yield the control to ANOTHER thread: I do this by
    releasing mutex_gil: the stealer will acquire the GIL in point (8.B).

  - I want the GIL and there are exactly 2 threads in total: I will
    immediately become the stealer and go to point 8

  - I want the GIL but there are more than 2 threads in total: I will spend
    most of my time waiting for mutex_gil_stealer, and then go to point 8


*/


/* The GIL is initially released; see pypy_main_function(), which calls
   RPyGilAcquire/RPyGilRelease.  The point is that when building
   RPython libraries, they can be a collection of regular functions that
   also call RPyGilAcquire/RPyGilRelease; see test_standalone.TestShared.
*/

#include "src/threadlocal.h"

Signed rpy_fastgil = 0;
static Signed rpy_waiting_threads = -42;    /* GIL not initialized */
static volatile int rpy_early_poll_n = 0;
static mutex1_t mutex_gil_stealer;
static mutex2_t mutex_gil;


static void rpy_init_mutexes(void)
{
    mutex1_init(&mutex_gil_stealer);
    mutex2_init_locked(&mutex_gil);
    rpy_waiting_threads = 0;
}

void RPyGilAllocate(void)
{
    if (rpy_waiting_threads < 0) {
        assert(rpy_waiting_threads == -42);
        rpy_init_mutexes();
#ifdef HAVE_PTHREAD_ATFORK
        pthread_atfork(NULL, NULL, rpy_init_mutexes);
#endif
    }
}

#define RPY_GIL_POKE_MIN   40
#define RPY_GIL_POKE_MAX  400

void RPyGilAcquireSlowPath(void)
{
    /* Acquires the GIL.  This is the slow path after which we failed
       the compare-and-swap (after point (5)).  Another thread is busy
       with the GIL.
     */
    if (1) {      /* preserve commit history */
        int n;
        Signed old_waiting_threads;

        if (rpy_waiting_threads < 0) {
            /* <arigo> I tried to have RPyGilAllocate() called from
             * here, but it fails occasionally on an example
             * (2.7/test/test_threading.py).  I think what occurs is
             * that if one thread runs RPyGilAllocate(), it still
             * doesn't have the GIL; then the other thread might fork()
             * at precisely this moment, killing the first thread.
             */
            fprintf(stderr, "Fatal RPython error: a thread is trying to wait "
                            "for the GIL, but the GIL was not initialized\n"
                            "(For PyPy, see "
                            "https://foss.heptapod.net/pypy/pypy/-/issues/2274)\n");
            abort();
        }

        /* Register me as one of the threads that is actively waiting
           for the GIL.  The number of such threads is found in
           rpy_waiting_threads. */
        old_waiting_threads = atomic_increment(&rpy_waiting_threads);

        /* Early polling: before entering the waiting queue, we check
           a certain number of times if the GIL becomes free.  The
           motivation for this is issue #2341.  Note that we do this
           polling even if there are already other threads in the
           queue, and one of thesee threads is the stealer.  This is
           because the stealer is likely sleeping right now.  There
           are use cases where the GIL will really be released very
           soon after RPyGilAcquireSlowPath() is called, so it's worth
           always doing this check.

           To avoid falling into bad cases, we "randomize" the number
           of iterations: we loop N times, where N is choosen between
           RPY_GIL_POKE_MIN and RPY_GIL_POKE_MAX.
        */
        n = rpy_early_poll_n * 2 + 1;
        while (n >= RPY_GIL_POKE_MAX)
            n -= (RPY_GIL_POKE_MAX - RPY_GIL_POKE_MIN);
        rpy_early_poll_n = n;
        while (n >= 0) {
            n--;
            if (old_waiting_threads != rpy_waiting_threads) {
                /* If the number changed, it is because another thread
                   entered or left this function.  In that case, stop
                   this loop: if another thread left it means the GIL
                   has been acquired by that thread; if another thread
                   entered there is no point in running the present
                   loop twice. */
                break;
            }
            RPy_YieldProcessor();
            RPy_CompilerMemoryBarrier();

            if (!RPY_FASTGIL_LOCKED(rpy_fastgil)) {
                if (_rpygil_acquire_fast_path()) {
                    /* We got the gil before entering the waiting
                       queue.  In case there are other threads waiting
                       for the GIL, wake up the stealer thread now and
                       go to the waiting queue anyway, for fairness.
                       This will fall through if there are no other
                       threads waiting.
                    */
                    assert(RPY_FASTGIL_LOCKED(rpy_fastgil));
                    mutex2_unlock(&mutex_gil);
                    break;
                }
            }
        }

        /* Now we are in point (3): mutex_gil might be released, but
           rpy_fastgil might still contain an arbitrary tid */

        /* Enter the waiting queue from the end.  Assuming a roughly
           first-in-first-out order, this will nicely give the threads
           a round-robin chance.
        */
        mutex1_lock(&mutex_gil_stealer);
        mutex2_loop_start(&mutex_gil);

        /* We are now the stealer thread.  Steals! */
        while (1) {
            /* Busy-looping here.  Try to look again if 'rpy_fastgil' is
               released.
            */
            if (!RPY_FASTGIL_LOCKED(rpy_fastgil)) {
                /* point (8.A) */
                if (_rpygil_acquire_fast_path()) {
                    /* we just acquired the GIL */
                    break;
                }
            }
            /* Sleep for one interval of time.  We may be woken up earlier
               if 'mutex_gil' is released.  Point (8.B)
            */
            if (mutex2_lock_timeout(&mutex_gil, 0.0001)) {   /* 0.1 ms... */
                /* We arrive here if 'mutex_gil' was recently released
                   and we just relocked it.
                 */
                assert(RPY_FASTGIL_LOCKED(rpy_fastgil));
                /* restore the invariant point (3) */
                rpy_fastgil = _rpygil_get_my_ident();
                break;
            }
            /* Loop back. */
        }
        atomic_decrement(&rpy_waiting_threads);
        mutex2_loop_stop(&mutex_gil);
        mutex1_unlock(&mutex_gil_stealer);
    }
    assert(RPY_FASTGIL_LOCKED(rpy_fastgil));
}

Signed RPyGilYieldThread(void)
{
    /* can be called even before RPyGilAllocate(), but in this case,
       'rpy_waiting_threads' will be -42. */
    assert(RPY_FASTGIL_LOCKED(rpy_fastgil));
    if (rpy_waiting_threads <= 0)
        return 0;

    /* Explicitly release the 'mutex_gil'.
     */
    mutex2_unlock(&mutex_gil);

    /* Now nobody has got the GIL, because 'mutex_gil' is released (but
       rpy_fastgil is still locked).  Call RPyGilAcquire().  It will
       enqueue ourselves at the end of the 'mutex_gil_stealer' queue.
       If there is no other waiting thread, it will fall through both
       its mutex_lock() and mutex_lock_timeout() now.  But that's
       unlikely, because we tested above that 'rpy_waiting_threads > 0'.
     */
    RPyGilAcquire();
    return 1;
}

/********** for tests only **********/

/* These functions are usually defined as a macros RPyXyz() in thread.h
   which get translated into calls to _RpyXyz().  But for tests we need
   the real functions to exists in the library as well.
*/

#undef RPyGilRelease
RPY_EXTERN
void RPyGilRelease(void)
{
    /* Releases the GIL in order to do an external function call.
       We assume that the common case is that the function call is
       actually very short, and optimize accordingly.
    */
    _RPyGilRelease();
}

#undef RPyGilAcquire
RPY_EXTERN
void RPyGilAcquire(void)
{
    _RPyGilAcquire();
}

#undef RPyFetchFastGil
RPY_EXTERN
Signed *RPyFetchFastGil(void)
{
    return _RPyFetchFastGil();
}

#undef RPyGilGetHolder
RPY_EXTERN
Signed RPyGilGetHolder(void)
{
    return _RPyGilGetHolder();
}
