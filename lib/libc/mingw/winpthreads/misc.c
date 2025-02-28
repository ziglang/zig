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

#include <windows.h>
#include "pthread.h"
#include "misc.h"

void (WINAPI *_pthread_get_system_time_best_as_file_time) (LPFILETIME) = NULL;
static ULONGLONG (WINAPI *_pthread_get_tick_count_64) (VOID);
HRESULT (WINAPI *_pthread_set_thread_description) (HANDLE, PCWSTR) = NULL;

#if defined(__GNUC__) || defined(__clang__)
__attribute__((constructor(0)))
#endif
static void winpthreads_init(void)
{
    HMODULE mod = GetModuleHandleA("kernel32.dll");
    if (mod)
    {
        _pthread_get_tick_count_64 =
            (ULONGLONG (WINAPI *)(VOID))(void*) GetProcAddress(mod, "GetTickCount64");

        /* <1us precision on Windows 10 */
        _pthread_get_system_time_best_as_file_time =
            (void (WINAPI *)(LPFILETIME))(void*) GetProcAddress(mod, "GetSystemTimePreciseAsFileTime");
    }

    if (!_pthread_get_system_time_best_as_file_time)
        /* >15ms precision on Windows 10 */
        _pthread_get_system_time_best_as_file_time = GetSystemTimeAsFileTime;

    mod = GetModuleHandleA("kernelbase.dll");
    if (mod)
    {
        _pthread_set_thread_description =
            (HRESULT (WINAPI *)(HANDLE, PCWSTR))(void*) GetProcAddress(mod, "SetThreadDescription");
    }
}

#if defined(_MSC_VER) && !defined(__clang__)
/* Force a reference to __xc_t to prevent whole program optimization
 * from discarding the variable. */

/* On x86, symbols are prefixed with an underscore. */
# if defined(_M_IX86)
#   pragma comment(linker, "/include:___xc_t")
# else
#   pragma comment(linker, "/include:__xc_t")
# endif

#pragma section(".CRT$XCT", long, read)
__declspec(allocate(".CRT$XCT"))
extern const _PVFV __xc_t;
const _PVFV __xc_t = winpthreads_init;
#endif

unsigned long long _pthread_time_in_ms(void)
{
    FILETIME ft;

    GetSystemTimeAsFileTime(&ft);
    return (((unsigned long long)ft.dwHighDateTime << 32) + ft.dwLowDateTime
            - 0x19DB1DED53E8000ULL) / 10000ULL;
}

unsigned long long _pthread_time_in_ms_from_timespec(const struct timespec *ts)
{
    unsigned long long t = (unsigned long long) ts->tv_sec * 1000LL;
    /* The +999999 is here to ensure that the division always rounds up */
    t += (unsigned long long) (ts->tv_nsec + 999999) / 1000000;

    return t;
}

unsigned long long _pthread_rel_time_in_ms(const struct timespec *ts)
{
    unsigned long long t1 = _pthread_time_in_ms_from_timespec(ts);
    unsigned long long t2 = _pthread_time_in_ms();

    /* Prevent underflow */
    if (t1 < t2) return 0;
    return t1 - t2;
}

static unsigned long long
_pthread_get_tick_count (long long *frequency)
{
  if (_pthread_get_tick_count_64 != NULL)
    return _pthread_get_tick_count_64 ();

  LARGE_INTEGER freq, timestamp;

  if (*frequency == 0)
  {
    if (QueryPerformanceFrequency (&freq))
      *frequency = freq.QuadPart;
    else
      *frequency = -1;
  }

  if (*frequency > 0 && QueryPerformanceCounter (&timestamp))
    return timestamp.QuadPart / (*frequency / 1000);

  /* Fallback */
  return GetTickCount ();
}

/* A wrapper around WaitForSingleObject() that ensures that
 * the wait function does not time out before the time
 * actually runs out. This is needed because WaitForSingleObject()
 * might have poor accuracy, returning earlier than expected.
 * On the other hand, returning a bit *later* than expected
 * is acceptable in a preemptive multitasking environment.
 */
unsigned long
_pthread_wait_for_single_object (void *handle, unsigned long timeout)
{
  DWORD result;
  unsigned long long start_time, end_time;
  unsigned long wait_time;
  long long frequency = 0;

  if (timeout == INFINITE || timeout == 0)
    return WaitForSingleObject ((HANDLE) handle, (DWORD) timeout);

  start_time = _pthread_get_tick_count (&frequency);
  end_time = start_time + timeout;
  wait_time = timeout;

  do
  {
    unsigned long long current_time;

    result = WaitForSingleObject ((HANDLE) handle, (DWORD) wait_time);
    if (result != WAIT_TIMEOUT)
      break;

    current_time = _pthread_get_tick_count (&frequency);
    if (current_time >= end_time)
      break;

    wait_time = (DWORD) (end_time - current_time);
  } while (TRUE);

  return result;
}

/* A wrapper around WaitForMultipleObjects() that ensures that
 * the wait function does not time out before the time
 * actually runs out. This is needed because WaitForMultipleObjects()
 * might have poor accuracy, returning earlier than expected.
 * On the other hand, returning a bit *later* than expected
 * is acceptable in a preemptive multitasking environment.
 */
unsigned long
_pthread_wait_for_multiple_objects (unsigned long count, void **handles, unsigned int all, unsigned long timeout)
{
  DWORD result;
  unsigned long long start_time, end_time;
  unsigned long wait_time;
  long long frequency = 0;

  if (timeout == INFINITE || timeout == 0)
    return WaitForMultipleObjects ((DWORD) count, (HANDLE *) handles, all, (DWORD) timeout);

  start_time = _pthread_get_tick_count (&frequency);
  end_time = start_time + timeout;
  wait_time = timeout;

  do
  {
    unsigned long long current_time;

    result = WaitForMultipleObjects ((DWORD) count, (HANDLE *) handles, all, (DWORD) wait_time);
    if (result != WAIT_TIMEOUT)
      break;

    current_time = _pthread_get_tick_count (&frequency);
    if (current_time >= end_time)
      break;

    wait_time = (DWORD) (end_time - current_time);
  } while (TRUE);

  return result;
}
