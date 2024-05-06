/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

/* crt/libsrc/vss-uuid.c */
/* Generate GUIDs for Volume Shadow Copy Service interfaces */

#include <windows.h>
#include <initguid.h>
#include <vss.h>
#include <vsadmin.h>
#include <vsbackup.h>
#include <vsmgmt.h>
#include <vsprov.h>
#include <vswriter.h>
