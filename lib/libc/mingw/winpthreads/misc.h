/*
   Copyright (c) 2011-2016  mingw-w64 project

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the "Software"),
   to deal in the Software without restriction, including without limitation
   the rights to use, copy, modify, merge, publish, distribute, sublicense,
   and/or sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.
*/

#ifndef WIN_PTHREADS_MISC_H
#define WIN_PTHREADS_MISC_H

#include "pthread_compat.h"

#ifndef assert

#ifndef ASSERT_TRACE
# define ASSERT_TRACE 0
#else
# undef ASSERT_TRACE
# define ASSERT_TRACE 0
#endif

# define assert(e) \
   ((e) ? ((ASSERT_TRACE) ? fprintf(stderr, \
                                    "Assertion succeeded: (%s), file %s, line %d\n", \
                        #e, __FILE__, (int) __LINE__), \
                                fflush(stderr) : \
                             0) : \
          (fprintf(stderr, "Assertion failed: (%s), file %s, line %d\n", \
                   #e, __FILE__, (int) __LINE__), exit(1), 0))

# define fixme(e) \
   ((e) ? ((ASSERT_TRACE) ? fprintf(stderr, \
                                    "Assertion succeeded: (%s), file %s, line %d\n", \
                        #e, __FILE__, (int) __LINE__), \
                                fflush(stderr) : \
                             0) : \
          (fprintf(stderr, "FIXME: (%s), file %s, line %d\n", \
                   #e, __FILE__, (int) __LINE__), 0, 0))

#endif

#define PTR2INT(x)	((int)(uintptr_t)(x))

#if SIZE_MAX>UINT_MAX
typedef long long LONGBAG;
#else
typedef long LONGBAG;
#endif

#if !WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
#undef GetHandleInformation
#define GetHandleInformation(h,f)  (1)
#endif

#define CHECK_HANDLE(h)                                                 \
  do {                                                                  \
    DWORD dwFlags;                                                      \
    if (!(h) || ((h) == INVALID_HANDLE_VALUE) || !GetHandleInformation((h), &dwFlags)) \
      return EINVAL;                                                    \
  } while (0)

#define CHECK_PTR(p) do { if (!(p)) return EINVAL; } while (0)

#define UPD_RESULT(x,r) do { int _r = (x); (r) = (r) ? (r) : _r; } while (0)

#define CHECK_THREAD(t)                         \
  do {                                          \
    CHECK_PTR(t);                               \
    CHECK_HANDLE((t)->h);                       \
  } while (0)

#define CHECK_OBJECT(o, e)                                              \
  do {                                                                  \
    DWORD dwFlags;                                                      \
    if (!(o)) return e;                                                 \
    if (!((o)->h) || (((o)->h) == INVALID_HANDLE_VALUE) || !GetHandleInformation(((o)->h), &dwFlags)) \
      return e;                                                         \
  } while (0)

#define VALID(x)    if (!(p)) return EINVAL;

/* ms can be 64 bit, solve wrap-around issues: */
static WINPTHREADS_INLINE unsigned long dwMilliSecs(unsigned long long ms)
{
  if (ms >= 0xffffffffULL) return 0xfffffffful;
  return (unsigned long) ms;
}

unsigned long long _pthread_time_in_ms(void);
unsigned long long _pthread_time_in_ms_from_timespec(const struct timespec *ts);
unsigned long long _pthread_rel_time_in_ms(const struct timespec *ts);
unsigned long _pthread_wait_for_single_object (void *handle, unsigned long timeout);
unsigned long _pthread_wait_for_multiple_objects (unsigned long count, void **handles, unsigned int all, unsigned long timeout);

extern void (WINAPI *_pthread_get_system_time_best_as_file_time) (LPFILETIME);
extern HRESULT (WINAPI *_pthread_set_thread_description) (HANDLE, PCWSTR);

#if defined(__GNUC__) || defined(__clang__)
#define likely(cond) __builtin_expect((cond) != 0, 1)
#define unlikely(cond) __builtin_expect((cond) != 0, 0)
#else
#define likely(cond) (cond)
#define unlikely(cond) (cond)
#endif

#if defined(__GNUC__) || defined(__clang__)
#define UNREACHABLE() __builtin_unreachable()
#elif defined(_MSC_VER)
#define UNREACHABLE() __assume(0)
#endif

#endif
