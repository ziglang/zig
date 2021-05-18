#include <sys/utsname.h>
#ifdef __wasilibc_unmodified_upstream // Implement uname with placeholders
#include "syscall.h"
#else
#include <string.h>
#endif

int uname(struct utsname *uts)
{
#ifdef __wasilibc_unmodified_upstream // Implement uname with placeholders
	return syscall(SYS_uname, uts);
#else
	// Just fill in the fields with placeholder values.
	strcpy(uts->sysname, "wasi");
	strcpy(uts->nodename, "(none)");
	strcpy(uts->release, "0.0.0");
	strcpy(uts->version, "0.0.0");
#if defined(__wasm32__)
	strcpy(uts->machine, "wasm32");
#elif defined(__wasm64__)
	strcpy(uts->machine, "wasm64");
#else
	strcpy(uts->machine, "unknown");
#endif
#ifdef _GNU_SOURCE
	strcpy(uts->domainname, "(none)");
#else
	strcpy(uts->__domainname, "(none)");
#endif
	return 0;
#endif
}
