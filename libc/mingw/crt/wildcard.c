/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

/* _dowildcard is an int that controls the globbing of the command line.
 * If _dowildcard is non-zero, the command line will be globbed:  *.*
 * will be expanded to be all files in the startup directory.
 *
 * In the mingw-w64 library the _dowildcard variable is defined as being
 * 0, therefore command line globbing is DISABLED by default. To turn it
 * on and to leave wildcard command line processing MS's globbing code,
 * include a line in one of your source modules defining _dowildcard and
 * setting it to -1, like so:
 * int _dowildcard = -1;
 *
 * Alternatively, the mingw-w64 library can be configured using the
 * --enable-wildcard option and compiled thusly upon which the resulting
 * library will have _dowildcard as -1 and command line globbing will be
 * enabled by default.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifndef __ENABLE_GLOBBING
#define __ENABLE_GLOBBING 0 /* -1 */
#endif

int _dowildcard = __ENABLE_GLOBBING;

