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
#include <strsafe.h>
#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <signal.h>
#include "pthread.h"
#include "thread.h"
#include "misc.h"
#include "winpthread_internal.h"

static _pthread_v *__pthread_self_lite (void);

void (**_pthread_key_dest)(void *) = NULL;

static volatile long _pthread_cancelling;
static int _pthread_concur;

/* FIXME Will default to zero as needed */
static pthread_once_t _pthread_tls_once;
static DWORD _pthread_tls = 0xffffffff;

static pthread_rwlock_t _pthread_key_lock = PTHREAD_RWLOCK_INITIALIZER;
static unsigned long _pthread_key_max=0L;
static unsigned long _pthread_key_sch=0L;

static _pthread_v *pthr_root = NULL, *pthr_last = NULL;
static pthread_mutex_t mtx_pthr_locked = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;

static __pthread_idlist *idList = NULL;
static size_t idListCnt = 0;
static size_t idListMax = 0;
static pthread_t idListNextId = 0;

#if !defined(_MSC_VER)
#define USE_VEH_FOR_MSC_SETTHREADNAME
#endif
#if !WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
/* forbidden RemoveVectoredExceptionHandler/AddVectoredExceptionHandler APIs */
#undef USE_VEH_FOR_MSC_SETTHREADNAME
#endif

#if defined(USE_VEH_FOR_MSC_SETTHREADNAME)
static void *SetThreadName_VEH_handle = NULL;

static LONG __stdcall
SetThreadName_VEH (PEXCEPTION_POINTERS ExceptionInfo)
{
  if (ExceptionInfo->ExceptionRecord != NULL &&
      ExceptionInfo->ExceptionRecord->ExceptionCode == EXCEPTION_SET_THREAD_NAME)
    return EXCEPTION_CONTINUE_EXECUTION;

  return EXCEPTION_CONTINUE_SEARCH;
}

static PVOID (WINAPI *AddVectoredExceptionHandlerFuncPtr) (ULONG, PVECTORED_EXCEPTION_HANDLER);
static ULONG (WINAPI *RemoveVectoredExceptionHandlerFuncPtr) (PVOID);

static void __attribute__((constructor))
ctor (void)
{
  HMODULE module = GetModuleHandleA("kernel32.dll");
  if (module) {
    AddVectoredExceptionHandlerFuncPtr = (__typeof__(AddVectoredExceptionHandlerFuncPtr)) GetProcAddress(module, "AddVectoredExceptionHandler");
    RemoveVectoredExceptionHandlerFuncPtr = (__typeof__(RemoveVectoredExceptionHandlerFuncPtr)) GetProcAddress(module, "RemoveVectoredExceptionHandler");
  }
}
#endif

typedef struct _THREADNAME_INFO
{
  DWORD  dwType;	/* must be 0x1000 */
  LPCSTR szName;	/* pointer to name (in user addr space) */
  DWORD  dwThreadID;	/* thread ID (-1=caller thread) */
  DWORD  dwFlags;	/* reserved for future use, must be zero */
} THREADNAME_INFO;

static void
SetThreadName (DWORD dwThreadID, LPCSTR szThreadName)
{
   THREADNAME_INFO info;
   DWORD infosize;

   info.dwType = 0x1000;
   info.szName = szThreadName;
   info.dwThreadID = dwThreadID;
   info.dwFlags = 0;

   infosize = sizeof (info) / sizeof (ULONG_PTR);

#if defined(_MSC_VER) && !defined (USE_VEH_FOR_MSC_SETTHREADNAME)
   __try
     {
       RaiseException (EXCEPTION_SET_THREAD_NAME, 0, infosize, (ULONG_PTR *)&info);
     }
   __except (EXCEPTION_EXECUTE_HANDLER)
     {
     }
#else
   /* Without a debugger we *must* have an exception handler,
    * otherwise raising an exception will crash the process.
    */
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
   if ((!IsDebuggerPresent ()) && (SetThreadName_VEH_handle == NULL))
#else
   if (!IsDebuggerPresent ())
#endif
     return;

   RaiseException (EXCEPTION_SET_THREAD_NAME, 0, infosize, (ULONG_PTR *) &info);
#endif
}

/* Search the list idList for an element with identifier ID.  If
   found, its associated _pthread_v pointer is returned, otherwise
   NULL.
   NOTE: This method is not locked.  */
static struct _pthread_v *
__pthread_get_pointer (pthread_t id)
{
  size_t l, r, p;
  if (!idListCnt)
    return NULL;
  if (idListCnt == 1)
    return (idList[0].id == id ? idList[0].ptr : NULL);
  l = 0; r = idListCnt - 1;
  while (l <= r)
  {
    p = (l + r) >> 1;
    if (idList[p].id == id)
      return idList[p].ptr;
    else if (idList[p].id > id)
      {
	if (p == l)
	  return NULL;
	r = p - 1;
      }
    else
      {
	l = p + 1;
      }
  }

  return NULL;
}

static void
__pth_remove_use_for_key (pthread_key_t key)
{
  int i;

  pthread_mutex_lock (&mtx_pthr_locked);
  for (i = 0; i < idListCnt; i++)
    {
      if (idList[i].ptr != NULL
          && idList[i].ptr->keyval != NULL
          && key < idList[i].ptr->keymax)
        {
	  idList[i].ptr->keyval[key] = NULL;
	  idList[i].ptr->keyval_set[key] = 0;
	}
    }
  pthread_mutex_unlock (&mtx_pthr_locked);
}

/* Search the list idList for an element with identifier ID.  If
   found, its associated _pthread_v pointer is returned, otherwise
   NULL.
   NOTE: This method uses lock mtx_pthr_locked.  */
struct _pthread_v *
__pth_gpointer_locked (pthread_t id)
{
  struct _pthread_v *ret;
  if (!id)
    return NULL;
  pthread_mutex_lock (&mtx_pthr_locked);
  ret =  __pthread_get_pointer (id);
  pthread_mutex_unlock (&mtx_pthr_locked);
  return ret;
}

/* Registers in the list idList an element with _pthread_v pointer
   and creates and unique identifier ID.  If successful created the
   ID of this element is returned, otherwise on failure zero ID gets
   returned.
   NOTE: This method is not locked.  */
static pthread_t
__pthread_register_pointer (struct _pthread_v *ptr)
{
  __pthread_idlist *e;
  size_t i;

  if (!ptr)
    return 0;
  /* Check if a resize of list is necessary.  */
  if (idListCnt >= idListMax)
    {
      if (!idListCnt)
        {
	  e = (__pthread_idlist *) malloc (sizeof (__pthread_idlist) * 16);
	  if (!e)
	    return 0;
	  idListMax = 16;
	  idList = e;
	}
      else
        {
	  e = (__pthread_idlist *) realloc (idList, sizeof (__pthread_idlist) * (idListMax + 16));
	  if (!e)
	    return 0;
	  idListMax += 16;
	  idList = e;
	}
    }
  do
    {
      ++idListNextId;
      /* If two MSB are set we reset to id 1.  We need to check here bits
         to avoid gcc's no-overflow issue on increment.  Additionally we
         need to handle different size of pthread_t on 32-bit/64-bit.  */
      if ((idListNextId & ( ((pthread_t) 1) << ((sizeof (pthread_t) * 8) - 2))) != 0)
        idListNextId = 1;
    }
  while (idListNextId == 0 || __pthread_get_pointer (idListNextId));
  /* We assume insert at end of list.  */
  i = idListCnt;
  if (i != 0)
    {
      /* Find position we can actual insert sorted.  */
      while (i > 0 && idList[i - 1].id > idListNextId)
        --i;
      if (i != idListCnt)
	memmove (&idList[i + 1], &idList[i], sizeof (__pthread_idlist) * (idListCnt - i));
    }
  idList[i].id = idListNextId;
  idList[i].ptr = ptr;
  ++idListCnt;
  return idListNextId;
}

