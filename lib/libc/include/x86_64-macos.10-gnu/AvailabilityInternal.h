/*
 * Copyright (c) 2007-2016 by Apple Inc.. All rights reserved.
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
    File:       AvailabilityInternal.h
 
    Contains:   implementation details of __OSX_AVAILABLE_* macros from <Availability.h>

*/
#ifndef __AVAILABILITY_INTERNAL__
#define __AVAILABILITY_INTERNAL__

#if __has_include(<AvailabilityInternalPrivate.h>)
  #include <AvailabilityInternalPrivate.h>
#endif

#ifndef __MAC_OS_X_VERSION_MIN_REQUIRED
    #ifdef __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__
        /* compiler for Mac OS X sets __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ */
        #define __MAC_OS_X_VERSION_MIN_REQUIRED __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__
    #endif
#endif /* __MAC_OS_X_VERSION_MIN_REQUIRED*/

#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
    #ifdef __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__
        /* compiler sets __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ when -miphoneos-version-min is used */
        #define __IPHONE_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__
    #endif
#endif /* __IPHONE_OS_VERSION_MIN_REQUIRED */

#ifndef __TV_OS_VERSION_MIN_REQUIRED
    #ifdef __ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__
        /* compiler sets __ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__ when -mtvos-version-min is used */
        #define __TV_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__
        #define __TV_OS_VERSION_MAX_ALLOWED __TVOS_13_0 
        /* for compatibility with existing code.  New code should use platform specific checks */
        #define __IPHONE_OS_VERSION_MIN_REQUIRED 90000
    #endif
#endif

#ifndef __WATCH_OS_VERSION_MIN_REQUIRED
    #ifdef __ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__
        /* compiler sets __ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__ when -mwatchos-version-min is used */
        #define __WATCH_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__
        #define __WATCH_OS_VERSION_MAX_ALLOWED 60000
        /* for compatibility with existing code.  New code should use platform specific checks */
        #define __IPHONE_OS_VERSION_MIN_REQUIRED 90000
    #endif
#endif

#ifndef __BRIDGE_OS_VERSION_MIN_REQUIRED
    #ifdef __ENVIRONMENT_BRIDGE_OS_VERSION_MIN_REQUIRED__
        
        #define __BRIDGE_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_BRIDGE_OS_VERSION_MIN_REQUIRED__
        #define __BRIDGE_OS_VERSION_MAX_ALLOWED 20000
        /* for compatibility with existing code.  New code should use platform specific checks */
        #define __IPHONE_OS_VERSION_MIN_REQUIRED 110000
    #endif
#endif

#ifndef __DRIVERKIT_VERSION_MIN_REQUIRED
    #ifdef __ENVIRONMENT_DRIVERKIT_VERSION_MIN_REQUIRED__
        #define __DRIVERKIT_VERSION_MIN_REQUIRED __ENVIRONMENT_DRIVERKIT_VERSION_MIN_REQUIRED__
    #endif
#endif

#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
    /* make sure a default max version is set */
    #ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
        #define __MAC_OS_X_VERSION_MAX_ALLOWED __MAC_10_15
    #endif
#endif /* __MAC_OS_X_VERSION_MIN_REQUIRED */

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    /* make sure a default max version is set */
    #ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
        #define __IPHONE_OS_VERSION_MAX_ALLOWED     __IPHONE_13_0
    #endif
    /* make sure a valid min is set */
    #if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_2_0
        #undef __IPHONE_OS_VERSION_MIN_REQUIRED
        #define __IPHONE_OS_VERSION_MIN_REQUIRED    __IPHONE_2_0
    #endif
#endif

#define __AVAILABILITY_INTERNAL_DEPRECATED            __attribute__((deprecated))
#ifdef __has_feature
    #if __has_feature(attribute_deprecated_with_message)
        #define __AVAILABILITY_INTERNAL_DEPRECATED_MSG(_msg)  __attribute__((deprecated(_msg)))
    #else
        #define __AVAILABILITY_INTERNAL_DEPRECATED_MSG(_msg)  __attribute__((deprecated))
    #endif
#elif defined(__GNUC__) && ((__GNUC__ >= 5) || ((__GNUC__ == 4) && (__GNUC_MINOR__ >= 5)))
    #define __AVAILABILITY_INTERNAL_DEPRECATED_MSG(_msg)  __attribute__((deprecated(_msg)))
#else
    #define __AVAILABILITY_INTERNAL_DEPRECATED_MSG(_msg)  __attribute__((deprecated))
#endif
#define __AVAILABILITY_INTERNAL_UNAVAILABLE           __attribute__((unavailable))
#define __AVAILABILITY_INTERNAL_WEAK_IMPORT           __attribute__((weak_import))
#define __AVAILABILITY_INTERNAL_REGULAR            

#if defined(__has_builtin)
 #if __has_builtin(__is_target_arch)
  #if __has_builtin(__is_target_vendor)
   #if __has_builtin(__is_target_os)
    #if __has_builtin(__is_target_environment)
     #if __has_builtin(__is_target_variant_os)
      #if __has_builtin(__is_target_variant_environment)
       #if (__is_target_arch(x86_64) && __is_target_vendor(apple) && ((__is_target_os(ios) && __is_target_environment(macabi)) || (__is_target_variant_os(ios) && __is_target_variant_environment(macabi))))
         #define __ENABLE_LEGACY_IPHONE_AVAILABILITY 1
         #define __ENABLE_LEGACY_MAC_AVAILABILITY 1
       #endif /* # if __is_target_arch... */
      #endif /* #if __has_builtin(__is_target_variant_environment) */
     #endif /* #if __has_builtin(__is_target_variant_os) */
    #endif /* #if __has_builtin(__is_target_environment) */
   #endif /* #if __has_builtin(__is_target_os) */
  #endif /* #if __has_builtin(__is_target_vendor) */
 #endif /* #if __has_builtin(__is_target_arch) */
#endif /* #if defined(__has_builtin) */

#ifndef __ENABLE_LEGACY_IPHONE_AVAILABILITY
 #ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
  #define __ENABLE_LEGACY_IPHONE_AVAILABILITY 1
 #elif defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
  #define __ENABLE_LEGACY_MAC_AVAILABILITY 1
 #endif
#endif /* __ENABLE_LEGACY_IPHONE_AVAILABILITY */

