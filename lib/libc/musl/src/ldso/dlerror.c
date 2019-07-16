#include <dlfcn.h>
#include <stdlib.h>
#include <stdarg.h>
#include "pthread_impl.h"
#include "dynlink.h"

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

void __dl_thread_cleanup(void)
{
	pthread_t self = __pthread_self();
	if (self->dlerror_buf != (void *)-1)
		free(self->dlerror_buf);
}

hidden void __dl_vseterr(const char *fmt, va_list ap)
{
	va_list ap2;
	va_copy(ap2, ap);
	pthread_t self = __pthread_self();
	if (self->dlerror_buf != (void *)-1)
		free(self->dlerror_buf);
	size_t len = vsnprintf(0, 0, fmt, ap2);
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