/* Deregisters in the list idList an element with identifier ID and
   returns its _pthread_v pointer on success.  Otherwise NULL is returned.
   NOTE: This method is not locked.  */
static struct _pthread_v *
__pthread_deregister_pointer (pthread_t id)
{
  size_t l, r, p;
  if (!idListCnt)
    return NULL;
  l = 0; r = idListCnt - 1;
  while (l <= r)
  {
    p = (l + r) >> 1;
    if (idList[p].id == id)
      {
	struct _pthread_v *ret = idList[p].ptr;
	p++;
	if (p < idListCnt)
	  memmove (&idList[p - 1], &idList[p], sizeof (__pthread_idlist) * (idListCnt - p));
	--idListCnt;
	/* Is this last element in list then free list.  */
	if (idListCnt == 0)
	{
	  free (idList);
	  idListCnt = idListMax = 0;
	}
	return ret;
      }
    else if (idList[p].id > id)
      {
	if (p == l)
	  return NULL;
	r = p - 1;
      }
    else
      {
	l = p + 1;
      }
  }
  return NULL;
}

/* Save a _pthread_v element for reuse in pool.  */
static void
push_pthread_mem (_pthread_v *sv)
{
  if (!sv || sv->next != NULL)
    return;
  pthread_mutex_lock (&mtx_pthr_locked);
  if (sv->x != 0)
    __pthread_deregister_pointer (sv->x);
  if (sv->keyval)
    free (sv->keyval);
  if (sv->keyval_set)
    free (sv->keyval_set);
  if (sv->thread_name)
    free (sv->thread_name);
  memset (sv, 0, sizeof(struct _pthread_v));
  if (pthr_last == NULL)
    pthr_root = pthr_last = sv;
  else
  {
    pthr_last->next = sv;
    pthr_last = sv;
  }
  pthread_mutex_unlock (&mtx_pthr_locked);
}

/* Get a _pthread_v element from pool, or allocate it.
   Note the unique identifier is created for the element here, too.  */
static _pthread_v *
pop_pthread_mem (void)
{
  _pthread_v *r = NULL;

  pthread_mutex_lock (&mtx_pthr_locked);
  if ((r = pthr_root) == NULL)
    {
      if ((r = (_pthread_v *)calloc (1,sizeof(struct _pthread_v))) != NULL)
	{
	  r->x = __pthread_register_pointer (r);
	  if (r->x == 0)
	    {
	      free (r);
	      r = NULL;
	    }
	}
      pthread_mutex_unlock (&mtx_pthr_locked);
      return r;
    }
  r->x = __pthread_register_pointer (r);
  if (r->x == 0)
    r = NULL;
  else
    {
      if((pthr_root = r->next) == NULL)
	pthr_last = NULL;

      r->next = NULL;
    }
  pthread_mutex_unlock (&mtx_pthr_locked);
  return r;
}

/* Free memory consumed in _pthread_v pointer pool.  */
static void
free_pthread_mem (void)
{
#if 0
  _pthread_v *t;

  pthread_mutex_lock (&mtx_pthr_locked);
  t = pthr_root;
  while (t != NULL)
  {
    _pthread_v *sv = t;
    t = t->next;
    if (sv->x != 0 && sv->ended == 0 && sv->valid != DEAD_THREAD)
      {
	pthread_mutex_unlock (&mtx_pthr_locked);
	pthread_cancel (t->x);
	Sleep (0);
	pthread_mutex_lock (&mtx_pthr_locked);
	t = pthr_root;
	continue;
      }
    else if (sv->x != 0 && sv->valid != DEAD_THREAD)
      {
	pthread_mutex_unlock (&mtx_pthr_locked);
	Sleep (0);
	pthread_mutex_lock (&mtx_pthr_locked);
	continue;
      }
    if (sv->x != 0)
      __pthread_deregister_pointer (sv->x);
    sv->x = 0;
    free (sv);
    pthr_root = t;
  }
  pthread_mutex_unlock (&mtx_pthr_locked);
#endif
  return;
}

static void
replace_spin_keys (pthread_spinlock_t *old, pthread_spinlock_t new)
{
  if (old == NULL)
    return;

  if (EPERM == pthread_spin_destroy (old))
    {
#define THREADERR "Error cleaning up spin_keys for thread %lu.\n"
      char threaderr[sizeof(THREADERR) + 8] = { 0 };
      snprintf(threaderr, sizeof(threaderr), THREADERR, GetCurrentThreadId());
#undef THREADERR
      OutputDebugStringA (threaderr);
      abort ();
    }

  *old = new;
}

/* Hook for TLS-based deregistration/registration of thread.  */
static void WINAPI
__dyn_tls_pthread (HANDLE hDllHandle, DWORD dwReason, LPVOID lpreserved)
{
  _pthread_v *t = NULL;
  pthread_spinlock_t new_spin_keys = PTHREAD_SPINLOCK_INITIALIZER;

  if (dwReason == DLL_PROCESS_DETACH)
    {
#if defined(USE_VEH_FOR_MSC_SETTHREADNAME)
      if (lpreserved == NULL && SetThreadName_VEH_handle != NULL)
        {
          if (RemoveVectoredExceptionHandlerFuncPtr != NULL)
            RemoveVectoredExceptionHandlerFuncPtr (SetThreadName_VEH_handle);
          SetThreadName_VEH_handle = NULL;
        }
#endif
      free_pthread_mem ();
    }
  else if (dwReason == DLL_PROCESS_ATTACH)
    {
#if defined(USE_VEH_FOR_MSC_SETTHREADNAME)
      if (AddVectoredExceptionHandlerFuncPtr != NULL)
        SetThreadName_VEH_handle = AddVectoredExceptionHandlerFuncPtr (1, &SetThreadName_VEH);
      else
        SetThreadName_VEH_handle = NULL;
      /* Can't do anything on error anyway, check for NULL later */
#endif
    }
  else if (dwReason == DLL_THREAD_DETACH)
    {
      if (_pthread_tls != 0xffffffff)
	t = (_pthread_v *)TlsGetValue(_pthread_tls);
      if (t && t->thread_noposix != 0)
	{
	  _pthread_cleanup_dest (t->x);
	  if (t->h != NULL)
	    {
	      CloseHandle (t->h);
	      if (t->evStart)
		CloseHandle (t->evStart);
	      t->evStart = NULL;
	      t->h = NULL;
	    }
	  pthread_mutex_destroy (&t->p_clock);
	  replace_spin_keys (&t->spin_keys, new_spin_keys);
	  push_pthread_mem (t);
	  t = NULL;
	  TlsSetValue (_pthread_tls, t);
	}
      else if (t && t->ended == 0)
	{
	  if (t->evStart)
	    CloseHandle(t->evStart);
	  t->evStart = NULL;
	  t->ended = 1;
	  _pthread_cleanup_dest (t->x);
	  if ((t->p_state & PTHREAD_CREATE_DETACHED) == PTHREAD_CREATE_DETACHED)
	    {
	      t->valid = DEAD_THREAD;
	      if (t->h != NULL)
		CloseHandle (t->h);
	      t->h = NULL;
	      pthread_mutex_destroy(&t->p_clock);
	      replace_spin_keys (&t->spin_keys, new_spin_keys);
	      push_pthread_mem (t);
	      t = NULL;
	      TlsSetValue (_pthread_tls, t);
	      return;
	    }
	  pthread_mutex_destroy(&t->p_clock);
	  replace_spin_keys (&t->spin_keys, new_spin_keys);
	}
      else if (t)
	{
	  if (t->evStart)
	    CloseHandle (t->evStart);
	  t->evStart = NULL;
	  pthread_mutex_destroy (&t->p_clock);
	  replace_spin_keys (&t->spin_keys, new_spin_keys);
	}
    }
}

