/*
 * Copyright (c) 2013 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 * 
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */

#ifndef __HFS_UNISTR__
#define __HFS_UNISTR__

#include <sys/types.h>

/* 
 * hfs_unitstr.h
 *
 * This file contains definition of the unicode string used for HFS Plus 
 * files and folder names, as described by the on-disk format.
 *
 */

#ifdef __cplusplus
extern "C" {
#endif


#ifndef _HFSUNISTR255_DEFINED_
#define _HFSUNISTR255_DEFINED_
/* Unicode strings are used for HFS Plus file and folder names */
struct HFSUniStr255 {
	u_int16_t	length;		/* number of unicode characters */
	u_int16_t	unicode[255];	/* unicode characters */
} __attribute__((aligned(2), packed));
typedef struct HFSUniStr255 HFSUniStr255;
typedef const HFSUniStr255 *ConstHFSUniStr255Param;
#endif /* _HFSUNISTR255_DEFINED_ */


#ifdef __cplusplus
}
#endif


#endif /* __HFS_UNISTR__ */