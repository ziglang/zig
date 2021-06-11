#include <stdlib.h>
#include <stdint.h>
#include "libc.h"

static void dummy()
{
}

/* atexit.c and __stdio_exit.c override these. the latter is linked
 * as a consequence of linking either __toread.c or __towrite.c. */
weak_alias(dummy, __funcs_on_exit);
weak_alias(dummy, __stdio_exit);
#ifdef __wasilibc_unmodified_upstream // fini
weak_alias(dummy, _fini);

extern weak hidden void (*const __fini_array_start)(void), (*const __fini_array_end)(void);

static void libc_exit_fini(void)
{
	uintptr_t a = (uintptr_t)&__fini_array_end;
	for (; a>(uintptr_t)&__fini_array_start; a-=sizeof(void(*)()))
		(*(void (**)())(a-sizeof(void(*)())))();
	_fini();
}

weak_alias(libc_exit_fini, __libc_exit_fini);
#endif

#ifdef __wasilibc_unmodified_upstream // WASI libc uses a custom exit
_Noreturn void exit(int code)
{
	__funcs_on_exit();
	__libc_exit_fini();
	__stdio_exit();
	_Exit(code);
}
#else
// Split out the cleanup functions so that we can call them without calling
// _Exit if we don't need to. This allows _start to just return if main
// returns 0.
void __wasm_call_dtors(void)
{
	__funcs_on_exit();
	__stdio_exit();
}

_Noreturn void exit(int code)
{
	__wasm_call_dtors();
	_Exit(code);
}
#endif