/* TLS-runtime section variable.  */

#if defined(_MSC_VER)
/* Force a reference to _tls_used to make the linker create the TLS
 * directory if it's not already there.  (e.g. if __declspec(thread)
 * is not used).
 * Force a reference to __xl_f to prevent whole program optimization
 * from discarding the variable. */

/* On x86, symbols are prefixed with an underscore. */
# if defined(_M_IX86)
#   pragma comment(linker, "/include:__tls_used")
#   pragma comment(linker, "/include:___xl_f")
# else
#   pragma comment(linker, "/include:_tls_used")
#   pragma comment(linker, "/include:__xl_f")
# endif

/* .CRT$XLA to .CRT$XLZ is an array of PIMAGE_TLS_CALLBACK
 * pointers. Pick an arbitrary location for our callback.
 *
 * See VC\...\crt\src\vcruntime\tlssup.cpp for reference. */

# pragma section(".CRT$XLF", long, read)
#endif

WINPTHREADS_ATTRIBUTE((WINPTHREADS_SECTION(".CRT$XLF")))
extern const PIMAGE_TLS_CALLBACK __xl_f;
const PIMAGE_TLS_CALLBACK __xl_f = __dyn_tls_pthread;


#ifdef WINPTHREAD_DBG
static int print_state = 0;
void thread_print_set (int state)
{
  print_state = state;
}

void
thread_print (volatile pthread_t t, char *txt)
{
    if (!print_state)
      return;
    if (!t)
      printf("T%p %lu %s\n",NULL,GetCurrentThreadId(),txt);
    else
      {
	printf("T%p %lu V=%0X H=%p %s\n",
	    (void *) __pth_gpointer_locked (t),
	    GetCurrentThreadId(),
	    (__pth_gpointer_locked (t))->valid,
	    (__pth_gpointer_locked (t))->h,
	    txt
	    );
      }
}
#endif

/* Internal collect-once structure.  */
typedef struct collect_once_t {
  pthread_once_t *o;
  pthread_mutex_t m;
  int count;
  struct collect_once_t *next;
} collect_once_t;

static collect_once_t *once_obj = NULL;

static pthread_spinlock_t once_global = PTHREAD_SPINLOCK_INITIALIZER;

static collect_once_t *
enterOnceObject (pthread_once_t *o)
{
  collect_once_t *c, *p = NULL;
  pthread_spin_lock (&once_global);
  c = once_obj;
  while (c != NULL && c->o != o)
    {
      c = (p = c)->next;
    }
  if (!c)
    {
      c = (collect_once_t *) calloc(1,sizeof(collect_once_t));
      c->o = o;
      c->count = 1;
      if (!p)
        once_obj = c;
      else
        p->next = c;
      pthread_mutex_init(&c->m, NULL);
    }
  else
    c->count += 1;
  pthread_spin_unlock (&once_global);
  return c;
}

static void
leaveOnceObject (collect_once_t *c)
{
  collect_once_t *h, *p = NULL;
  if (!c)
    return;
  pthread_spin_lock (&once_global);
  h = once_obj;
  while (h != NULL && c != h)
    h = (p = h)->next;

  if (h)
    {
      c->count -= 1;
      if (c->count == 0)
	{
	  pthread_mutex_destroy(&c->m);
	  if (!p)
	    once_obj = c->next;
	  else
	    p->next = c->next;
	  free (c);
	}
    }
  else
    fprintf(stderr, "%p not found?!?!\n", (void *) c);
  pthread_spin_unlock (&once_global);
}

static void
_pthread_once_cleanup (void *o)
{
  collect_once_t *co = (collect_once_t *) o;
  pthread_mutex_unlock (&co->m);
  leaveOnceObject (co);
}

static int
_pthread_once_raw (pthread_once_t *o, void (*func)(void))
{
  collect_once_t *co;
  long state = *o;

  CHECK_PTR(o);
  CHECK_PTR(func);

  if (state == 1)
    return 0;
  co = enterOnceObject(o);
  pthread_mutex_lock(&co->m);
  if (*o == 0)
    {
      func();
      *o = 1;
    }
  else if (*o != 1)
    fprintf (stderr," once %p is %ld\n", (void *) o, (long) *o);
  pthread_mutex_unlock(&co->m);
  leaveOnceObject(co);

  /* Done */
  return 0;
}

/* Unimplemented.  */
void *
pthread_timechange_handler_np(void *dummy)
{
  return NULL;
}

/* Compatibility routine for pthread-win32.  It waits for ellapse of
   interval and additionally checks for possible thread-cancelation.  */
int
pthread_delay_np (const struct timespec *interval)
{
  DWORD to = (!interval ? 0 : dwMilliSecs (_pthread_time_in_ms_from_timespec (interval)));
  struct _pthread_v *s = __pthread_self_lite ();

  if (!to)
    {
      pthread_testcancel ();
      Sleep (0);
      pthread_testcancel ();
      return 0;
    }
  pthread_testcancel ();
  if (s->evStart)
    _pthread_wait_for_single_object (s->evStart, to);
  else
    Sleep (to);
  pthread_testcancel ();
  return 0;
}

int pthread_delay_np_ms (DWORD to);

int
pthread_delay_np_ms (DWORD to)
{
  struct _pthread_v *s = __pthread_self_lite ();

  if (!to)
    {
      pthread_testcancel ();
      Sleep (0);
      pthread_testcancel ();
      return 0;
    }
  pthread_testcancel ();
  if (s->evStart)
    _pthread_wait_for_single_object (s->evStart, to);
  else
    Sleep (to);
  pthread_testcancel ();
  return 0;
}

/* Compatibility routine for pthread-win32.  It returns the
   amount of available CPUs on system.  */
int
pthread_num_processors_np(void) 
{
  int r = 0;
  DWORD_PTR ProcessAffinityMask, SystemAffinityMask;

  if (GetProcessAffinityMask(GetCurrentProcess(), &ProcessAffinityMask, &SystemAffinityMask))
    {
      for(; ProcessAffinityMask != 0; ProcessAffinityMask >>= 1)
	r += (ProcessAffinityMask & 1) != 0;
    }
  /* assume at least 1 */
  return r ? r : 1;
}

