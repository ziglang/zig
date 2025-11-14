/*
 * Copyright (c) 2004 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
#ifndef _MACH_O_GETSECT_H_
#define _MACH_O_GETSECT_H_

#include <stdint.h>
#include <mach-o/loader.h>
#include <Availability.h>
#include <TargetConditionals.h>

#ifndef __CCTOOLS_DEPRECATED
    #define __CCTOOLS_DEPRECATED            __API_DEPRECATED("No longer supported", macos(10.0, 13.0), ios(1.0, 16.0), watchos(1.0, 8.0), tvos(1.0, 16.0))
    #define __CCTOOLS_DEPRECATED_MSG(_msg)  __API_DEPRECATED_WITH_REPLACEMENT(_msg, macos(10.0, 13.0), ios(1.0, 16.0), watchos(1.0, 8.0), tvos(1.0, 16.0))
#endif


#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/*
 * Runtime interfaces for Mach-O programs.  For both 32-bit and 64-bit programs,
 * where the sizes returned will be 32-bit or 64-bit based on the size of
 * 'unsigned long'.
 */
extern char *getsectdata(
    const char *segname,
    const char *sectname,
    unsigned long *size) __CCTOOLS_DEPRECATED_MSG("use getsectiondata()");

extern char *getsectdatafromFramework(
    const char *FrameworkName,
    const char *segname,
    const char *sectname,
    unsigned long *size) __CCTOOLS_DEPRECATED;

extern unsigned long get_end(void) __CCTOOLS_DEPRECATED;
extern unsigned long get_etext(void) __CCTOOLS_DEPRECATED;
extern unsigned long get_edata(void) __CCTOOLS_DEPRECATED;

#ifndef __LP64__
/*
 * Runtime interfaces for 32-bit Mach-O programs.
 */
extern const struct section *getsectbyname(
    const char *segname,
    const char *sectname) __CCTOOLS_DEPRECATED_MSG("use getsectiondata(&__dso_handle,)");

extern uint8_t *getsectiondata(
    const struct mach_header *mhp,
    const char *segname,
    const char *sectname,
    unsigned long *size);

extern const struct segment_command *getsegbyname(
    const char *segname) __CCTOOLS_DEPRECATED;

extern uint8_t *getsegmentdata(
    const struct mach_header *mhp,
    const char *segname,
    unsigned long *size);

#else /* defined(__LP64__) */
/*
 * Runtime interfaces for 64-bit Mach-O programs.
 */
extern const struct section_64 *getsectbyname(
    const char *segname,
    const char *sectname);

extern uint8_t *getsectiondata(
    const struct mach_header_64 *mhp,
    const char *segname,
    const char *sectname,
    unsigned long *size);

extern const struct segment_command_64 *getsegbyname(
    const char *segname) __CCTOOLS_DEPRECATED;

extern uint8_t *getsegmentdata(
    const struct mach_header_64 *mhp,
    const char *segname,
    unsigned long *size);

#endif /* defined(__LP64__) */

/*
 * Interfaces for tools working with 32-bit Mach-O files.
 */
extern char *getsectdatafromheader(
    const struct mach_header *mhp,
    const char *segname,
    const char *sectname,
    uint32_t *size) __CCTOOLS_DEPRECATED_MSG("use getsectiondata()");

extern const struct section *getsectbynamefromheader(
    const struct mach_header *mhp,
    const char *segname,
    const char *sectname) __CCTOOLS_DEPRECATED_MSG("use getsectiondata()");

extern const struct section *getsectbynamefromheaderwithswap(
    struct mach_header *mhp,
    const char *segname,
    const char *sectname,
    int fSwap) __CCTOOLS_DEPRECATED_MSG("use getsectiondata()");

/*
 * Interfaces for tools working with 64-bit Mach-O files.
 */
extern char *getsectdatafromheader_64(
    const struct mach_header_64 *mhp,
    const char *segname,
    const char *sectname,
    uint64_t *size) __CCTOOLS_DEPRECATED_MSG("use getsectiondata()");

extern const struct section_64 *getsectbynamefromheader_64(
    const struct mach_header_64 *mhp,
    const char *segname,
    const char *sectname) __CCTOOLS_DEPRECATED_MSG("use getsectiondata()");

extern const struct section *getsectbynamefromheaderwithswap_64(
    struct mach_header_64 *mhp,
    const char *segname,
    const char *sectname,
    int fSwap) __CCTOOLS_DEPRECATED_MSG("use getsectiondata()");

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _MACH_O_GETSECT_H_ */
