 /**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _PROCESSTOPOLOGYAPI_H_
#define _PROCESSTOPOLOGYAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI GetProcessGroupAffinity (HANDLE hProcess, PUSHORT GroupCount, PUSHORT GroupArray);
  WINBASEAPI WINBOOL WINAPI SetProcessGroupAffinity (HANDLE hProcess, CONST GROUP_AFFINITY *GroupAffinity, PGROUP_AFFINITY PreviousGroupAffinity);
  WINBASEAPI WINBOOL WINAPI GetThreadGroupAffinity (HANDLE hThread, PGROUP_AFFINITY GroupAffinity);
  WINBASEAPI WINBOOL WINAPI SetThreadGroupAffinity (HANDLE hThread, CONST GROUP_AFFINITY *GroupAffinity, PGROUP_AFFINITY PreviousGroupAffinity);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
