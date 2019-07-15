/*
 * usb100.h
 *
 * USB 2.0 support
 *
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 *
 * This file is based on the ReactOS PSDK package file usb100.h header.
 * Original contributors by Magnus Olsen.
 *
 * Winapi-family check and replace header by usbspec.h header by Kai Tietz.
 */

#ifndef __USB200_H__
#define __USB200_H__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#include "usbspec.h"
#endif
#endif
