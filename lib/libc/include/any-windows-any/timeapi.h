/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _TIMERAPI_H_
#define _TIMERAPI_H_

#include <apiset.h>
#include <apisetcconv.h>

#include <mmsyscom.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifndef MMNOTIMER

#define TIMERR_NOERROR (0)
#define TIMERR_NOCANDO (TIMERR_BASE+1)
#define TIMERR_STRUCT (TIMERR_BASE+33)

typedef struct timecaps_tag {
    UINT wPeriodMin;
    UINT wPeriodMax;
} TIMECAPS, *PTIMECAPS, *NPTIMECAPS, *LPTIMECAPS;

WINMMAPI MMRESULT WINAPI timeGetSystemTime(LPMMTIME pmmt, UINT cbmmt);

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

WINMMAPI DWORD WINAPI timeGetTime(void);

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

WINMMAPI MMRESULT WINAPI timeGetDevCaps(LPTIMECAPS ptc, UINT cbtc);
WINMMAPI MMRESULT WINAPI timeBeginPeriod(UINT uPeriod);
WINMMAPI MMRESULT WINAPI timeEndPeriod(UINT uPeriod);

#endif  /* ifndef MMNOTIMER */

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#ifdef __cplusplus
}
#endif

#endif /* _TIMERAPI_H_ */
