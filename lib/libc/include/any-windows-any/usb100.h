/**
 * usb100.h
 *
 * USB 1.0 support
 *
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 *
 * This file is based on the ReactOS PSDK package file usb100.h header.
 * Original contributors by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * Add winap-family check and move content into usbspec.h header by Kai Tietz.
 */

#ifndef __USB100_H__
#define __USB100_H__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#include "usbspec.h"
#endif

#endif
