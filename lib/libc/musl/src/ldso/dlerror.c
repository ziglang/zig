#include <dlfcn.h>
#include <stdlib.h>
#include <stdarg.h>
#include "pthread_impl.h"
#include "dynlink.h"
#include "lock.h"
#include "fork_impl.h"

#define malloc __libc_malloc
#define calloc __libc_calloc
#define realloc __libc_realloc
#define free __libc_free

char *dlerror()
{
	pthread_t self = __pthread_self();
	if (!self->dlerror_flag) return 0;
	self->dlerror_flag = 0;
	char *s = self->dlerror_buf;
	if (s == (void *)-1)
		return "Dynamic linker failed to allocate memory for error message";
	else
		return s;
}

static volatile int freebuf_queue_lock[1];
static void **freebuf_queue;
volatile int *const __dlerror_lockptr = freebuf_queue_lock;

void __dl_thread_cleanup(void)
{
	pthread_t self = __pthread_self();
	if (self->dlerror_buf && self->dlerror_buf != (void *)-1) {
		LOCK(freebuf_queue_lock);
		void **p = (void **)self->dlerror_buf;
		*p = freebuf_queue;
		freebuf_queue = p;
		UNLOCK(freebuf_queue_lock);
	}
}

hidden void __dl_vseterr(const char *fmt, va_list ap)
{
	LOCK(freebuf_queue_lock);
	void **q = freebuf_queue;
	freebuf_queue = 0;
	UNLOCK(freebuf_queue_lock);

	while (q) {
		void **p = *q;
		free(q);
		q = p;
	}

	va_list ap2;
	va_copy(ap2, ap);
	pthread_t self = __pthread_self();
	if (self->dlerror_buf != (void *)-1)
		free(self->dlerror_buf);
	size_t len = vsnprintf(0, 0, fmt, ap2);
	if (len < sizeof(void *)) len = sizeof(void *);
	va_end(ap2);
	char *buf = malloc(len+1);
	if (buf) {
		vsnprintf(buf, len+1, fmt, ap);
	} else {
		buf = (void *)-1;	
	}
	self->dlerror_buf = buf;
	self->dlerror_flag = 1;
}

hidden void __dl_seterr(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	__dl_vseterr(fmt, ap);
	va_end(ap);
}

static int stub_invalid_handle(void *h)
{
	__dl_seterr("Invalid library handle %p", (void *)h);
	return 1;
}

weak_alias(stub_invalid_handle, __dl_invalid_handle);