/* Compatiblity routine for pthread-win32.  Allows to set amount of used
   CPUs for process.  */
int
pthread_set_num_processors_np(int n) 
{
  DWORD_PTR ProcessAffinityMask, ProcessNewAffinityMask = 0, SystemAffinityMask;
  int r = 0; 
  /* need at least 1 */
  n = n ? n : 1;
  if (GetProcessAffinityMask (GetCurrentProcess (), &ProcessAffinityMask, &SystemAffinityMask))
    {
      for (; ProcessAffinityMask != 0; ProcessAffinityMask >>= 1)
	{
	  ProcessNewAffinityMask <<= 1;
	  if ((ProcessAffinityMask & 1) != 0 && r < n)
	    {
	      ProcessNewAffinityMask |= 1;
	      r++;
	    }
	}
      SetProcessAffinityMask (GetCurrentProcess (),ProcessNewAffinityMask);
    }
  return r;
}

int
pthread_once (pthread_once_t *o, void (*func)(void))
{
  collect_once_t *co;
  long state = *o;

  CHECK_PTR(o);
  CHECK_PTR(func);

  if (state == 1)
    return 0;
  co = enterOnceObject(o);
  pthread_mutex_lock(&co->m);
  if (*o == 0)
    {
      pthread_cleanup_push(_pthread_once_cleanup, co);
      func();
      pthread_cleanup_pop(0);
      *o = 1;
    }
  else if (*o != 1)
    fprintf (stderr," once %p is %ld\n", (void *) o, (long) *o);
  pthread_mutex_unlock(&co->m);
  leaveOnceObject(co);

  return 0;
}

int
pthread_key_create (pthread_key_t *key, void (* dest)(void *))
{
	unsigned int i;
	long nmax;
	void (**d)(void *);

	if (!key)
		return EINVAL;

	pthread_rwlock_wrlock (&_pthread_key_lock);

	for (i = _pthread_key_sch; i < _pthread_key_max; i++)
	{
		if (!_pthread_key_dest[i])
		{
			*key = i;
			if (dest)
				_pthread_key_dest[i] = dest;
			else
				_pthread_key_dest[i] = (void(*)(void *))1;
			pthread_rwlock_unlock (&_pthread_key_lock);
			return 0;
		}
	}

	for (i = 0; i < _pthread_key_sch; i++)
	{
		if (!_pthread_key_dest[i])
		{
			*key = i;
			if (dest)
				_pthread_key_dest[i] = dest;
			else
				_pthread_key_dest[i] = (void(*)(void *))1;
			pthread_rwlock_unlock (&_pthread_key_lock);

			return 0;
		}
	}

	if (_pthread_key_max == PTHREAD_KEYS_MAX)
	{
		pthread_rwlock_unlock(&_pthread_key_lock);
		return ENOMEM;
	}

	nmax = _pthread_key_max * 2;
	if (nmax == 0)
		nmax = _pthread_key_max + 1;
	if (nmax > PTHREAD_KEYS_MAX)
		nmax = PTHREAD_KEYS_MAX;

	/* No spare room anywhere */
	d = (void (__cdecl **)(void *))realloc(_pthread_key_dest, nmax * sizeof(*d));
	if (!d)
	{
		pthread_rwlock_unlock (&_pthread_key_lock);
		return ENOMEM;
	}

	/* Clear new region */
	memset ((void *) &d[_pthread_key_max], 0, (nmax-_pthread_key_max)*sizeof(void *));

	/* Use new region */
	_pthread_key_dest = d;
	_pthread_key_sch = _pthread_key_max + 1;
	*key = _pthread_key_max;
	_pthread_key_max = nmax;

	if (dest)
		_pthread_key_dest[*key] = dest;
	else
		_pthread_key_dest[*key] = (void(*)(void *))1;

	pthread_rwlock_unlock (&_pthread_key_lock);
	return 0;
}

int
pthread_key_delete (pthread_key_t key)
{
  if (key >= _pthread_key_max || !_pthread_key_dest)
    return EINVAL;

  pthread_rwlock_wrlock (&_pthread_key_lock);
  
  _pthread_key_dest[key] = NULL;

  /* Start next search from our location */
  if (_pthread_key_sch > key)
    _pthread_key_sch = key;
  /* So now we need to walk the complete list of threads
     and remove key's reference for it.  */
  __pth_remove_use_for_key (key);

  pthread_rwlock_unlock (&_pthread_key_lock);
  return 0;
}

void *
pthread_getspecific (pthread_key_t key)
{
  DWORD lasterr = GetLastError ();
  void *r;
  _pthread_v *t = __pthread_self_lite ();
  pthread_spin_lock (&t->spin_keys);
  r = (key >= t->keymax || t->keyval_set[key] == 0 ? NULL : t->keyval[key]);
  pthread_spin_unlock (&t->spin_keys);
  SetLastError (lasterr);
  return r;
}

int
pthread_setspecific (pthread_key_t key, const void *value)
{
  DWORD lasterr = GetLastError ();
  _pthread_v *t = __pthread_self_lite ();
  
  pthread_spin_lock (&t->spin_keys);

  if (key >= t->keymax)
    {
      int keymax = (key + 1);
      void **kv;
      unsigned char *kv_set;

      kv = (void **) realloc (t->keyval, keymax * sizeof (void *));

      if (!kv)
        {
	  pthread_spin_unlock (&t->spin_keys);
	  return ENOMEM;
	}
      kv_set = (unsigned char *) realloc (t->keyval_set, keymax);
      if (!kv_set)
        {
	  pthread_spin_unlock (&t->spin_keys);
	  return ENOMEM;
	}

      /* Clear new region */
      memset (&kv[t->keymax], 0, (keymax - t->keymax)*sizeof(void *));
      memset (&kv_set[t->keymax], 0, (keymax - t->keymax));

      t->keyval = kv;
      t->keyval_set = kv_set;
      t->keymax = keymax;
    }

  t->keyval[key] = (void *) value;
  t->keyval_set[key] = 1;
  pthread_spin_unlock (&t->spin_keys);
  SetLastError (lasterr);

  return 0;
}

int
pthread_equal (pthread_t t1, pthread_t t2)
{
  return (t1 == t2);
}

void
pthread_tls_init (void)
{
  _pthread_tls = TlsAlloc();

  /* Cannot continue if out of indexes */
  if (_pthread_tls == TLS_OUT_OF_INDEXES)
    abort();
}

