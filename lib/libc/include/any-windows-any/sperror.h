/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef SPError_h
#define SPError_h

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#include <winerror.h>

#define FACILITY_SAPI FACILITY_ITF
#define SAPI_ERROR_BASE 0x5000

#define MAKE_SAPI_HRESULT(sev, err) MAKE_HRESULT(sev, FACILITY_SAPI, err)
#define MAKE_SAPI_ERROR(err)        MAKE_SAPI_HRESULT(SEVERITY_ERROR, err+SAPI_ERROR_BASE)
#define MAKE_SAPI_SCODE(scode)      MAKE_SAPI_HRESULT(SEVERITY_SUCCESS, scode+SAPI_ERROR_BASE)

#define SPERR_NOT_FOUND MAKE_SAPI_ERROR(0x003a)

#endif
#endif
