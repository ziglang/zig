/* This file is used to build libdl.so with stub versions of `dlopen`, `dlsym`,
 * etc.  The intention is that this stubbed libdl.so can be used to build
 * libraries and applications which use `dlopen` without committing to a
 * specific runtime implementation.  Later, it can be replaced with a real,
 * working libdl.so (e.g. at runtime or component composition time).
 * 
 * For example, the `wasm-tools component link` subcommand can be used to create
 * a component that bundles any `dlopen`-able libraries in such a way that their
 * function exports can be resolved symbolically at runtime using an
 * implementation of libdl.so designed for that purpose.  In other cases, a
 * runtime might provide Emscripten-style dynamic linking via URLs or else a
 * more traditional, filesystem-based implementation.  Finally, even this
 * stubbed version of libdl.so can be used at runtime in cases where dynamic
 * library resolution cannot or should not be supported (and the application can
 * handle this situation gracefully). */

#include <stddef.h>
#include <dlfcn.h>

static const char *error = NULL;

weak int dlclose(void *library)
{
	error = "dlclose not implemented";
	return -1;
}

weak char *dlerror(void)
{
	const char *var = error;
	error = NULL;
	return (char*) var;
}

weak void *dlopen(const char *name, int flags)
{
	error = "dlopen not implemented";
	return NULL;
}

weak void *dlsym(void *library, const char *name)
{
	error = "dlsym not implemented";
	return NULL;
}
