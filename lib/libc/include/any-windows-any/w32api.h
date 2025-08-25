/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _W32API_H
#define _W32API_H
#define _W32API_H_
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#define __W32API_VERSION 3.14
#define __W32API_MAJOR_VERSION 3
#define __W32API_MINOR_VERSION 14

/* The following defines are for documentation purposes.  The following defines
 * identify the versions of Windows and Internet Explorer.  They are not to be
 * used in the w32api library but may be used by a user to set the _WIN32_WINNT
 * or _WIN32_WINDOWS and the WINVER values to their minimum level of support.
 *
 * Similarly the user can use the Internet Explorer values to set the _WIN32_IE
 * value to their minimum level of support.
 */

/* Use these values to set _WIN32_WINDOWS and WINVER to your minimum support 
 * level */
#define Windows95    0x0400
#define Windows98    0x0410
#define WindowsME    0x0500

/* Use these values to set _WIN32_WINNT and WINVER to your mimimum support 
 * level. */
#define WindowsNT4   0x0400
#define Windows2000  0x0500
#define WindowsXP    0x0501
#define Windows2003  0x0502
#define WindowsVista 0x0600
#define Windows7     0x0601
#define Windows8     0x0602

/* Use these values to set _WIN32_IE to your minimum support level */
#define IE3	0x0300
#define IE301	0x0300
#define IE302	0x0300
#define IE4	0x0400
#define IE401	0x0401
#define IE5	0x0500
#define IE5a	0x0500
#define IE5b	0x0500
#define IE501	0x0501
#define IE55	0x0501
#define IE56	0x0560
#define IE6	0x0600
#define IE601	0x0601
#define IE602	0x0603
#define IE7	0x0700
#define IE8	0x0800
#define IE9	0x0900
#define IE10	0x0A00

#endif /* ndef _W32API_H */