void
_pthread_cleanup_dest (pthread_t t)
{
	_pthread_v *tv;
	unsigned int i, j;

	if (!t)
		return;
	tv = __pth_gpointer_locked (t);
	if (!tv)
		return;

	for (j = 0; j < PTHREAD_DESTRUCTOR_ITERATIONS; j++)
	{
		int flag = 0;

		pthread_spin_lock (&tv->spin_keys);
		for (i = 0; i < tv->keymax; i++)
		{
			void *val = tv->keyval[i];

			if (tv->keyval_set[i])
			{
				pthread_rwlock_rdlock (&_pthread_key_lock);
				if ((uintptr_t) _pthread_key_dest[i] > 1)
				{
					/* Call destructor */
					tv->keyval[i] = NULL;
					tv->keyval_set[i] = 0;
					pthread_spin_unlock (&tv->spin_keys);
					_pthread_key_dest[i](val);
					pthread_spin_lock (&tv->spin_keys);
					flag = 1;
				}
				else
				{
					tv->keyval[i] = NULL;
					tv->keyval_set[i] = 0;
				}
				pthread_rwlock_unlock(&_pthread_key_lock);
			}
		}
		pthread_spin_unlock (&tv->spin_keys);
		/* Nothing to do? */
		if (!flag)
			return;
	}
}

static _pthread_v *
__pthread_self_lite (void)
{
  _pthread_v *t;
  pthread_spinlock_t new_spin_keys = PTHREAD_SPINLOCK_INITIALIZER;

  _pthread_once_raw (&_pthread_tls_once, pthread_tls_init);

  t = (_pthread_v *) TlsGetValue (_pthread_tls);
  if (t)
    return t;
  /* Main thread? */
  t = (struct _pthread_v *) pop_pthread_mem ();

  /* If cannot initialize main thread, then the only thing we can do is return null pthread_t */
  if (!__xl_f || !t)
    return 0;

  t->p_state = PTHREAD_DEFAULT_ATTR /*| PTHREAD_CREATE_DETACHED*/;
  t->tid = GetCurrentThreadId();
  t->evStart = CreateEvent (NULL, 1, 0, NULL);
  t->p_clock = PTHREAD_MUTEX_INITIALIZER;
  replace_spin_keys (&t->spin_keys, new_spin_keys);
  t->sched_pol = SCHED_OTHER;
  t->h = NULL; //GetCurrentThread();
  if (!DuplicateHandle(GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(), &t->h, 0, FALSE, DUPLICATE_SAME_ACCESS))
    abort ();
  t->sched.sched_priority = GetThreadPriority(t->h);
  t->ended = 0;
  t->thread_noposix = 1;

  /* Save for later */
  if (!TlsSetValue(_pthread_tls, t))
    abort ();
  return t;
}

pthread_t
pthread_self (void)
{
  _pthread_v *t = __pthread_self_lite ();

  if (!t)
    return 0;
  return t->x;
}

/* Internal helper for getting event handle of thread T.  */
void *
pthread_getevent (void)
{
  _pthread_v *t = __pthread_self_lite ();
  return (!t ? NULL : t->evStart);
}

/* Internal helper for getting thread handle of thread T.  */
void *
pthread_gethandle (pthread_t t)
{
  struct _pthread_v *tv = __pth_gpointer_locked (t);
  return (!tv ? NULL : tv->h);
}

/* Internal helper for getting pointer of clean of current thread.  */
struct _pthread_cleanup **
pthread_getclean (void)
{
  struct _pthread_v *t = __pthread_self_lite ();
  if (!t) return NULL;
  return &t->clean;
}

int
pthread_get_concurrency (int *val)
{
  *val = _pthread_concur;
  return 0;
}

int
pthread_set_concurrency (int val)
{
  _pthread_concur = val;
  return 0;
}

void
pthread_exit (void *res)
{
  _pthread_v *t = NULL;
  unsigned rslt = (unsigned) ((intptr_t) res);
  struct _pthread_v *id = __pthread_self_lite ();

  id->ret_arg = res;

  _pthread_cleanup_dest (id->x);
  if (id->thread_noposix == 0)
    longjmp(id->jb, 1);

  /* Make sure we free ourselves if we are detached */
  if ((t = (_pthread_v *)TlsGetValue(_pthread_tls)) != NULL)
    {
      if (!t->h)
	{
	  t->valid = DEAD_THREAD;
	  if (t->evStart)
	    CloseHandle (t->evStart);
	  t->evStart = NULL;
	  rslt = (unsigned) (size_t) t->ret_arg;
	  push_pthread_mem(t);
	  t = NULL;
	  TlsSetValue (_pthread_tls, t);
	}
      else
	{
	  rslt = (unsigned) (size_t) t->ret_arg;
	  t->ended = 1;
	  if (t->evStart)
	    CloseHandle (t->evStart);
	  t->evStart = NULL;
	  if ((t->p_state & PTHREAD_CREATE_DETACHED) == PTHREAD_CREATE_DETACHED)
	    {
	      t->valid = DEAD_THREAD;
	      CloseHandle (t->h);
	      t->h = NULL;
	      push_pthread_mem(t);
	      t = NULL;
	      TlsSetValue(_pthread_tls, t);
	    }
	}
    }
  /* Time to die */
  _endthreadex(rslt);
}

void
_pthread_invoke_cancel (void)
{
  _pthread_cleanup *pcup;
  struct _pthread_v *se = __pthread_self_lite ();
  se->in_cancel = 1;
  _pthread_setnobreak (1);
  InterlockedDecrement(&_pthread_cancelling);

  /* Call cancel queue */
  for (pcup = se->clean; pcup; pcup = pcup->next)
    {
      pcup->func((pthread_once_t *)pcup->arg);
    }

  _pthread_setnobreak (0);
  pthread_exit(PTHREAD_CANCELED);
}

int
__pthread_shallcancel (void)
{
  struct _pthread_v *t;
  if (!_pthread_cancelling)
    return 0;
  t = __pthread_self_lite ();
  if (t == NULL)
    return 0;
  if (t->nobreak <= 0 && t->cancelled && (t->p_state & PTHREAD_CANCEL_ENABLE))
    return 1;
  return 0;
}

void
_pthread_setnobreak (int v)
{
  struct _pthread_v *t = __pthread_self_lite ();
  if (t == NULL)
    return;
  if (v > 0)
    InterlockedIncrement ((long*)&t->nobreak);
  else
    InterlockedDecrement((long*)&t->nobreak);
}

void
pthread_testcancel (void)
{
  struct _pthread_v *self = __pthread_self_lite ();

  if (!self || self->in_cancel)
    return;
  if (!_pthread_cancelling)
    return;
  pthread_mutex_lock (&self->p_clock);

  if (self->cancelled && (self->p_state & PTHREAD_CANCEL_ENABLE) && self->nobreak <= 0)
    {
      self->in_cancel = 1;
      self->p_state &= ~PTHREAD_CANCEL_ENABLE;
      if (self->evStart)
	ResetEvent (self->evStart);
      pthread_mutex_unlock (&self->p_clock);
      _pthread_invoke_cancel ();
    }
  pthread_mutex_unlock (&self->p_clock);
}

