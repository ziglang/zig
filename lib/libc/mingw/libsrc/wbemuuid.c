/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

/* crt/libsrc/wbemuuid.c */
/* Generate GUIDs for Windows Management Instrumentation (WMI) Provider interfaces */

#define INITGUID
#include <basetyps.h>
#include <wbemads.h>
#include <wbemcli.h>
#include <wbemdisp.h>
#include <wbemprov.h>
#include <wbemtran.h>
#include <wmiutils.h>
