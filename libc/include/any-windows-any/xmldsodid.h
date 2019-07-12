/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __XMLDSODID_H__
#define __XMLDSODID_H__

#define DISPID_XOBJ_MIN 0x00010000
#define DISPID_XOBJ_MAX 0x0001FFFF
#define DISPID_XOBJ_BASE DISPID_XOBJ_MIN

#define DISPID_XMLDSO DISPID_XOBJ_BASE
#define DISPID_XMLDSO_DOCUMENT DISPID_XMLDSO + 1
#define DISPID_XMLDSO_JAVADSOCOMPATIBLE DISPID_XMLDSO_DOCUMENT + 1
#endif