int
pthread_cancel (pthread_t t)
{
  struct _pthread_v *tv = __pth_gpointer_locked (t);

  if (tv == NULL)
    return ESRCH;
  CHECK_OBJECT(tv, ESRCH);
  /*if (tv->ended) return ESRCH;*/
  pthread_mutex_lock(&tv->p_clock);
  if (pthread_equal(pthread_self(), t))
    {
      if(tv->cancelled)
	{
	  pthread_mutex_unlock(&tv->p_clock);
	  return (tv->in_cancel ? ESRCH : 0);
	}
      tv->cancelled = 1;
      InterlockedIncrement(&_pthread_cancelling);
      if(tv->evStart) SetEvent(tv->evStart);
      if ((tv->p_state & PTHREAD_CANCEL_ASYNCHRONOUS) != 0 && (tv->p_state & PTHREAD_CANCEL_ENABLE) != 0)
	{
	  tv->p_state &= ~PTHREAD_CANCEL_ENABLE;
	  tv->in_cancel = 1;
	  pthread_mutex_unlock(&tv->p_clock);
	  _pthread_invoke_cancel();
	}
      else
	pthread_mutex_unlock(&tv->p_clock);
      return 0;
    }

  if ((tv->p_state & PTHREAD_CANCEL_ASYNCHRONOUS) != 0 && (tv->p_state & PTHREAD_CANCEL_ENABLE) != 0)
    {
      /* Dangerous asynchronous cancelling */
      CONTEXT ctxt;

      if(tv->in_cancel)
	{
	  pthread_mutex_unlock(&tv->p_clock);
	  return (tv->in_cancel ? ESRCH : 0);
	}
      /* Already done? */
      if(tv->cancelled || tv->in_cancel)
	{
	  /* ??? pthread_mutex_unlock (&tv->p_clock); */
	  return ESRCH;
	}

      ctxt.ContextFlags = CONTEXT_CONTROL;

      SuspendThread (tv->h);
      if (WaitForSingleObject (tv->h, 0) == WAIT_TIMEOUT)
	{
	  GetThreadContext(tv->h, &ctxt);
#ifdef _M_X64
	  ctxt.Rip = (uintptr_t) _pthread_invoke_cancel;
#elif defined(_M_IX86)
	  ctxt.Eip = (uintptr_t) _pthread_invoke_cancel;
#elif defined(_M_ARM) || defined(_M_ARM64)
	  ctxt.Pc = (uintptr_t) _pthread_invoke_cancel;
#else
#error Unsupported architecture
#endif
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
	  SetThreadContext (tv->h, &ctxt);
#endif

	  /* Also try deferred Cancelling */
	  tv->cancelled = 1;
	  tv->p_state &= ~PTHREAD_CANCEL_ENABLE;
	  tv->in_cancel = 1;

	  /* Notify everyone to look */
	  InterlockedIncrement (&_pthread_cancelling);
	  if (tv->evStart)
	    SetEvent (tv->evStart);
	  pthread_mutex_unlock (&tv->p_clock);

	  ResumeThread (tv->h);
	}
    }
  else
    {
      if (tv->cancelled == 0)
	{
	  /* Safe deferred Cancelling */
	  tv->cancelled = 1;

	  /* Notify everyone to look */
	  InterlockedIncrement (&_pthread_cancelling);
	  if (tv->evStart)
	    SetEvent (tv->evStart);
	}
      else
	{
	  pthread_mutex_unlock (&tv->p_clock);
	  return (tv->in_cancel ? ESRCH : 0);
	}
    }
  pthread_mutex_unlock (&tv->p_clock);
  return 0;
}

/* half-stubbed version as we don't really well support signals */
int
pthread_kill (pthread_t t, int sig)
{
  struct _pthread_v *tv;

  pthread_mutex_lock (&mtx_pthr_locked);
  tv = __pthread_get_pointer (t);
  if (!tv || t != tv->x || tv->in_cancel || tv->ended || tv->h == NULL
      || tv->h == INVALID_HANDLE_VALUE)
  {
    pthread_mutex_unlock (&mtx_pthr_locked);
    return ESRCH;
  }
  pthread_mutex_unlock (&mtx_pthr_locked);
  if (!sig)
    return 0;
  if (sig < SIGINT || sig > NSIG)
    return EINVAL;
  return pthread_cancel(t);
}

unsigned
_pthread_get_state (const pthread_attr_t *attr, unsigned flag)
{
  return (attr->p_state & flag);
}

int
_pthread_set_state (pthread_attr_t *attr, unsigned flag, unsigned val)
{
  if (~flag & val)
    return EINVAL;
  attr->p_state &= ~flag;
  attr->p_state |= val;

  return 0;
}

int
pthread_attr_init (pthread_attr_t *attr)
{
  memset (attr, 0, sizeof (pthread_attr_t));
  attr->p_state = PTHREAD_DEFAULT_ATTR;
  attr->stack = NULL;
  attr->s_size = 0;
  return 0;
}

int
pthread_attr_destroy (pthread_attr_t *attr)
{
  /* No need to do anything */
  memset (attr, 0, sizeof(pthread_attr_t));
  return 0;
}

int
pthread_attr_setdetachstate (pthread_attr_t *a, int flag)
{
  return _pthread_set_state(a, PTHREAD_CREATE_DETACHED, flag);
}

int
pthread_attr_getdetachstate (const pthread_attr_t *a, int *flag)
{
  *flag = _pthread_get_state(a, PTHREAD_CREATE_DETACHED);
  return 0;
}

int
pthread_attr_setinheritsched (pthread_attr_t *a, int flag)
{
  if (!a || (flag != PTHREAD_INHERIT_SCHED && flag != PTHREAD_EXPLICIT_SCHED))
    return EINVAL;
  return _pthread_set_state(a, PTHREAD_INHERIT_SCHED, flag);
}

int
pthread_attr_getinheritsched (const pthread_attr_t *a, int *flag)
{
  *flag = _pthread_get_state(a, PTHREAD_INHERIT_SCHED);
  return 0;
}

int
pthread_attr_setscope (pthread_attr_t *a, int flag)
{
  return _pthread_set_state(a, PTHREAD_SCOPE_SYSTEM, flag);
}

int
pthread_attr_getscope (const pthread_attr_t *a, int *flag)
{
  *flag = _pthread_get_state(a, PTHREAD_SCOPE_SYSTEM);
  return 0;
}

int
pthread_attr_getstack (const pthread_attr_t *attr, void **stack, size_t *size)
{
  *stack = (char *) attr->stack - attr->s_size;
  *size = attr->s_size;
  return 0;
}

int
pthread_attr_setstack (pthread_attr_t *attr, void *stack, size_t size)
{
  attr->s_size = size;
  attr->stack = (char *) stack + size;
  return 0;
}

int
pthread_attr_getstackaddr (const pthread_attr_t *attr, void **stack)
{
  *stack = attr->stack;
  return 0;
}

int
pthread_attr_setstackaddr (pthread_attr_t *attr, void *stack)
{
  attr->stack = stack;
  return 0;
}

int
pthread_attr_getstacksize (const pthread_attr_t *attr, size_t *size)
{
  *size = attr->s_size;
  return 0;
}

int
pthread_attr_setstacksize (pthread_attr_t *attr, size_t size)
{
  attr->s_size = size;
  return 0;
}

static void
test_cancel_locked (pthread_t t)
{
  struct _pthread_v *tv = __pth_gpointer_locked (t);

  if (!tv || tv->in_cancel || tv->ended != 0 || (tv->p_state & PTHREAD_CANCEL_ENABLE) == 0)
    return;
  if ((tv->p_state & PTHREAD_CANCEL_ASYNCHRONOUS) == 0)
    return;
  if (WaitForSingleObject(tv->evStart, 0) != WAIT_OBJECT_0)
    return;
  pthread_mutex_unlock (&tv->p_clock);
  _pthread_invoke_cancel();
}

