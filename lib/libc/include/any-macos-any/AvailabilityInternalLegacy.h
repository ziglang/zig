/*
 * Copyright (c) 2007-2022 by Apple Inc.. All rights reserved.
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
    File:       AvailabilityInternalLegacy.h
 
    Contains:   implementation details of __OSX_AVAILABLE_* macros from <Availability.h>

*/

#ifndef __AVAILABILITY_INTERNAL_LEGACY__
#define __AVAILABILITY_INTERNAL_LEGACY__

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
                  #if ((__is_target_arch(x86_64) || __is_target_arch(arm64) || __is_target_arch(arm64e)) && __is_target_vendor(apple) && __is_target_os(ios) && __is_target_environment(macabi))
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

#endif /* __AVAILABILITY_INTERNAL_LEAGCY__ */
