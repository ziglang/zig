#include <dlfcn.h>
#include <stdlib.h>
#include <stdarg.h>
#include "pthread_impl.h"
#include "dynlink.h"
#include "atomic.h"

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

/* Atomic singly-linked list, used to store list of thread-local dlerror
 * buffers for deferred free. They cannot be freed at thread exit time
 * because, by the time it's known they can be freed, the exiting thread
 * is in a highly restrictive context where it cannot call (even the
 * libc-internal) free. It also can't take locks; thus the atomic list. */

static void *volatile freebuf_queue;

void __dl_thread_cleanup(void)
{
	pthread_t self = __pthread_self();
	if (!self->dlerror_buf || self->dlerror_buf == (void *)-1)
		return;
	void *h;
	do {
		h = freebuf_queue;
		*(void **)self->dlerror_buf = h;
	} while (a_cas_p(&freebuf_queue, h, self->dlerror_buf) != h);
}

hidden void __dl_vseterr(const char *fmt, va_list ap)
{
	void **q;
	do q = freebuf_queue;
	while (q && a_cas_p(&freebuf_queue, q, 0) != q);

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
