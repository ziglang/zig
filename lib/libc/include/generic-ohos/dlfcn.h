#ifndef	_DLFCN_H
#define	_DLFCN_H

#include <features.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RTLD_LAZY   1
#define RTLD_NOW    2
#define RTLD_NOLOAD 4
#define RTLD_NODELETE 4096
#define RTLD_GLOBAL 256
#define RTLD_LOCAL  0

#define RTLD_NEXT    ((void *)-1)
#define RTLD_DEFAULT ((void *)0)

#define RTLD_DI_LINKMAP 2

int    dlclose(void *);
char  *dlerror(void);
void  *dlopen(const char *, int);
void  *dlsym(void *__restrict, const char *__restrict);


/**
 * @brief Obtain address of a symbol in a shared object or executable
 * 
 * @param (void *__restrict) the handle to the dynamic link library
 * @param (const char *restrict) the name of the symbol to be looked up
 * @param (const char *restrict) the specific version of the symbol to be looked up
 * 
 * @return On success, return the address associated with symbol. On failure, return NULL
 * @since 12
*/
void *dlvsym(void *__restrict, const char *__restrict, const char *__restrict);

/* namespace apis */
#define NS_NAME_MAX 255
typedef struct {
	char name[NS_NAME_MAX+1];
} Dl_namespace;

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
typedef struct {
	const char *dli_fname;
	void *dli_fbase;
	const char *dli_sname;
	void *dli_saddr;
} Dl_info;
int dladdr(const void *, Dl_info *);
#endif

#if _REDIR_TIME64
__REDIR(dlsym, __dlsym_time64);
#endif

#ifdef __cplusplus
}
#endif

#endif