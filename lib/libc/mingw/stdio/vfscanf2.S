/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

#define FCT __MINGW_USYMBOL(vfscanf)
#define FWD __MINGW_USYMBOL(__ms_vfscanf)

	.file   "vfscanf2.S"
#include "scanf2-template.S"
