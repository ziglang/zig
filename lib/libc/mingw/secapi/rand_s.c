#define _CRT_RAND_S
#include <stdlib.h>
#include <windows.h>
#include <ntsecapi.h>
#include <errno.h>
#include <msvcrt.h>

static BOOLEAN (WINAPI *pRtlGenRandom)(void*,ULONG);

static errno_t mingw_rand_s(unsigned int *pval)
{
    return !pval || !pRtlGenRandom || !pRtlGenRandom(pval, sizeof(*pval)) ? EINVAL : 0;
}

static errno_t __cdecl init_rand_s(unsigned int*);

errno_t (__cdecl *__MINGW_IMP_SYMBOL(rand_s))(unsigned int*) = init_rand_s;

static errno_t __cdecl init_rand_s(unsigned int *val)
{
    int (__cdecl *func)(unsigned int*);

    func = (void*)GetProcAddress(__mingw_get_msvcrt_handle(), "rand_s");
    if(!func) {
        func = mingw_rand_s;
        pRtlGenRandom = (void*)GetProcAddress(LoadLibraryW(L"advapi32.dll"), "SystemFunction036");
    }

    return (__MINGW_IMP_SYMBOL(rand_s) = func)(val);
}