#ifdef __ENABLE_LEGACY_IPHONE_AVAILABILITY
    #if defined(__has_attribute) && defined(__has_feature)
        #if __has_attribute(availability)
            /* use better attributes if possible */
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0                    __attribute__((availability(ios,introduced=2.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=2.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=2.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=2.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=2.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_11_0   __attribute__((availability(ios,introduced=2.0,deprecated=11.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_0   __attribute__((availability(ios,introduced=2.0,deprecated=2.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=2.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=2.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_1   __attribute__((availability(ios,introduced=2.0,deprecated=2.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=2.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=2.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_2   __attribute__((availability(ios,introduced=2.0,deprecated=2.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=2.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=2.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_0   __attribute__((availability(ios,introduced=2.0,deprecated=3.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=3.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=3.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_1   __attribute__((availability(ios,introduced=2.0,deprecated=3.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=3.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=3.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_2   __attribute__((availability(ios,introduced=2.0,deprecated=3.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=3.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=3.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_0   __attribute__((availability(ios,introduced=2.0,deprecated=4.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=4.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=4.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_1   __attribute__((availability(ios,introduced=2.0,deprecated=4.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=4.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=4.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=2.0,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=2.0,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=2.0,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=2.0,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=2.0,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=2.0,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=2.0,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=2.0,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=2.0,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=2.0,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=2.0,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=2.0,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=2.0,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=2.0,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=2.0,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=2.0,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=2.0,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.0,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=2.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=2.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1                    __attribute__((availability(ios,introduced=2.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=2.1,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=2.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=2.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=2.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_2_1   __attribute__((availability(ios,introduced=2.1,deprecated=2.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_2_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=2.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_2_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=2.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_2_2   __attribute__((availability(ios,introduced=2.1,deprecated=2.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_2_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=2.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_2_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=2.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_0   __attribute__((availability(ios,introduced=2.1,deprecated=3.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=3.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=3.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_1   __attribute__((availability(ios,introduced=2.1,deprecated=3.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=3.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=3.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_2   __attribute__((availability(ios,introduced=2.1,deprecated=3.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=3.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=3.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_0   __attribute__((availability(ios,introduced=2.1,deprecated=4.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=4.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=4.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_1   __attribute__((availability(ios,introduced=2.1,deprecated=4.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=4.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=4.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=2.1,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=2.1,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=2.1,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=2.1,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=2.1,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=2.1,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=2.1,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=2.1,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=2.1,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=2.1,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=2.1,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=2.1,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=2.1,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=2.1,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=2.1,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=2.1,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=2.1,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.1,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=2.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=2.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2                    __attribute__((availability(ios,introduced=2.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=2.2,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=2.2,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=2.2,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=2.2,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_2_2   __attribute__((availability(ios,introduced=2.2,deprecated=2.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_2_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=2.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_2_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=2.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_0   __attribute__((availability(ios,introduced=2.2,deprecated=3.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=3.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=3.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_1   __attribute__((availability(ios,introduced=2.2,deprecated=3.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=3.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=3.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_2   __attribute__((availability(ios,introduced=2.2,deprecated=3.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=3.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=3.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_0   __attribute__((availability(ios,introduced=2.2,deprecated=4.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=4.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=4.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_1   __attribute__((availability(ios,introduced=2.2,deprecated=4.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=4.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=4.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=2.2,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=2.2,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=2.2,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=2.2,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=2.2,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=2.2,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=2.2,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=2.2,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=2.2,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=2.2,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=2.2,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=2.2,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=2.2,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=2.2,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=2.2,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=2.2,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=2.2,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=2.2,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=2.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_2_2_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=2.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0                    __attribute__((availability(ios,introduced=3.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=3.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=3.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=3.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=3.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_0   __attribute__((availability(ios,introduced=3.0,deprecated=3.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=3.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=3.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_1   __attribute__((availability(ios,introduced=3.0,deprecated=3.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=3.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=3.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_2   __attribute__((availability(ios,introduced=3.0,deprecated=3.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=3.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=3.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_0   __attribute__((availability(ios,introduced=3.0,deprecated=4.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=4.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=4.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_1   __attribute__((availability(ios,introduced=3.0,deprecated=4.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=4.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=4.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=3.0,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=3.0,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=3.0,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=3.0,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=3.0,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=3.0,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=3.0,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=3.0,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=3.0,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=3.0,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=3.0,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=3.0,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=3.0,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=3.0,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=3.0,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=3.0,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=3.0,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.0,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=3.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=3.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1                    __attribute__((availability(ios,introduced=3.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=3.1,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=3.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=3.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=3.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_3_1   __attribute__((availability(ios,introduced=3.1,deprecated=3.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=3.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_3_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=3.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_3_2   __attribute__((availability(ios,introduced=3.1,deprecated=3.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=3.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=3.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_0   __attribute__((availability(ios,introduced=3.1,deprecated=4.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=4.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=4.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_1   __attribute__((availability(ios,introduced=3.1,deprecated=4.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=4.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=4.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=3.1,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=3.1,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=3.1,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=3.1,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=3.1,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=3.1,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=3.1,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=3.1,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=3.1,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=3.1,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=3.1,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=3.1,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=3.1,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=3.1,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=3.1,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=3.1,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=3.1,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.1,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=3.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=3.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2                    __attribute__((availability(ios,introduced=3.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=3.2,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=3.2,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=3.2,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=3.2,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_3_2   __attribute__((availability(ios,introduced=3.2,deprecated=3.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=3.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_3_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=3.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_0   __attribute__((availability(ios,introduced=3.2,deprecated=4.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=4.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=4.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_1   __attribute__((availability(ios,introduced=3.2,deprecated=4.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=4.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=4.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=3.2,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=3.2,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=3.2,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=3.2,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=3.2,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=3.2,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=3.2,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=3.2,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=3.2,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=3.2,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=3.2,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=3.2,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=3.2,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=3.2,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=3.2,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=3.2,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=3.2,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=3.2,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=3.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_3_2_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=3.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0                    __attribute__((availability(ios,introduced=4.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=4.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=4.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=4.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=4.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_12_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=12.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_12_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=12.0)))
            #endif            
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_0   __attribute__((availability(ios,introduced=4.0,deprecated=4.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_1   __attribute__((availability(ios,introduced=4.0,deprecated=4.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=4.0,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=4.0,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=4.0,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=4.0,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=4.0,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=4.0,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=4.0,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=4.0,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=4.0,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=4.0,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=4.0,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=4.0,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=4.0,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=4.0,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=4.0,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=4.0,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=4.0,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=4.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=4.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1                    __attribute__((availability(ios,introduced=4.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=4.1,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=4.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=4.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=4.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_1   __attribute__((availability(ios,introduced=4.1,deprecated=4.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=4.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=4.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=4.1,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=4.1,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=4.1,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=4.1,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=4.1,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=4.1,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=4.1,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=4.1,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=4.1,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=4.1,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=4.1,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=4.1,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=4.1,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=4.1,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=4.1,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=4.1,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=4.1,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.1,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=4.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=4.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2                    __attribute__((availability(ios,introduced=4.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=4.2,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=4.2,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=4.2,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=4.2,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_4_2   __attribute__((availability(ios,introduced=4.2,deprecated=4.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=4.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_4_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=4.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=4.2,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=4.2,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=4.2,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=4.2,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=4.2,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=4.2,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=4.2,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=4.2,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=4.2,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=4.2,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=4.2,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=4.2,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=4.2,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=4.2,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=4.2,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=4.2,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.2,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=4.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_2_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=4.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3                    __attribute__((availability(ios,introduced=4.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=4.3,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=4.3,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=4.3,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=4.3,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_4_3   __attribute__((availability(ios,introduced=4.3,deprecated=4.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=4.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_4_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=4.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=4.3,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=4.3,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=4.3,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=4.3,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=4.3,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=4.3,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=4.3,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=4.3,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=4.3,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=4.3,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=4.3,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=4.3,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=4.3,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=4.3,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=4.3,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=4.3,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=4.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_4_3_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=4.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0                    __attribute__((availability(ios,introduced=5.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=5.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=5.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=5.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=5.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_11_0   __attribute__((availability(ios,introduced=5.0,deprecated=11.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_5_0   __attribute__((availability(ios,introduced=5.0,deprecated=5.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=5.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_5_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=5.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=5.0,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=5.0,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=5.0,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=5.0,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=5.0,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=5.0,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=5.0,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=5.0,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=5.0,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=5.0,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=5.0,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=5.0,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=5.0,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=5.0,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.0,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=5.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_5_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=5.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1                    __attribute__((availability(ios,introduced=5.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=5.1,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=5.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=5.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=5.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_5_1   __attribute__((availability(ios,introduced=5.1,deprecated=5.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=5.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_5_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=5.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=5.1,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=5.1,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=5.1,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=5.1,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=5.1,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=5.1,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=5.1,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=5.1,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=5.1,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=5.1,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=5.1,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=5.1,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=5.1,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=5.1,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=5.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_5_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=5.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0                    __attribute__((availability(ios,introduced=6.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=6.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=6.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=6.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=6.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_6_0   __attribute__((availability(ios,introduced=6.0,deprecated=6.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=6.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_6_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=6.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=6.0,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=6.0,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=6.0,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=6.0,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=6.0,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=6.0,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=6.0,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=6.0,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=6.0,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=6.0,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=6.0,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=6.0,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.0,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=6.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_6_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=6.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1                    __attribute__((availability(ios,introduced=6.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=6.1,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=6.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=6.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=6.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_6_1   __attribute__((availability(ios,introduced=6.1,deprecated=6.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=6.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_6_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=6.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=6.1,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=6.1,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=6.1,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=6.1,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=6.1,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=6.1,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=6.1,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=6.1,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=6.1,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=6.1,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=6.1,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=6.1,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=6.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_6_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=6.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0                    __attribute__((availability(ios,introduced=7.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=7.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=7.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=7.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=7.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_11_0   __attribute__((availability(ios,introduced=7.0,deprecated=11.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_11_3   __attribute__((availability(ios,introduced=7.0,deprecated=11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_12_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=12.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_12_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=12.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_7_0   __attribute__((availability(ios,introduced=7.0,deprecated=7.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=7.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_7_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=7.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=7.0,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=7.0,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=7.0,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=7.0,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=7.0,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=7.0,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=7.0,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=7.0,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=7.0,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=7.0,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.0,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=7.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_7_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=7.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1                    __attribute__((availability(ios,introduced=7.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=7.1,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=7.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=7.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=7.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_7_1   __attribute__((availability(ios,introduced=7.1,deprecated=7.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=7.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_7_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=7.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=7.1,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=7.1,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=7.1,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=7.1,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=7.1,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=7.1,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=7.1,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=7.1,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=7.1,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=7.1,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=7.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_7_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=7.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0                    __attribute__((availability(ios,introduced=8.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=8.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=8.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=8.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=8.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_11_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_11_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=11)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_11_3   __attribute__((availability(ios,introduced=8.0,deprecated=11.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_12_0   __attribute__((availability(ios,introduced=8.0,deprecated=12.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_0   __attribute__((availability(ios,introduced=8.0,deprecated=8.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=8.0,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=8.0,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=8.0,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=8.0,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=8.0,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=8.0,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=8.0,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=8.0,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.0,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=8.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=8.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1                    __attribute__((availability(ios,introduced=8.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=8.1,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=8.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=8.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=8.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_1   __attribute__((availability(ios,introduced=8.1,deprecated=8.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=8.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=8.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=8.1,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=8.1,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=8.1,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=8.1,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=8.1,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=8.1,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=8.1,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.1,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=8.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=8.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2                    __attribute__((availability(ios,introduced=8.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=8.2,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=8.2,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=8.2,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=8.2,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_2   __attribute__((availability(ios,introduced=8.2,deprecated=8.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=8.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=8.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=8.2,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=8.2,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=8.2,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=8.2,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=8.2,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=8.2,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.2,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=8.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_2_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=8.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3                    __attribute__((availability(ios,introduced=8.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=8.3,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=8.3,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=8.3,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=8.3,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_8_3   __attribute__((availability(ios,introduced=8.3,deprecated=8.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=8.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_8_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=8.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=8.3,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=8.3,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=8.3,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=8.3,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=8.3,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.3,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=8.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_3_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=8.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4                    __attribute__((availability(ios,introduced=8.4)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=8.4,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=8.4,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=8.4,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=8.4,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_8_4   __attribute__((availability(ios,introduced=8.4,deprecated=8.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=8.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_8_4_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=8.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=8.4,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=8.4,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=8.4,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=8.4,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=8.4,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=8.4)))
            #define __AVAILABILITY_INTERNAL__IPHONE_8_4_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=8.4)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0                    __attribute__((availability(ios,introduced=9.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=9.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=9.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=9.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=9.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_0   __attribute__((availability(ios,introduced=9.0,deprecated=9.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=9.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=9.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=9.0,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=9.0,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=9.0,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.0,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=9.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=9.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1                    __attribute__((availability(ios,introduced=9.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=9.1,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=9.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=9.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=9.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_1   __attribute__((availability(ios,introduced=9.1,deprecated=9.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=9.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=9.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=9.1,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=9.1,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.1,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=9.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=9.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2                    __attribute__((availability(ios,introduced=9.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=9.2,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=9.2,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=9.2,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=9.2,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_9_2   __attribute__((availability(ios,introduced=9.2,deprecated=9.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=9.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_9_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=9.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=9.2,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.2,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=9.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_2_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=9.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_3                    __attribute__((availability(ios,introduced=9.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=9.3,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=9.3,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=9.3,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=9.3,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_9_3   __attribute__((availability(ios,introduced=9.3,deprecated=9.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=9.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_9_3_MSG(_msg)   __attribute__((availability(ios,introduced=9.3,deprecated=9.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=9.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_9_3_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=9.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0                    __attribute__((availability(ios,introduced=10.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_0   __attribute__((availability(ios,introduced=10.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=10.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_0_MSG(_msg)   __attribute__((availability(ios,introduced=10.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=10.0,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=10.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=10.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=10.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=10.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=10.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=10.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=10.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=10.0,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_11_0   __attribute__((availability(ios,introduced=10.0,deprecated=11.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_12_0   __attribute__((availability(ios,introduced=10.0,deprecated=12.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=10.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_0_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=10.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_1                    __attribute__((availability(ios,introduced=10.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_1   __attribute__((availability(ios,introduced=10.1,deprecated=10.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=10.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_1_MSG(_msg)   __attribute__((availability(ios,introduced=10.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=10.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=10.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=10.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=10.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=10.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=10.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=10.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_1_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=10.1)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_2                    __attribute__((availability(ios,introduced=10.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_2_DEP__IPHONE_10_2   __attribute__((availability(ios,introduced=10.2,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=10.2,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_2_DEP__IPHONE_10_2_MSG(_msg)   __attribute__((availability(ios,introduced=10.2,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_2_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=10.2,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=10.2,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_2_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=10.2,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_2_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=10.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_2_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=10.2)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_3                    __attribute__((availability(ios,introduced=10.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_3_DEP__IPHONE_10_3   __attribute__((availability(ios,introduced=10.3,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_10_3_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=10.3,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__IPHONE_10_3_DEP__IPHONE_10_3_MSG(_msg)   __attribute__((availability(ios,introduced=10.3,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__IPHONE_10_3_DEP__IPHONE_NA   __attribute__((availability(ios,introduced=10.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_10_3_DEP__IPHONE_NA_MSG(_msg)   __attribute__((availability(ios,introduced=10.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_11                    __attribute__((availability(ios,introduced=11)))
            #define __AVAILABILITY_INTERNAL__IPHONE_11_0                    __attribute__((availability(ios,introduced=11.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_11_3                    __attribute__((availability(ios,introduced=11.3)))
            #define __AVAILABILITY_INTERNAL__IPHONE_12_0                    __attribute__((availability(ios,introduced=12.0)))
            #define __AVAILABILITY_INTERNAL__IPHONE_13_0                    __attribute__((availability(ios,introduced=13.0)))

            #define __AVAILABILITY_INTERNAL__IPHONE_NA                      __attribute__((availability(ios,unavailable)))
            #define __AVAILABILITY_INTERNAL__IPHONE_NA__IPHONE_NA           __attribute__((availability(ios,unavailable)))
            #define __AVAILABILITY_INTERNAL__IPHONE_NA_DEP__IPHONE_NA       __attribute__((availability(ios,unavailable)))
            #define __AVAILABILITY_INTERNAL__IPHONE_NA_DEP__IPHONE_NA_MSG(_msg) __attribute__((availability(ios,unavailable)))

            #if __has_builtin(__is_target_arch)
             #if __has_builtin(__is_target_vendor)
              #if __has_builtin(__is_target_os)
               #if __has_builtin(__is_target_environment)
                #if __has_builtin(__is_target_variant_os)
                 #if __has_builtin(__is_target_variant_environment)
                  #if (__is_target_arch(x86_64) && __is_target_vendor(apple) && __is_target_os(ios) && __is_target_environment(macabi))
                    #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION __attribute__((availability(ios,introduced=4.0)))
                    #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION_DEP__IPHONE_COMPAT_VERSION               __attribute__((availability(ios,unavailable)))
                    #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION_DEP__IPHONE_COMPAT_VERSION_MSG(_msg)     __attribute__((availability(ios,unavailable)))
                  #endif
                 #endif /* #if __has_builtin(__is_target_variant_environment) */
                #endif /* #if __has_builtin(__is_target_variant_os) */
               #endif /* #if __has_builtin(__is_target_environment) */
              #endif /* #if __has_builtin(__is_target_os) */
             #endif /* #if __has_builtin(__is_target_vendor) */
            #endif /* #if __has_builtin(__is_target_arch) */

            #ifndef __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION
                #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION __attribute__((availability(ios,introduced=4.0)))
                #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION_DEP__IPHONE_COMPAT_VERSION   __attribute__((availability(ios,introduced=4.0,deprecated=4.0)))
                #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION_DEP__IPHONE_COMPAT_VERSION_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.0,message=_msg)))
                #else
                #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION_DEP__IPHONE_COMPAT_VERSION_MSG(_msg)   __attribute__((availability(ios,introduced=4.0,deprecated=4.0)))
                #endif
            #endif /* __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION */
        #endif
    #endif
#endif

#if __ENABLE_LEGACY_MAC_AVAILABILITY
    #if defined(__has_attribute) && defined(__has_feature)
        #if __has_attribute(availability)
            /* use better attributes if possible */
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.1,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.12)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_2   __attribute__((availability(macosx,introduced=10.1,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_3   __attribute__((availability(macosx,introduced=10.1,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_4   __attribute__((availability(macosx,introduced=10.1,deprecated=10.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_5   __attribute__((availability(macosx,introduced=10.1,deprecated=10.5)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.5,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.5)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_6   __attribute__((availability(macosx,introduced=10.1,deprecated=10.6)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.6,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.6)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_7   __attribute__((availability(macosx,introduced=10.1,deprecated=10.7)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.7,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.7)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.1,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.1,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_1_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_2                    __attribute__((availability(macosx,introduced=10.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.2,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.2,deprecated=10.13)))
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_2   __attribute__((availability(macosx,introduced=10.2,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_3   __attribute__((availability(macosx,introduced=10.2,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_4   __attribute__((availability(macosx,introduced=10.2,deprecated=10.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_5   __attribute__((availability(macosx,introduced=10.2,deprecated=10.5)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.5,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.5)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_6   __attribute__((availability(macosx,introduced=10.2,deprecated=10.6)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.6,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.6)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_7   __attribute__((availability(macosx,introduced=10.2,deprecated=10.7)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.7,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.7)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.2,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.2,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_3                    __attribute__((availability(macosx,introduced=10.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.3,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.3,deprecated=10.13)))
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_3   __attribute__((availability(macosx,introduced=10.3,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_4   __attribute__((availability(macosx,introduced=10.3,deprecated=10.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_5   __attribute__((availability(macosx,introduced=10.3,deprecated=10.5)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.5,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.5)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_6   __attribute__((availability(macosx,introduced=10.3,deprecated=10.6)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.6,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.6)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_7   __attribute__((availability(macosx,introduced=10.3,deprecated=10.7)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.7,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.7)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.3,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.3,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_4                    __attribute__((availability(macosx,introduced=10.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.4,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.4,deprecated=10.13)))
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_4   __attribute__((availability(macosx,introduced=10.4,deprecated=10.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_5   __attribute__((availability(macosx,introduced=10.4,deprecated=10.5)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.5,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.5)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_6   __attribute__((availability(macosx,introduced=10.4,deprecated=10.6)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.6,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.6)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_7   __attribute__((availability(macosx,introduced=10.4,deprecated=10.7)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.7,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.7)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.4,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.4,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_5                    __attribute__((availability(macosx,introduced=10.5)))
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEPRECATED__MAC_10_7                    __attribute__((availability(macosx,introduced=10.5.DEPRECATED..MAC.10.7)))
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.5,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_5   __attribute__((availability(macosx,introduced=10.5,deprecated=10.5)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.5,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.5)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_6   __attribute__((availability(macosx,introduced=10.5,deprecated=10.6)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.6,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.6)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_7   __attribute__((availability(macosx,introduced=10.5,deprecated=10.7)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.7,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.7)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.5,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.5,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.5)))
            #define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.5)))
            #define __AVAILABILITY_INTERNAL__MAC_10_6                    __attribute__((availability(macosx,introduced=10.6)))
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.6,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.6,deprecated=10.13)))
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_6   __attribute__((availability(macosx,introduced=10.6,deprecated=10.6)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.6,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.6)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_7   __attribute__((availability(macosx,introduced=10.6,deprecated=10.7)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.7,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.7)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.6,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.6,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.6)))
            #define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.6)))
            #define __AVAILABILITY_INTERNAL__MAC_10_7                    __attribute__((availability(macosx,introduced=10.7)))
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.7,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_13_2   __attribute__((availability(macosx,introduced=10.7,deprecated=10.13.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_7   __attribute__((availability(macosx,introduced=10.7,deprecated=10.7)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.7,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.7)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.7,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.7,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.7)))
            #define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.7)))
            #define __AVAILABILITY_INTERNAL__MAC_10_8                    __attribute__((availability(macosx,introduced=10.8)))
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.8,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.8,deprecated=10.13)))
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.8,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.8,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.8)))
            #define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.8)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9                    __attribute__((availability(macosx,introduced=10.9)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.9,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.9,deprecated=10.13)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_14   __attribute__((availability(macosx,introduced=10.9,deprecated=10.14)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.9,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9,deprecated=10.9)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.9)))
            #define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.9)))
            #define __AVAILABILITY_INTERNAL__MAC_10_0                    __attribute__((availability(macosx,introduced=10.0)))
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_0   __attribute__((availability(macosx,introduced=10.0,deprecated=10.0)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_0_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.0,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_0_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.0)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.0,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.0,deprecated=10.13)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_2   __attribute__((availability(macosx,introduced=10.0,deprecated=10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_3   __attribute__((availability(macosx,introduced=10.0,deprecated=10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_4   __attribute__((availability(macosx,introduced=10.0,deprecated=10.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_5   __attribute__((availability(macosx,introduced=10.0,deprecated=10.5)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.5,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_5_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.5)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_6   __attribute__((availability(macosx,introduced=10.0,deprecated=10.6)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.6,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_6_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.6)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_7   __attribute__((availability(macosx,introduced=10.0,deprecated=10.7)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.7,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_7_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.7)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_8   __attribute__((availability(macosx,introduced=10.0,deprecated=10.8)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.8,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_8_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.8)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_9   __attribute__((availability(macosx,introduced=10.0,deprecated=10.9)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.9,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_9_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.9)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_13_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.13,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_10_13_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0,deprecated=10.13)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.0)))
            #define __AVAILABILITY_INTERNAL__MAC_10_0_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.0)))
            #define __AVAILABILITY_INTERNAL__MAC_10_1                    __attribute__((availability(macosx,introduced=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10                    __attribute__((availability(macosx,introduced=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2                    __attribute__((availability(macosx,introduced=10.10.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.10.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_2_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3                    __attribute__((availability(macosx,introduced=10.10.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.10.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.10.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_3_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.10,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10_2   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10_3   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10.3)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_10_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.10)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.10,deprecated=10.13)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_13_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.13,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_13_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10,deprecated=10.13)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_13_4   __attribute__((availability(macosx,introduced=10.10,deprecated=10.13.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.10)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11                    __attribute__((availability(macosx,introduced=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2                    __attribute__((availability(macosx,introduced=10.11.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.11.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.11.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_2_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3                    __attribute__((availability(macosx,introduced=10.11.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.11.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.11.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_3_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.3)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_4                    __attribute__((availability(macosx,introduced=10.11.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.11.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.11.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_4_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_1   __attribute__((availability(macosx,introduced=10.11,deprecated=10.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_2   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_3   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.3)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.3,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_3_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.3)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_4   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.11)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.11)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12                    __attribute__((availability(macosx,introduced=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_1                    __attribute__((availability(macosx,introduced=10.12.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.1,deprecated=10.12.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.12.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_1_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.1)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_2                    __attribute__((availability(macosx,introduced=10.12.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_2_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.12.2,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_2_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.2,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_2_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.2,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_2_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.12.2,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_2_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.2,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_2_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.2,deprecated=10.12.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_2_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.12.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_2_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.2)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_4                    __attribute__((availability(macosx,introduced=10.12.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_4_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.12.4,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_4_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.4,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_4_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.4,deprecated=10.12.4)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_4_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.12.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_4_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_1   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.1)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.1,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_1_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.1)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_2   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.2)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.2,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_2_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.2)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_4   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.4)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.4,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_4_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12.4)))
            #endif
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_12_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.12)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_13   __attribute__((availability(macosx,introduced=10.12,deprecated=10.13)))
            #if __has_feature(attribute_availability_with_message)
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_13_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.13,message=_msg)))
            #else
                #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_13_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12,deprecated=10.13)))
            #endif
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_13_4   __attribute__((availability(macosx,introduced=10.12,deprecated=10.13.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_10_14   __attribute__((availability(macosx,introduced=10.12,deprecated=10.14)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_NA   __attribute__((availability(macosx,introduced=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_12_DEP__MAC_NA_MSG(_msg)   __attribute__((availability(macosx,introduced=10.12)))
            #define __AVAILABILITY_INTERNAL__MAC_10_13                    __attribute__((availability(macosx,introduced=10.13)))
            #define __AVAILABILITY_INTERNAL__MAC_10_13_4                    __attribute__((availability(macosx,introduced=10.13.4)))
            #define __AVAILABILITY_INTERNAL__MAC_10_14                    __attribute__((availability(macosx,introduced=10.14)))
            #define __AVAILABILITY_INTERNAL__MAC_10_14_DEP__MAC_10_14   __attribute__((availability(macosx,introduced=10.14,deprecated=10.14)))
            #define __AVAILABILITY_INTERNAL__MAC_10_15                    __attribute__((availability(macosx,introduced=10.15)))

            #define __AVAILABILITY_INTERNAL__MAC_NA                        __attribute__((availability(macosx,unavailable)))
            #define __AVAILABILITY_INTERNAL__MAC_NA_DEP__MAC_NA            __attribute__((availability(macosx,unavailable)))
            #define __AVAILABILITY_INTERNAL__MAC_NA_DEP__MAC_NA_MSG(_msg)  __attribute__((availability(macosx,unavailable)))

            #define __AVAILABILITY_INTERNAL__IPHONE_NA                      __attribute__((availability(ios,unavailable)))
            #define __AVAILABILITY_INTERNAL__IPHONE_NA__IPHONE_NA           __attribute__((availability(ios,unavailable)))
            #define __AVAILABILITY_INTERNAL__IPHONE_NA_DEP__IPHONE_NA       __attribute__((availability(ios,unavailable)))
            #define __AVAILABILITY_INTERNAL__IPHONE_NA_DEP__IPHONE_NA_MSG(_msg) __attribute__((availability(ios,unavailable)))

            #ifndef __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION
             #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION                                          __attribute__((availability(ios,unavailable)))
             #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION_DEP__IPHONE_COMPAT_VERSION               __attribute__((availability(ios,unavailable)))
             #define __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION_DEP__IPHONE_COMPAT_VERSION_MSG(_msg)     __attribute__((availability(ios,unavailable)))
            #endif /* __AVAILABILITY_INTERNAL__IPHONE_COMPAT_VERSION */
        #endif
    #endif
#endif /* __ENABLE_LEGACY_MAC_AVAILABILITY */

/*
 Macros for defining which versions/platform a given symbol can be used.
 
 @see http://clang.llvm.org/docs/AttributeReference.html#availability
 */

#if defined(__has_feature) && defined(__has_attribute)
 #if __has_attribute(availability)

    
    #define __API_AVAILABLE_PLATFORM_macos(x) macos,introduced=x
    #define __API_AVAILABLE_PLATFORM_macosx(x) macosx,introduced=x
    #define __API_AVAILABLE_PLATFORM_ios(x) ios,introduced=x
    #define __API_AVAILABLE_PLATFORM_watchos(x) watchos,introduced=x
    #define __API_AVAILABLE_PLATFORM_tvos(x) tvos,introduced=x
    
    #define __API_AVAILABLE_PLATFORM_macCatalyst(x) macCatalyst,introduced=x
    #define __API_AVAILABLE_PLATFORM_macCatalyst(x) macCatalyst,introduced=x
    #ifndef __API_AVAILABLE_PLATFORM_uikitformac
     #define __API_AVAILABLE_PLATFORM_uikitformac(x) uikitformac,introduced=x
    #endif
    #define __API_AVAILABLE_PLATFORM_driverkit(x) driverkit,introduced=x

    #if defined(__has_attribute)
      #if __has_attribute(availability)
        #define __API_A(x) __attribute__((availability(__API_AVAILABLE_PLATFORM_##x)))
      #else
        #define __API_A(x)
      #endif
    #else
        #define __API_A(x)
    #endif
    
    #define __API_AVAILABLE1(x) __API_A(x)
    #define __API_AVAILABLE2(x,y) __API_A(x) __API_A(y)
    #define __API_AVAILABLE3(x,y,z)  __API_A(x) __API_A(y) __API_A(z)
    #define __API_AVAILABLE4(x,y,z,t) __API_A(x) __API_A(y) __API_A(z) __API_A(t)
    #define __API_AVAILABLE5(x,y,z,t,b) __API_A(x) __API_A(y) __API_A(z) __API_A(t) __API_A(b)
    #define __API_AVAILABLE6(x,y,z,t,b,m) __API_A(x) __API_A(y) __API_A(z) __API_A(t) __API_A(b) __API_A(m)
    #define __API_AVAILABLE7(x,y,z,t,b,m,d) __API_A(x) __API_A(y) __API_A(z) __API_A(t) __API_A(b) __API_A(m) __API_A(d)
    #define __API_AVAILABLE_GET_MACRO(_1,_2,_3,_4,_5,_6,_7,NAME,...) NAME

    #define __API_APPLY_TO any(record, enum, enum_constant, function, objc_method, objc_category, objc_protocol, objc_interface, objc_property, type_alias, variable, field)
    #define __API_RANGE_STRINGIFY(x) __API_RANGE_STRINGIFY2(x)
    #define __API_RANGE_STRINGIFY2(x) #x 
    
    #define __API_A_BEGIN(x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_AVAILABLE_PLATFORM_##x))), apply_to = __API_APPLY_TO)))

    #define __API_AVAILABLE_BEGIN1(a) __API_A_BEGIN(a)
    #define __API_AVAILABLE_BEGIN2(a,b) __API_A_BEGIN(a) __API_A_BEGIN(b)
    #define __API_AVAILABLE_BEGIN3(a,b,c) __API_A_BEGIN(a) __API_A_BEGIN(b) __API_A_BEGIN(c)
    #define __API_AVAILABLE_BEGIN4(a,b,c,d) __API_A_BEGIN(a) __API_A_BEGIN(b) __API_A_BEGIN(c) __API_A_BEGIN(d)
    #define __API_AVAILABLE_BEGIN5(a,b,c,d,e) __API_A_BEGIN(a) __API_A_BEGIN(b) __API_A_BEGIN(c) __API_A_BEGIN(d) __API_A_BEGIN(e)
    #define __API_AVAILABLE_BEGIN6(a,b,c,d,e,f) __API_A_BEGIN(a) __API_A_BEGIN(b) __API_A_BEGIN(c) __API_A_BEGIN(d) __API_A_BEGIN(e) __API_A_BEGIN(f)
    #define __API_AVAILABLE_BEGIN7(a,b,c,d,e,f,g) __API_A_BEGIN(a) __API_A_BEGIN(b) __API_A_BEGIN(c) __API_A_BEGIN(d) __API_A_BEGIN(e) __API_A_BEGIN(f) __API_A_BEGIN(g)
    #define __API_AVAILABLE_BEGIN_GET_MACRO(_1,_2,_3,_4,_5,_6,_7,NAME,...) NAME

    
    #define __API_DEPRECATED_PLATFORM_macos(x,y) macos,introduced=x,deprecated=y
    #define __API_DEPRECATED_PLATFORM_macosx(x,y) macosx,introduced=x,deprecated=y
    #define __API_DEPRECATED_PLATFORM_ios(x,y) ios,introduced=x,deprecated=y
    #define __API_DEPRECATED_PLATFORM_watchos(x,y) watchos,introduced=x,deprecated=y
    #define __API_DEPRECATED_PLATFORM_tvos(x,y) tvos,introduced=x,deprecated=y
    
    #define __API_DEPRECATED_PLATFORM_macCatalyst(x,y) macCatalyst,introduced=x,deprecated=y
    #define __API_DEPRECATED_PLATFORM_macCatalyst(x,y) macCatalyst,introduced=x,deprecated=y
    #ifndef __API_DEPRECATED_PLATFORM_uikitformac
     #define __API_DEPRECATED_PLATFORM_uikitformac(x) uikitformac,introduced=x,deprecated=y
    #endif
    #define __API_DEPRECATED_PLATFORM_driverkit(x,y) driverkit,introduced=x,deprecated=y

    #if defined(__has_attribute)
      #if __has_attribute(availability)
        #define __API_D(msg,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x,message=msg)))
      #else
        #define __API_D(msg,x)
      #endif
    #else
        #define __API_D(msg,x)
    #endif
    
    #define __API_DEPRECATED_MSG2(msg,x) __API_D(msg,x)
    #define __API_DEPRECATED_MSG3(msg,x,y) __API_D(msg,x) __API_D(msg,y)
    #define __API_DEPRECATED_MSG4(msg,x,y,z) __API_DEPRECATED_MSG3(msg,x,y) __API_D(msg,z)
    #define __API_DEPRECATED_MSG5(msg,x,y,z,t) __API_DEPRECATED_MSG4(msg,x,y,z) __API_D(msg,t)
    #define __API_DEPRECATED_MSG6(msg,x,y,z,t,b) __API_DEPRECATED_MSG5(msg,x,y,z,t) __API_D(msg,b)
    #define __API_DEPRECATED_MSG7(msg,x,y,z,t,b,m) __API_DEPRECATED_MSG6(msg,x,y,z,t,b) __API_D(msg,m)
    #define __API_DEPRECATED_MSG8(msg,x,y,z,t,b,m,d) __API_DEPRECATED_MSG7(msg,x,y,z,t,b,m) __API_D(msg,d)
    #define __API_DEPRECATED_MSG_GET_MACRO(_1,_2,_3,_4,_5,_6,_7,_8,NAME,...) NAME

    #define __API_D_BEGIN(msg, x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x,message=msg))), apply_to = __API_APPLY_TO)))

    #define __API_DEPRECATED_BEGIN_MSG2(msg,a) __API_D_BEGIN(msg,a)
    #define __API_DEPRECATED_BEGIN_MSG3(msg,a,b) __API_D_BEGIN(msg,a) __API_D_BEGIN(msg,b)
    #define __API_DEPRECATED_BEGIN_MSG4(msg,a,b,c) __API_D_BEGIN(msg,a) __API_D_BEGIN(msg,b) __API_D_BEGIN(msg,c)
    #define __API_DEPRECATED_BEGIN_MSG5(msg,a,b,c,d) __API_D_BEGIN(msg,a) __API_D_BEGIN(msg,b) __API_D_BEGIN(msg,c) __API_D_BEGIN(msg,d)
    #define __API_DEPRECATED_BEGIN_MSG6(msg,a,b,c,d,e) __API_D_BEGIN(msg,a) __API_D_BEGIN(msg,b) __API_D_BEGIN(msg,c) __API_D_BEGIN(msg,d) __API_D_BEGIN(msg,e)
    #define __API_DEPRECATED_BEGIN_MSG7(msg,a,b,c,d,e,f) __API_D_BEGIN(msg,a) __API_D_BEGIN(msg,b) __API_D_BEGIN(msg,c) __API_D_BEGIN(msg,d) __API_D_BEGIN(msg,e) __API_D_BEGIN(msg,f)
    #define __API_DEPRECATED_BEGIN_MSG8(msg,a,b,c,d,e,f,g) __API_D_BEGIN(msg,a) __API_D_BEGIN(msg,b) __API_D_BEGIN(msg,c) __API_D_BEGIN(msg,d) __API_D_BEGIN(msg,e) __API_D_BEGIN(msg,f) __API_D_BEGIN(msg,g)
    #define __API_DEPRECATED_BEGIN_MSG_GET_MACRO(_1,_2,_3,_4,_5,_6,_7,_8,NAME,...) NAME

    #if __has_feature(attribute_availability_with_replacement)
        #define __API_R(rep,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x,replacement=rep)))
    #else
        #define __API_R(rep,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x)))
    #endif

    #define __API_DEPRECATED_REP2(rep,x) __API_R(rep,x)
    #define __API_DEPRECATED_REP3(rep,x,y) __API_R(rep,x) __API_R(rep,y)
    #define __API_DEPRECATED_REP4(rep,x,y,z)  __API_DEPRECATED_REP3(rep,x,y) __API_R(rep,z)
    #define __API_DEPRECATED_REP5(rep,x,y,z,t) __API_DEPRECATED_REP4(rep,x,y,z) __API_R(rep,t)
    #define __API_DEPRECATED_REP6(rep,x,y,z,t,b) __API_DEPRECATED_REP5(rep,x,y,z,t) __API_R(rep,b)
    #define __API_DEPRECATED_REP7(rep,x,y,z,t,b,m) __API_DEPRECATED_REP6(rep,x,y,z,t,b) __API_R(rep,m)
    #define __API_DEPRECATED_REP8(rep,x,y,z,t,b,m,d) __API_DEPRECATED_REP7(rep,x,y,z,t,b,m) __API_R(rep,d)
    #define __API_DEPRECATED_REP_GET_MACRO(_1,_2,_3,_4,_5,_6,_7,_8,NAME,...) NAME

    #if __has_feature(attribute_availability_with_replacement)
        #define __API_R_BEGIN(rep,x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x,replacement=rep))), apply_to = __API_APPLY_TO)))    
    #else
        #define __API_R_BEGIN(rep,x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x))), apply_to = __API_APPLY_TO)))    
    #endif

    #define __API_DEPRECATED_BEGIN_REP2(rep,a) __API_R_BEGIN(rep,a)
    #define __API_DEPRECATED_BEGIN_REP3(rep,a,b) __API_R_BEGIN(rep,a) __API_R_BEGIN(rep,b)
    #define __API_DEPRECATED_BEGIN_REP4(rep,a,b,c) __API_R_BEGIN(rep,a) __API_R_BEGIN(rep,b) __API_R_BEGIN(rep,c)
    #define __API_DEPRECATED_BEGIN_REP5(rep,a,b,c,d) __API_R_BEGIN(rep,a) __API_R_BEGIN(rep,b) __API_R_BEGIN(rep,c) __API_R_BEGIN(rep,d)
    #define __API_DEPRECATED_BEGIN_REP6(rep,a,b,c,d,e) __API_R_BEGIN(rep,a) __API_R_BEGIN(rep,b) __API_R_BEGIN(rep,c) __API_R_BEGIN(rep,d) __API_R_BEGIN(rep,e)
    #define __API_DEPRECATED_BEGIN_REP7(rep,a,b,c,d,e,f) __API_R_BEGIN(rep,a) __API_R_BEGIN(rep,b) __API_R_BEGIN(rep,c) __API_R_BEGIN(rep,d) __API_R_BEGIN(rep,e) __API_R_BEGIN(rep,f)
    #define __API_DEPRECATED_BEGIN_REP8(rep,a,b,c,d,e,f,g) __API_R_BEGIN(rep,a) __API_R_BEGIN(rep,b) __API_R_BEGIN(rep,c) __API_R_BEGIN(rep,d) __API_R_BEGIN(rep,e) __API_R_BEGIN(rep,f) __API_R_BEGIN(rep,g)
    #define __API_DEPRECATED_BEGIN_REP_GET_MACRO(_1,_2,_3,_4,_5,_6,_7,_8,NAME,...) NAME

    /*
     * API Unavailability
     * Use to specify that an API is unavailable for a particular platform.
     *
     * Example:
     *    __API_UNAVAILABLE(macos)
     *    __API_UNAVAILABLE(watchos, tvos)
     */
    #define __API_UNAVAILABLE_PLATFORM_macos macos,unavailable
    #define __API_UNAVAILABLE_PLATFORM_macosx macosx,unavailable
    #define __API_UNAVAILABLE_PLATFORM_ios ios,unavailable
    #define __API_UNAVAILABLE_PLATFORM_watchos watchos,unavailable
    #define __API_UNAVAILABLE_PLATFORM_tvos tvos,unavailable
    
    #define __API_UNAVAILABLE_PLATFORM_macCatalyst macCatalyst,unavailable
    #define __API_UNAVAILABLE_PLATFORM_macCatalyst macCatalyst,unavailable
    #ifndef __API_UNAVAILABLE_PLATFORM_uikitformac
     #define __API_UNAVAILABLE_PLATFORM_uikitformac(x) uikitformac,unavailable
    #endif
    #define __API_UNAVAILABLE_PLATFORM_driverkit driverkit,unavailable

    #if defined(__has_attribute)
      #if __has_attribute(availability)
        #define __API_U(x) __attribute__((availability(__API_UNAVAILABLE_PLATFORM_##x)))
      #else
        #define __API_U(x)
      #endif
    #else
        #define __API_U(x)
    #endif
    
    #define __API_UNAVAILABLE1(x) __API_U(x)
    #define __API_UNAVAILABLE2(x,y) __API_U(x) __API_U(y)
    #define __API_UNAVAILABLE3(x,y,z) __API_UNAVAILABLE2(x,y) __API_U(z)
    #define __API_UNAVAILABLE4(x,y,z,t) __API_UNAVAILABLE3(x,y,z) __API_U(t)
    #define __API_UNAVAILABLE5(x,y,z,t,b) __API_UNAVAILABLE4(x,y,z,t) __API_U(b)
    #define __API_UNAVAILABLE6(x,y,z,t,b,m) __API_UNAVAILABLE5(x,y,z,t,b) __API_U(m)
    #define __API_UNAVAILABLE7(x,y,z,t,b,m,d) __API_UNAVAILABLE6(x,y,z,t,b,m) __API_U(d)
    #define __API_UNAVAILABLE_GET_MACRO(_1,_2,_3,_4,_5,_6,_7,NAME,...) NAME

    #define __API_U_BEGIN(x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_UNAVAILABLE_PLATFORM_##x))), apply_to = __API_APPLY_TO)))

    #define __API_UNAVAILABLE_BEGIN1(a) __API_U_BEGIN(a)
    #define __API_UNAVAILABLE_BEGIN2(a,b) __API_U_BEGIN(a) __API_U_BEGIN(b)
    #define __API_UNAVAILABLE_BEGIN3(a,b,c) __API_U_BEGIN(a) __API_U_BEGIN(b) __API_U_BEGIN(c)
    #define __API_UNAVAILABLE_BEGIN4(a,b,c,d) __API_U_BEGIN(a) __API_U_BEGIN(b) __API_U_BEGIN(c) __API_U_BEGIN(d)
    #define __API_UNAVAILABLE_BEGIN5(a,b,c,d,e) __API_U_BEGIN(a) __API_U_BEGIN(b) __API_U_BEGIN(c) __API_U_BEGIN(d) __API_U_BEGIN(e)
    #define __API_UNAVAILABLE_BEGIN6(a,b,c,d,e,f) __API_U_BEGIN(a) __API_U_BEGIN(b) __API_U_BEGIN(c) __API_U_BEGIN(d) __API_U_BEGIN(e) __API_U_BEGIN(f)
    #define __API_UNAVAILABLE_BEGIN7(a,b,c,d,e,f) __API_U_BEGIN(a) __API_U_BEGIN(b) __API_U_BEGIN(c) __API_U_BEGIN(d) __API_U_BEGIN(e) __API_U_BEGIN(f) __API_U_BEGIN(g)
    #define __API_UNAVAILABLE_BEGIN_GET_MACRO(_1,_2,_3,_4,_5,_6,_7,NAME,...) NAME
 #else 

 /* 
  * Evaluate to nothing for compilers that don't support availability.
  */
    
  #define __API_AVAILABLE_GET_MACRO(...)
  #define __API_AVAILABLE_BEGIN_GET_MACRO(...)
  #define __API_DEPRECATED_MSG_GET_MACRO(...)
  #define __API_DEPRECATED_REP_GET_MACRO(...)
  #define __API_DEPRECATED_BEGIN_MSG_GET_MACRO(...)
  #define __API_DEPRECATED_BEGIN_REP_GET_MACRO
  #define __API_UNAVAILABLE_GET_MACRO(...)
  #define __API_UNAVAILABLE_BEGIN_GET_MACRO(...)
 #endif /* __has_attribute(availability) */
#else

    /* 
     * Evaluate to nothing for compilers that don't support clang language extensions.
     */
    
    #define __API_AVAILABLE_GET_MACRO(...)
    #define __API_AVAILABLE_BEGIN_GET_MACRO(...)
    #define __API_DEPRECATED_MSG_GET_MACRO(...)
    #define __API_DEPRECATED_REP_GET_MACRO(...)
    #define __API_DEPRECATED_BEGIN_MSG_GET_MACRO(...)
    #define __API_DEPRECATED_BEGIN_REP_GET_MACRO
    #define __API_UNAVAILABLE_GET_MACRO(...)
    #define __API_UNAVAILABLE_BEGIN_GET_MACRO(...)
#endif /* #if defined(__has_feature) && defined(__has_attribute) */

/*
 * Swift compiler version
 * Allows for project-agnostic “epochs” for frameworks imported into Swift via the Clang importer, like #if _compiler_version for Swift
 * Example:
 *
 *  #if __swift_compiler_version_at_least(800, 2, 20)
 *  - (nonnull NSString *)description;
 *  #else
 *  - (NSString *)description;
 *  #endif
 */
 
#ifdef __SWIFT_COMPILER_VERSION
    #define __swift_compiler_version_at_least_impl(X, Y, Z, a, b, ...) \
    __SWIFT_COMPILER_VERSION >= ((X * UINT64_C(1000) * 1000 * 1000) + (Z * 1000 * 1000) + (a * 1000) + b)
    #define __swift_compiler_version_at_least(...) __swift_compiler_version_at_least_impl(__VA_ARGS__, 0, 0, 0, 0)
#else
    #define __swift_compiler_version_at_least(...) 1
#endif

/*
 * If __SPI_AVAILABLE has not been defined elsewhere, disable it.
 */
 
#ifndef __SPI_AVAILABLE
  #define __SPI_AVAILABLE(...)
#endif

#endif /* __AVAILABILITY_INTERNAL__ */