int
pthread_setcancelstate (int state, int *oldstate)
{
  _pthread_v *t = __pthread_self_lite ();

  if (!t || (state & PTHREAD_CANCEL_ENABLE) != state)
    return EINVAL;

  pthread_mutex_lock (&t->p_clock);
  if (oldstate)
    *oldstate = t->p_state & PTHREAD_CANCEL_ENABLE;
  t->p_state &= ~PTHREAD_CANCEL_ENABLE;
  t->p_state |= state;
  test_cancel_locked (t->x);
  pthread_mutex_unlock (&t->p_clock);

  return 0;
}

int
pthread_setcanceltype (int type, int *oldtype)
{
  _pthread_v *t = __pthread_self_lite ();

  if (!t || (type & PTHREAD_CANCEL_ASYNCHRONOUS) != type)
    return EINVAL;

  pthread_mutex_lock (&t->p_clock);
  if (oldtype)
    *oldtype = t->p_state & PTHREAD_CANCEL_ASYNCHRONOUS;
  t->p_state &= ~PTHREAD_CANCEL_ASYNCHRONOUS;
  t->p_state |= type;
  test_cancel_locked (t->x);
  pthread_mutex_unlock (&t->p_clock);

  return 0;
}

void _fpreset (void);

#if defined(__i386__)
/* Align ESP on 16-byte boundaries. */
#  if __GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 2)
__attribute__((force_align_arg_pointer))
#  endif
#endif
unsigned __stdcall
pthread_create_wrapper (void *args)
{
  unsigned rslt = 0;
  struct _pthread_v *tv = (struct _pthread_v *)args;

  _fpreset();

  pthread_mutex_lock (&mtx_pthr_locked);
  pthread_mutex_lock (&tv->p_clock);
  _pthread_once_raw(&_pthread_tls_once, pthread_tls_init);
  TlsSetValue(_pthread_tls, tv);
  tv->tid = GetCurrentThreadId();
  pthread_mutex_unlock (&tv->p_clock);


  if (!setjmp(tv->jb))
    {
      intptr_t trslt = (intptr_t) 128;
      /* Provide to this thread a default exception handler.  */
      #ifdef __SEH__
	asm ("\t.tl_start:\n");
      #endif      /* Call function and save return value */
      pthread_mutex_unlock (&mtx_pthr_locked);
      if (tv->func)
        trslt = (intptr_t) tv->func(tv->ret_arg);
      #ifdef __SEH__
	asm ("\tnop\n\t.tl_end: nop\n"
#ifdef __arm__
	  "\t.seh_handler __C_specific_handler, %except\n"
#else
	  "\t.seh_handler __C_specific_handler, @except\n"
#endif
	  "\t.seh_handlerdata\n"
	  "\t.long 1\n"
	  "\t.rva .tl_start, .tl_end, _gnu_exception_handler ,.tl_end\n"
	  "\t.text"
	  );
      #endif
      pthread_mutex_lock (&mtx_pthr_locked);
      tv->ret_arg = (void*) trslt;
      /* Clean up destructors */
      _pthread_cleanup_dest(tv->x);
    }
  else
    pthread_mutex_lock (&mtx_pthr_locked);

  pthread_mutex_lock (&tv->p_clock);
  rslt = (unsigned) (size_t) tv->ret_arg;
  /* Make sure we free ourselves if we are detached */
  if (tv->evStart)
    CloseHandle (tv->evStart);
  tv->evStart = NULL;
  if (!tv->h)
    {
      tv->valid = DEAD_THREAD;
      pthread_mutex_unlock (&tv->p_clock);
      pthread_mutex_destroy (&tv->p_clock);
      push_pthread_mem (tv);
      tv = NULL;
      TlsSetValue (_pthread_tls, tv);
    }
  else
    {
      pthread_mutex_unlock (&tv->p_clock);
      pthread_mutex_destroy (&tv->p_clock);
      /* Reinitialise p_clock, since there may be attempts at
         destroying it again in __dyn_tls_thread later on. */
      tv->p_clock = PTHREAD_MUTEX_INITIALIZER;
      tv->ended = 1;
    }
  while (pthread_mutex_unlock (&mtx_pthr_locked) == 0)
   Sleep (0);
  _endthreadex (rslt);
  return rslt;
}

int
pthread_create (pthread_t *th, const pthread_attr_t *attr, void *(* func)(void *), void *arg)
{
  HANDLE thrd = NULL;
  int redo = 0;
  struct _pthread_v *tv;
  unsigned int ssize = 0;
  pthread_spinlock_t new_spin_keys = PTHREAD_SPINLOCK_INITIALIZER;

  if (attr && attr->s_size > UINT_MAX)
    return EINVAL;

  if ((tv = pop_pthread_mem ()) == NULL)
    return EAGAIN;

  if (th)
    *th = tv->x;

  /* Save data in pthread_t */
  tv->ended = 0;
  tv->ret_arg = arg;
  tv->func = func;
  tv->p_state = PTHREAD_DEFAULT_ATTR;
  tv->h = INVALID_HANDLE_VALUE;
  /* We retry it here a few times, as events are a limited resource ... */
  do
    {
      tv->evStart = CreateEvent (NULL, 1, 0, NULL);
      if (tv->evStart != NULL)
	break;
      Sleep ((!redo ? 0 : 20));
    }
  while (++redo <= 4);

  tv->p_clock = PTHREAD_MUTEX_INITIALIZER;
  replace_spin_keys (&tv->spin_keys, new_spin_keys);
  tv->valid = LIFE_THREAD;
  tv->sched.sched_priority = THREAD_PRIORITY_NORMAL;
  tv->sched_pol = SCHED_OTHER;
  if (tv->evStart == NULL)
    {
      if (th)
       memset (th, 0, sizeof (pthread_t));
      push_pthread_mem (tv);
      return EAGAIN;
    }

  if (attr)
    {
      int inh = 0;
      tv->p_state = attr->p_state;
      ssize = (unsigned int)attr->s_size;
      pthread_attr_getinheritsched (attr, &inh);
      if (inh)
	{
	  tv->sched.sched_priority = __pthread_self_lite ()->sched.sched_priority;
	}
      else
	tv->sched.sched_priority = attr->param.sched_priority;
    }

  /* Make sure tv->h has value of INVALID_HANDLE_VALUE */
  _ReadWriteBarrier();

  thrd = (HANDLE) _beginthreadex(NULL, ssize, pthread_create_wrapper, tv, 0x4/*CREATE_SUSPEND*/, NULL);
  if (thrd == INVALID_HANDLE_VALUE)
    thrd = 0;
  /* Failed */
  if (!thrd)
    {
      if (tv->evStart)
	CloseHandle (tv->evStart);
      pthread_mutex_destroy (&tv->p_clock);
      replace_spin_keys (&tv->spin_keys, new_spin_keys);
      tv->evStart = NULL;
      tv->h = 0;
      if (th)
        memset (th, 0, sizeof (pthread_t));
      push_pthread_mem (tv);
      return EAGAIN;
    }
  {
    int pr = tv->sched.sched_priority;
    if (pr <= THREAD_PRIORITY_IDLE) {
	pr = THREAD_PRIORITY_IDLE;
    } else if (pr <= THREAD_PRIORITY_LOWEST) {
	pr = THREAD_PRIORITY_LOWEST;
    } else if (pr >= THREAD_PRIORITY_TIME_CRITICAL) {
	pr = THREAD_PRIORITY_TIME_CRITICAL;
    } else if (pr >= THREAD_PRIORITY_HIGHEST) {
	pr = THREAD_PRIORITY_HIGHEST;
    }
    SetThreadPriority (thrd, pr);
  }
  ResetEvent (tv->evStart);
  if ((tv->p_state & PTHREAD_CREATE_DETACHED) != 0)
    {
      tv->h = 0;
      ResumeThread (thrd);
      CloseHandle (thrd);
    }
  else
    {
      tv->h = thrd;
      ResumeThread (thrd);
    }
  Sleep (0);
  return 0;
}

