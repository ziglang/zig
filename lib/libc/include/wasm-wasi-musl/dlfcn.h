#ifndef	_DLFCN_H
#define	_DLFCN_H

#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>

#define RTLD_LAZY   1
#define RTLD_NOW    2
#define RTLD_NOLOAD 4
#define RTLD_NODELETE 4096
#define RTLD_GLOBAL 256
#ifdef __wasilibc_unmodified_upstream
#define RTLD_LOCAL  0
#else
/* For WASI, we give `RTLD_LOCAL` a non-zero value, avoiding ambiguity and
 * allowing us to defer the decision of whether `RTLD_LOCAL` or `RTLD_GLOBAL`
 * should be the default when neither is specified.
 */
#define RTLD_LOCAL  8
#endif

#define RTLD_NEXT    ((void *)-1)
#define RTLD_DEFAULT ((void *)0)

#ifdef __wasilibc_unmodified_upstream
#define RTLD_DI_LINKMAP 2
#endif

int    dlclose(void *);
char  *dlerror(void);
void  *dlopen(const char *, int);
void  *dlsym(void *__restrict, const char *__restrict);

#if defined(__wasilibc_unmodified_upstream) && (defined(_GNU_SOURCE) || defined(_BSD_SOURCE))
typedef struct {
	const char *dli_fname;
	void *dli_fbase;
	const char *dli_sname;
	void *dli_saddr;
} Dl_info;
int dladdr(const void *, Dl_info *);
int dlinfo(void *, int, void *);
#endif

#if _REDIR_TIME64
__REDIR(dlsym, __dlsym_time64);
#endif

#ifdef __cplusplus
}
#endif

#endif
