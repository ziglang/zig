/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _WINCON_
#define _WINCON_

#include <winapifamily.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <wincontypes.h>

#ifndef NOGDI
#include <wingdi.h>
#endif

#ifndef NOAPISET
#include <consoleapi.h>
#include <consoleapi2.h>
#include <consoleapi3.h>
#endif

#define CONSOLE_REAL_OUTPUT_HANDLE (LongToHandle(-2))
#define CONSOLE_REAL_INPUT_HANDLE (LongToHandle(-3))

#define CONSOLE_TEXTMODE_BUFFER 1

#ifdef __cplusplus
}
#endif

#endif /* _WINCON_ */