int
pthread_join (pthread_t t, void **res)
{
  DWORD dwFlags;
  struct _pthread_v *tv = __pth_gpointer_locked (t);
  pthread_spinlock_t new_spin_keys = PTHREAD_SPINLOCK_INITIALIZER;

  if (!tv || tv->h == NULL || !GetHandleInformation(tv->h, &dwFlags))
    return ESRCH;
  if ((tv->p_state & PTHREAD_CREATE_DETACHED) != 0)
    return EINVAL;
  if (pthread_equal(pthread_self(), t))
    return EDEADLK;

  /* pthread_testcancel (); */
  if (tv->ended == 0 || (tv->h != NULL && tv->h != INVALID_HANDLE_VALUE))
    WaitForSingleObject (tv->h, INFINITE);
  CloseHandle (tv->h);
  if (tv->evStart)
    CloseHandle (tv->evStart);
  tv->evStart = NULL;
  /* Obtain return value */
  if (res)
    *res = tv->ret_arg;
  pthread_mutex_destroy (&tv->p_clock);
  replace_spin_keys (&tv->spin_keys, new_spin_keys);
  push_pthread_mem (tv);

  return 0;
}

int
_pthread_tryjoin (pthread_t t, void **res)
{
  DWORD dwFlags;
  struct _pthread_v *tv;
  pthread_spinlock_t new_spin_keys = PTHREAD_SPINLOCK_INITIALIZER;

  pthread_mutex_lock (&mtx_pthr_locked);
  tv = __pthread_get_pointer (t);

  if (!tv || tv->h == NULL || !GetHandleInformation(tv->h, &dwFlags))
    {
      pthread_mutex_unlock (&mtx_pthr_locked);
      return ESRCH;
    }

  if ((tv->p_state & PTHREAD_CREATE_DETACHED) != 0)
    {
      pthread_mutex_unlock (&mtx_pthr_locked);
      return EINVAL;
    }
  if (pthread_equal(pthread_self(), t))
    {
      pthread_mutex_unlock (&mtx_pthr_locked);
      return EDEADLK;
    }
  if(tv->ended == 0 && WaitForSingleObject(tv->h, 0))
    {
      if (tv->ended == 0)
        {
	      pthread_mutex_unlock (&mtx_pthr_locked);
	      /* pthread_testcancel (); */
	      return EBUSY;
	    }
    }
  CloseHandle (tv->h);
  if (tv->evStart)
    CloseHandle (tv->evStart);
  tv->evStart = NULL;

  /* Obtain return value */
  if (res)
    *res = tv->ret_arg;
  pthread_mutex_destroy (&tv->p_clock);
  replace_spin_keys (&tv->spin_keys, new_spin_keys);

  push_pthread_mem (tv);

  pthread_mutex_unlock (&mtx_pthr_locked);
  /* pthread_testcancel (); */
  return 0;
}

int
pthread_detach (pthread_t t)
{
  int r = 0;
  DWORD dwFlags;
  struct _pthread_v *tv = __pth_gpointer_locked (t);
  HANDLE dw;
  pthread_spinlock_t new_spin_keys = PTHREAD_SPINLOCK_INITIALIZER;

  pthread_mutex_lock (&mtx_pthr_locked);
  if (!tv || tv->h == NULL || !GetHandleInformation(tv->h, &dwFlags))
    {
      pthread_mutex_unlock (&mtx_pthr_locked);
      return ESRCH;
    }
  if ((tv->p_state & PTHREAD_CREATE_DETACHED) != 0)
    {
      pthread_mutex_unlock (&mtx_pthr_locked);
      return EINVAL;
    }
  /* if (tv->ended) r = ESRCH; */
  dw = tv->h;
  tv->h = 0;
  tv->p_state |= PTHREAD_CREATE_DETACHED;
  _ReadWriteBarrier();
  if (dw)
    {
      CloseHandle (dw);
      if (tv->ended)
	{
	  if (tv->evStart)
	    CloseHandle (tv->evStart);
	  tv->evStart = NULL;
	  pthread_mutex_destroy (&tv->p_clock);
	  replace_spin_keys (&tv->spin_keys, new_spin_keys);
	  push_pthread_mem (tv);
	}
    }
  pthread_mutex_unlock (&mtx_pthr_locked);

  return r;
}

static int dummy_concurrency_level = 0;

int
pthread_getconcurrency (void)
{
  return dummy_concurrency_level;
}

int
pthread_setconcurrency (int new_level)
{
  dummy_concurrency_level = new_level;
  return 0;
}

int
pthread_setname_np (pthread_t thread, const char *name)
{
  struct _pthread_v *tv;
  char *stored_name;

  if (name == NULL)
    return EINVAL;

  tv = __pth_gpointer_locked (thread);
  if (!tv || thread != tv->x || tv->in_cancel || tv->ended || tv->h == NULL
      || tv->h == INVALID_HANDLE_VALUE)
    return ESRCH;

  stored_name = strdup (name);
  if (stored_name == NULL)
    return ENOMEM;

  if (tv->thread_name != NULL)
    free (tv->thread_name);

  tv->thread_name = stored_name;
  SetThreadName (tv->tid, name);

  if (_pthread_set_thread_description != NULL)
    {
      size_t required_size = mbstowcs(NULL, name, 0);
      if (required_size != (size_t)-1)
        {
          wchar_t *wname = malloc((required_size + 1) * sizeof(wchar_t));
          if (wname != NULL)
            {
              mbstowcs(wname, name, required_size + 1);
              _pthread_set_thread_description(tv->h, wname);
              free(wname);
            }
        }
    }
  return 0;
}

int
pthread_getname_np (pthread_t thread, char *name, size_t len)
{
  HRESULT result;
  struct _pthread_v *tv;

  if (name == NULL)
    return EINVAL;

  tv = __pth_gpointer_locked (thread);
  if (!tv || thread != tv->x || tv->in_cancel || tv->ended || tv->h == NULL
      || tv->h == INVALID_HANDLE_VALUE)
    return ESRCH;

  if (len < 1)
    return ERANGE;

  if (tv->thread_name == NULL)
    {
      name[0] = '\0';
      return 0;
    }

  if (strlen (tv->thread_name) >= len)
    return ERANGE;

  result = StringCchCopyNA (name, len, tv->thread_name, len - 1);
  if (SUCCEEDED (result))
    return 0;

  return ERANGE;
}
