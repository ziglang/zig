/*
 * Copyright (c) 2004-2008 Apple Inc. All rights reserved.
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

/*
  Based on the dlcompat work done by:
		Jorge Acereda  <jacereda@users.sourceforge.net> &
		Peter O'Gorman <ogorman@users.sourceforge.net>
*/

#ifndef _DLFCN_H_
#define _DLFCN_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/cdefs.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <stdbool.h>
#include <Availability.h>

#ifdef __DRIVERKIT_19_0
 #define __DYLDDL_DRIVERKIT_UNAVAILABLE __API_UNAVAILABLE(driverkit)
#else
 #define __DYLDDL_DRIVERKIT_UNAVAILABLE
#endif

/*
 * Structure filled in by dladdr().
 */
typedef struct dl_info {
        const char      *dli_fname;     /* Pathname of shared object */
        void            *dli_fbase;     /* Base address of shared object */
        const char      *dli_sname;     /* Name of nearest symbol */
        void            *dli_saddr;     /* Address of nearest symbol */
} Dl_info;

extern int dladdr(const void *, Dl_info *);
#else
 #define __DYLDDL_DRIVERKIT_UNAVAILABLE
#endif /* not POSIX */

extern int dlclose(void * __handle) __DYLDDL_DRIVERKIT_UNAVAILABLE;
extern char * dlerror(void) __DYLDDL_DRIVERKIT_UNAVAILABLE;
extern void * dlopen(const char * __path, int __mode) __DYLDDL_DRIVERKIT_UNAVAILABLE;
extern void * dlsym(void * __handle, const char * __symbol);

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
extern bool dlopen_preflight(const char* __path) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0) __DYLDDL_DRIVERKIT_UNAVAILABLE;
#endif /* not POSIX */


#define RTLD_LAZY	0x1
#define RTLD_NOW	0x2
#define RTLD_LOCAL	0x4
#define RTLD_GLOBAL	0x8

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define RTLD_NOLOAD	0x10
#define RTLD_NODELETE	0x80
#define RTLD_FIRST	0x100	/* Mac OS X 10.5 and later */

/*
 * Special handle arguments for dlsym().
 */
#define	RTLD_NEXT	((void *) -1)	/* Search subsequent objects. */
#define	RTLD_DEFAULT	((void *) -2)	/* Use default search algorithm. */
#define	RTLD_SELF	((void *) -3)	/* Search this and subsequent objects (Mac OS X 10.5 and later) */
#define	RTLD_MAIN_ONLY	((void *) -5)	/* Search main executable only (Mac OS X 10.5 and later) */
#endif /* not POSIX */

#ifdef __cplusplus
}
#endif

#endif /* _DLFCN_H_ */