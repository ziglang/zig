/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <winapifamily.h>

#ifndef _INC_MMSYSTEM
#define _INC_MMSYSTEM

#include <mmsyscom.h>

#include <pshpack1.h>

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifndef MMNOMCI
#include <mciapi.h>
#endif

#include <mmiscapi.h>
#include <mmiscapi2.h>
#include <playsoundapi.h>
#include <mmeapi.h>

#ifndef MMNOTIMER
#include <timeapi.h>
#endif

#include <joystickapi.h>

#ifndef NEWTRANSPARENT
#define NEWTRANSPARENT  3
#define QUERYROPSUPPORT 40
#endif

#define SELECTDIB 41
#define DIBINDEX(n) MAKELONG((n),0x10FF)

#ifndef SC_SCREENSAVE
#define SC_SCREENSAVE 0xF140
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#ifdef __cplusplus
}
#endif

#include <poppack.h>

#endif /* _INC_MMSYSTEM */
