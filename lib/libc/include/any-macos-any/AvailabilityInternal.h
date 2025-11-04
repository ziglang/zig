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

#include <AvailabilityVersions.h>

#ifndef __MAC_OS_X_VERSION_MIN_REQUIRED
    #if defined(__has_builtin)
        #if __has_builtin(__is_target_os)
            #if __is_target_os(macos)
                #define __MAC_OS_X_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
                #define __MAC_OS_X_VERSION_MAX_ALLOWED __MAC_26_1
            #endif
        #elif  __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ 
            #define __MAC_OS_X_VERSION_MIN_REQUIRED __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__
            #define __MAC_OS_X_VERSION_MAX_ALLOWED __MAC_26_1
        #endif /* __has_builtin(__is_target_os) */
    #endif /* defined(__has_builtin) */
#endif /* __MAC_OS_X_VERSION_MIN_REQUIRED */

#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin)
        #if __has_builtin(__is_target_os)
            #if __is_target_os(ios)
                #define __IPHONE_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
                #define __IPHONE_OS_VERSION_MAX_ALLOWED __IPHONE_26_1
            #endif
        #elif  __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ 
            #define __IPHONE_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__
            #define __IPHONE_OS_VERSION_MAX_ALLOWED __IPHONE_26_1
        #endif /* __has_builtin(__is_target_os) */
    #endif /* defined(__has_builtin) */
#endif /* __IPHONE_OS_VERSION_MIN_REQUIRED */

#ifndef __WATCH_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin)
        #if __has_builtin(__is_target_os)
            #if __is_target_os(watchos)
                #define __WATCH_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
                #define __WATCH_OS_VERSION_MAX_ALLOWED __WATCHOS_26_1
                /* for compatibility with existing code.  New code should use platform specific checks */
                #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_9_0
            #endif
        #elif  __ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__ 
            #define __WATCH_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__
            #define __WATCH_OS_VERSION_MAX_ALLOWED __WATCHOS_26_1
            /* for compatibility with existing code.  New code should use platform specific checks */
            #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_9_0
        #endif /* __has_builtin(__is_target_os) */
    #endif /* defined(__has_builtin) */
#endif /* __WATCH_OS_VERSION_MIN_REQUIRED */

#ifndef __TV_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin)
        #if __has_builtin(__is_target_os)
            #if __is_target_os(tvos)
                #define __TV_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
                #define __TV_OS_VERSION_MAX_ALLOWED __TVOS_26_1
                /* for compatibility with existing code.  New code should use platform specific checks */
                #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_9_0
            #endif
        #elif  __ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__ 
            #define __TV_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__
            #define __TV_OS_VERSION_MAX_ALLOWED __TVOS_26_1
            /* for compatibility with existing code.  New code should use platform specific checks */
            #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_9_0
        #endif /* __has_builtin(__is_target_os) */
    #endif /* defined(__has_builtin) */
#endif /* __TV_OS_VERSION_MIN_REQUIRED */



#ifndef __DRIVERKIT_VERSION_MIN_REQUIRED
    #if defined(__has_builtin)
        #if __has_builtin(__is_target_os)
            #if __is_target_os(driverkit)
                #define __DRIVERKIT_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
                #define __DRIVERKIT_VERSION_MAX_ALLOWED __DRIVERKIT_25_1
            #endif
        #endif /* __has_builtin(__is_target_os) */
    #endif /* defined(__has_builtin) */
#endif /* __DRIVERKIT_VERSION_MIN_REQUIRED */

#ifndef __VISION_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin)
        #if __has_builtin(__is_target_os)
            #if __is_target_os(visionos)
                #define __VISION_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
                #define __VISION_OS_VERSION_MAX_ALLOWED __VISIONOS_26_1
                /* for compatibility with existing code.  New code should use platform specific checks */
                #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_17_1
            #endif
        #endif /* __has_builtin(__is_target_os) */
    #endif /* defined(__has_builtin) */
#endif /* __VISION_OS_VERSION_MIN_REQUIRED */


#ifndef __OPEN_SOURCE__

#endif /* __OPEN_SOURCE__ */

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    /* make sure a default max version is set */
    #ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
        #define __IPHONE_OS_VERSION_MAX_ALLOWED     __IPHONE_17_0
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

#if defined(__has_feature) && defined(__has_attribute)
 #if __has_attribute(availability)
   #define __API_AVAILABLE_PLATFORM_macos(x) macos,introduced=x
   #define __API_DEPRECATED_PLATFORM_macos(x,y) macos,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_macos(x,y,z) macos,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_macos macos,unavailable
   #define __API_AVAILABLE_PLATFORM_macosx(x) macos,introduced=x
   #define __API_DEPRECATED_PLATFORM_macosx(x,y) macos,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_macosx(x,y,z) macos,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_macosx macos,unavailable
   #define __API_AVAILABLE_PLATFORM_macOSApplicationExtension(x) macOSApplicationExtension,introduced=x
   #define __API_DEPRECATED_PLATFORM_macOSApplicationExtension(x,y) macOSApplicationExtension,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_macOSApplicationExtension(x,y,z) macOSApplicationExtension,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_macOSApplicationExtension macOSApplicationExtension,unavailable
   #define __API_AVAILABLE_PLATFORM_ios(x) ios,introduced=x
   #define __API_DEPRECATED_PLATFORM_ios(x,y) ios,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_ios(x,y,z) ios,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_ios ios,unavailable
   #define __API_AVAILABLE_PLATFORM_iOSApplicationExtension(x) iOSApplicationExtension,introduced=x
   #define __API_DEPRECATED_PLATFORM_iOSApplicationExtension(x,y) iOSApplicationExtension,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_iOSApplicationExtension(x,y,z) iOSApplicationExtension,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_iOSApplicationExtension iOSApplicationExtension,unavailable
   #define __API_AVAILABLE_PLATFORM_macCatalyst(x) macCatalyst,introduced=x
   #define __API_DEPRECATED_PLATFORM_macCatalyst(x,y) macCatalyst,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_macCatalyst(x,y,z) macCatalyst,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_macCatalyst macCatalyst,unavailable
   #define __API_AVAILABLE_PLATFORM_macCatalystApplicationExtension(x) macCatalystApplicationExtension,introduced=x
   #define __API_DEPRECATED_PLATFORM_macCatalystApplicationExtension(x,y) macCatalystApplicationExtension,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_macCatalystApplicationExtension(x,y,z) macCatalystApplicationExtension,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_macCatalystApplicationExtension macCatalystApplicationExtension,unavailable
   #define __API_AVAILABLE_PLATFORM_watchos(x) watchos,introduced=x
   #define __API_DEPRECATED_PLATFORM_watchos(x,y) watchos,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_watchos(x,y,z) watchos,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_watchos watchos,unavailable
   #define __API_AVAILABLE_PLATFORM_watchOSApplicationExtension(x) watchOSApplicationExtension,introduced=x
   #define __API_DEPRECATED_PLATFORM_watchOSApplicationExtension(x,y) watchOSApplicationExtension,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_watchOSApplicationExtension(x,y,z) watchOSApplicationExtension,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_watchOSApplicationExtension watchOSApplicationExtension,unavailable
   #define __API_AVAILABLE_PLATFORM_tvos(x) tvos,introduced=x
   #define __API_DEPRECATED_PLATFORM_tvos(x,y) tvos,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_tvos(x,y,z) tvos,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_tvos tvos,unavailable
   #define __API_AVAILABLE_PLATFORM_tvOSApplicationExtension(x) tvOSApplicationExtension,introduced=x
   #define __API_DEPRECATED_PLATFORM_tvOSApplicationExtension(x,y) tvOSApplicationExtension,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_tvOSApplicationExtension(x,y,z) tvOSApplicationExtension,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_tvOSApplicationExtension tvOSApplicationExtension,unavailable

   #define __API_AVAILABLE_PLATFORM_driverkit(x) driverkit,introduced=x
   #define __API_DEPRECATED_PLATFORM_driverkit(x,y) driverkit,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_driverkit(x,y,z) driverkit,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_driverkit driverkit,unavailable
   #define __API_AVAILABLE_PLATFORM_visionos(x) visionos,introduced=x
   #define __API_DEPRECATED_PLATFORM_visionos(x,y) visionos,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_visionos(x,y,z) visionos,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_visionos visionos,unavailable
   #define __API_AVAILABLE_PLATFORM_visionOSApplicationExtension(x) visionOSApplicationExtension,introduced=x
   #define __API_DEPRECATED_PLATFORM_visionOSApplicationExtension(x,y) visionOSApplicationExtension,introduced=x,deprecated=y
   #define __API_OBSOLETED_PLATFORM_visionOSApplicationExtension(x,y,z) visionOSApplicationExtension,introduced=x,deprecated=y,obsoleted=z
   #define __API_UNAVAILABLE_PLATFORM_visionOSApplicationExtension visionOSApplicationExtension,unavailable
   
   #define __API_UNAVAILABLE_PLATFORM_kernelkit kernelkit,unavailable
 #endif /* __has_attribute(availability) */
#endif /* defined(__has_feature) && defined(__has_attribute) */

#ifndef __OPEN_SOURCE__

#endif /* __OPEN_SOURCE__ */

#if defined(__has_feature) && defined(__has_attribute)
 #if __has_attribute(availability)
  #define __API_APPLY_TO any(record, enum, enum_constant, function, objc_method, objc_category, objc_protocol, objc_interface, objc_property, type_alias, variable, field)
  #define __API_RANGE_STRINGIFY(x) __API_RANGE_STRINGIFY2(x)
  #define __API_RANGE_STRINGIFY2(x) #x
 #endif /* __has_attribute(availability) */
#endif /* defined(__has_feature) && defined(__has_attribute) */
/*
 Macros for defining which versions/platform a given symbol can be used.
 
 @see http://clang.llvm.org/docs/AttributeReference.html#availability
 */

#if defined(__has_feature) && defined(__has_attribute)
 #if __has_attribute(availability)

    

    #define __API_A(x) __attribute__((availability(__API_AVAILABLE_PLATFORM_##x)))
    
    #define __API_AVAILABLE0(arg0) __API_A(arg0)
    #define __API_AVAILABLE1(arg0,arg1) __API_A(arg0) __API_A(arg1)
    #define __API_AVAILABLE2(arg0,arg1,arg2) __API_A(arg0) __API_A(arg1) __API_A(arg2)
    #define __API_AVAILABLE3(arg0,arg1,arg2,arg3) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3)
    #define __API_AVAILABLE4(arg0,arg1,arg2,arg3,arg4) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4)
    #define __API_AVAILABLE5(arg0,arg1,arg2,arg3,arg4,arg5) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5)
    #define __API_AVAILABLE6(arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6)
    #define __API_AVAILABLE7(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7)
    #define __API_AVAILABLE8(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7) __API_A(arg8)
    #define __API_AVAILABLE9(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7) __API_A(arg8) __API_A(arg9)
    #define __API_AVAILABLE10(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7) __API_A(arg8) __API_A(arg9) __API_A(arg10)
    #define __API_AVAILABLE11(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7) __API_A(arg8) __API_A(arg9) __API_A(arg10) __API_A(arg11)
    #define __API_AVAILABLE12(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7) __API_A(arg8) __API_A(arg9) __API_A(arg10) __API_A(arg11) __API_A(arg12)
    #define __API_AVAILABLE13(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7) __API_A(arg8) __API_A(arg9) __API_A(arg10) __API_A(arg11) __API_A(arg12) __API_A(arg13)
    #define __API_AVAILABLE14(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7) __API_A(arg8) __API_A(arg9) __API_A(arg10) __API_A(arg11) __API_A(arg12) __API_A(arg13) __API_A(arg14)
    #define __API_AVAILABLE15(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_A(arg0) __API_A(arg1) __API_A(arg2) __API_A(arg3) __API_A(arg4) __API_A(arg5) __API_A(arg6) __API_A(arg7) __API_A(arg8) __API_A(arg9) __API_A(arg10) __API_A(arg11) __API_A(arg12) __API_A(arg13) __API_A(arg14) __API_A(arg15)
    #define __API_AVAILABLE_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,NAME,...) NAME
    
    #define __API_A_BEGIN(x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_AVAILABLE_PLATFORM_##x))), apply_to = __API_APPLY_TO)))
    
    #define __API_AVAILABLE_BEGIN0(arg0) __API_A_BEGIN(arg0)
    #define __API_AVAILABLE_BEGIN1(arg0,arg1) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1)
    #define __API_AVAILABLE_BEGIN2(arg0,arg1,arg2) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2)
    #define __API_AVAILABLE_BEGIN3(arg0,arg1,arg2,arg3) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3)
    #define __API_AVAILABLE_BEGIN4(arg0,arg1,arg2,arg3,arg4) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4)
    #define __API_AVAILABLE_BEGIN5(arg0,arg1,arg2,arg3,arg4,arg5) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5)
    #define __API_AVAILABLE_BEGIN6(arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6)
    #define __API_AVAILABLE_BEGIN7(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7)
    #define __API_AVAILABLE_BEGIN8(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7) __API_A_BEGIN(arg8)
    #define __API_AVAILABLE_BEGIN9(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7) __API_A_BEGIN(arg8) __API_A_BEGIN(arg9)
    #define __API_AVAILABLE_BEGIN10(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7) __API_A_BEGIN(arg8) __API_A_BEGIN(arg9) __API_A_BEGIN(arg10)
    #define __API_AVAILABLE_BEGIN11(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7) __API_A_BEGIN(arg8) __API_A_BEGIN(arg9) __API_A_BEGIN(arg10) __API_A_BEGIN(arg11)
    #define __API_AVAILABLE_BEGIN12(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7) __API_A_BEGIN(arg8) __API_A_BEGIN(arg9) __API_A_BEGIN(arg10) __API_A_BEGIN(arg11) __API_A_BEGIN(arg12)
    #define __API_AVAILABLE_BEGIN13(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7) __API_A_BEGIN(arg8) __API_A_BEGIN(arg9) __API_A_BEGIN(arg10) __API_A_BEGIN(arg11) __API_A_BEGIN(arg12) __API_A_BEGIN(arg13)
    #define __API_AVAILABLE_BEGIN14(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7) __API_A_BEGIN(arg8) __API_A_BEGIN(arg9) __API_A_BEGIN(arg10) __API_A_BEGIN(arg11) __API_A_BEGIN(arg12) __API_A_BEGIN(arg13) __API_A_BEGIN(arg14)
    #define __API_AVAILABLE_BEGIN15(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7) __API_A_BEGIN(arg8) __API_A_BEGIN(arg9) __API_A_BEGIN(arg10) __API_A_BEGIN(arg11) __API_A_BEGIN(arg12) __API_A_BEGIN(arg13) __API_A_BEGIN(arg14) __API_A_BEGIN(arg15)
    #define __API_AVAILABLE_BEGIN_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,NAME,...) NAME

    

    #define __API_D(msg,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x,message=msg)))
  
    #define __API_DEPRECATED_MSG0(msg,arg0) __API_D(msg,arg0)
    #define __API_DEPRECATED_MSG1(msg,arg0,arg1) __API_D(msg,arg0) __API_D(msg,arg1)
    #define __API_DEPRECATED_MSG2(msg,arg0,arg1,arg2) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2)
    #define __API_DEPRECATED_MSG3(msg,arg0,arg1,arg2,arg3) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3)
    #define __API_DEPRECATED_MSG4(msg,arg0,arg1,arg2,arg3,arg4) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4)
    #define __API_DEPRECATED_MSG5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5)
    #define __API_DEPRECATED_MSG6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6)
    #define __API_DEPRECATED_MSG7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7)
    #define __API_DEPRECATED_MSG8(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7) __API_D(msg,arg8)
    #define __API_DEPRECATED_MSG9(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7) __API_D(msg,arg8) __API_D(msg,arg9)
    #define __API_DEPRECATED_MSG10(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7) __API_D(msg,arg8) __API_D(msg,arg9) __API_D(msg,arg10)
    #define __API_DEPRECATED_MSG11(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7) __API_D(msg,arg8) __API_D(msg,arg9) __API_D(msg,arg10) __API_D(msg,arg11)
    #define __API_DEPRECATED_MSG12(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7) __API_D(msg,arg8) __API_D(msg,arg9) __API_D(msg,arg10) __API_D(msg,arg11) __API_D(msg,arg12)
    #define __API_DEPRECATED_MSG13(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7) __API_D(msg,arg8) __API_D(msg,arg9) __API_D(msg,arg10) __API_D(msg,arg11) __API_D(msg,arg12) __API_D(msg,arg13)
    #define __API_DEPRECATED_MSG14(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7) __API_D(msg,arg8) __API_D(msg,arg9) __API_D(msg,arg10) __API_D(msg,arg11) __API_D(msg,arg12) __API_D(msg,arg13) __API_D(msg,arg14)
    #define __API_DEPRECATED_MSG15(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7) __API_D(msg,arg8) __API_D(msg,arg9) __API_D(msg,arg10) __API_D(msg,arg11) __API_D(msg,arg12) __API_D(msg,arg13) __API_D(msg,arg14) __API_D(msg,arg15)
    #define __API_DEPRECATED_MSG_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,NAME,...) NAME

    #define __API_D_BEGIN(msg, x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x,message=msg))), apply_to = __API_APPLY_TO)))

    #define __API_DEPRECATED_BEGIN0(msg,arg0) __API_D_BEGIN(msg,arg0)
    #define __API_DEPRECATED_BEGIN1(msg,arg0,arg1) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1)
    #define __API_DEPRECATED_BEGIN2(msg,arg0,arg1,arg2) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2)
    #define __API_DEPRECATED_BEGIN3(msg,arg0,arg1,arg2,arg3) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3)
    #define __API_DEPRECATED_BEGIN4(msg,arg0,arg1,arg2,arg3,arg4) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4)
    #define __API_DEPRECATED_BEGIN5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5)
    #define __API_DEPRECATED_BEGIN6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6)
    #define __API_DEPRECATED_BEGIN7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7)
    #define __API_DEPRECATED_BEGIN8(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7) __API_D_BEGIN(msg,arg8)
    #define __API_DEPRECATED_BEGIN9(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7) __API_D_BEGIN(msg,arg8) __API_D_BEGIN(msg,arg9)
    #define __API_DEPRECATED_BEGIN10(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7) __API_D_BEGIN(msg,arg8) __API_D_BEGIN(msg,arg9) __API_D_BEGIN(msg,arg10)
    #define __API_DEPRECATED_BEGIN11(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7) __API_D_BEGIN(msg,arg8) __API_D_BEGIN(msg,arg9) __API_D_BEGIN(msg,arg10) __API_D_BEGIN(msg,arg11)
    #define __API_DEPRECATED_BEGIN12(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7) __API_D_BEGIN(msg,arg8) __API_D_BEGIN(msg,arg9) __API_D_BEGIN(msg,arg10) __API_D_BEGIN(msg,arg11) __API_D_BEGIN(msg,arg12)
    #define __API_DEPRECATED_BEGIN13(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7) __API_D_BEGIN(msg,arg8) __API_D_BEGIN(msg,arg9) __API_D_BEGIN(msg,arg10) __API_D_BEGIN(msg,arg11) __API_D_BEGIN(msg,arg12) __API_D_BEGIN(msg,arg13)
    #define __API_DEPRECATED_BEGIN14(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7) __API_D_BEGIN(msg,arg8) __API_D_BEGIN(msg,arg9) __API_D_BEGIN(msg,arg10) __API_D_BEGIN(msg,arg11) __API_D_BEGIN(msg,arg12) __API_D_BEGIN(msg,arg13) __API_D_BEGIN(msg,arg14)
    #define __API_DEPRECATED_BEGIN15(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7) __API_D_BEGIN(msg,arg8) __API_D_BEGIN(msg,arg9) __API_D_BEGIN(msg,arg10) __API_D_BEGIN(msg,arg11) __API_D_BEGIN(msg,arg12) __API_D_BEGIN(msg,arg13) __API_D_BEGIN(msg,arg14) __API_D_BEGIN(msg,arg15)
    #define __API_DEPRECATED_BEGIN_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,NAME,...) NAME

    #if __has_feature(attribute_availability_with_replacement)
        #define __API_DR(rep,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x,replacement=rep)))
    #else
        #define __API_DR(rep,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x)))
    #endif

    #define __API_DEPRECATED_REP0(msg,arg0) __API_DR(msg,arg0)
    #define __API_DEPRECATED_REP1(msg,arg0,arg1) __API_DR(msg,arg0) __API_DR(msg,arg1)
    #define __API_DEPRECATED_REP2(msg,arg0,arg1,arg2) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2)
    #define __API_DEPRECATED_REP3(msg,arg0,arg1,arg2,arg3) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3)
    #define __API_DEPRECATED_REP4(msg,arg0,arg1,arg2,arg3,arg4) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4)
    #define __API_DEPRECATED_REP5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5)
    #define __API_DEPRECATED_REP6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6)
    #define __API_DEPRECATED_REP7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7)
    #define __API_DEPRECATED_REP8(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7) __API_DR(msg,arg8)
    #define __API_DEPRECATED_REP9(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7) __API_DR(msg,arg8) __API_DR(msg,arg9)
    #define __API_DEPRECATED_REP10(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7) __API_DR(msg,arg8) __API_DR(msg,arg9) __API_DR(msg,arg10)
    #define __API_DEPRECATED_REP11(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7) __API_DR(msg,arg8) __API_DR(msg,arg9) __API_DR(msg,arg10) __API_DR(msg,arg11)
    #define __API_DEPRECATED_REP12(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7) __API_DR(msg,arg8) __API_DR(msg,arg9) __API_DR(msg,arg10) __API_DR(msg,arg11) __API_DR(msg,arg12)
    #define __API_DEPRECATED_REP13(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7) __API_DR(msg,arg8) __API_DR(msg,arg9) __API_DR(msg,arg10) __API_DR(msg,arg11) __API_DR(msg,arg12) __API_DR(msg,arg13)
    #define __API_DEPRECATED_REP14(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7) __API_DR(msg,arg8) __API_DR(msg,arg9) __API_DR(msg,arg10) __API_DR(msg,arg11) __API_DR(msg,arg12) __API_DR(msg,arg13) __API_DR(msg,arg14)
    #define __API_DEPRECATED_REP15(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_DR(msg,arg0) __API_DR(msg,arg1) __API_DR(msg,arg2) __API_DR(msg,arg3) __API_DR(msg,arg4) __API_DR(msg,arg5) __API_DR(msg,arg6) __API_DR(msg,arg7) __API_DR(msg,arg8) __API_DR(msg,arg9) __API_DR(msg,arg10) __API_DR(msg,arg11) __API_DR(msg,arg12) __API_DR(msg,arg13) __API_DR(msg,arg14) __API_DR(msg,arg15)
    #define __API_DEPRECATED_REP_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,NAME,...) NAME

    #if __has_feature(attribute_availability_with_replacement)
        #define __API_DR_BEGIN(rep,x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x,replacement=rep))), apply_to = __API_APPLY_TO)))
    #else
        #define __API_DR_BEGIN(rep,x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x))), apply_to = __API_APPLY_TO)))
    #endif

    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN0(msg,arg0) __API_DR_BEGIN(msg,arg0)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN1(msg,arg0,arg1) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN2(msg,arg0,arg1,arg2) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN3(msg,arg0,arg1,arg2,arg3) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN4(msg,arg0,arg1,arg2,arg3,arg4) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN8(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7) __API_DR_BEGIN(msg,arg8)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN9(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7) __API_DR_BEGIN(msg,arg8) __API_DR_BEGIN(msg,arg9)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN10(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7) __API_DR_BEGIN(msg,arg8) __API_DR_BEGIN(msg,arg9) __API_DR_BEGIN(msg,arg10)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN11(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7) __API_DR_BEGIN(msg,arg8) __API_DR_BEGIN(msg,arg9) __API_DR_BEGIN(msg,arg10) __API_DR_BEGIN(msg,arg11)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN12(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7) __API_DR_BEGIN(msg,arg8) __API_DR_BEGIN(msg,arg9) __API_DR_BEGIN(msg,arg10) __API_DR_BEGIN(msg,arg11) __API_DR_BEGIN(msg,arg12)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN13(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7) __API_DR_BEGIN(msg,arg8) __API_DR_BEGIN(msg,arg9) __API_DR_BEGIN(msg,arg10) __API_DR_BEGIN(msg,arg11) __API_DR_BEGIN(msg,arg12) __API_DR_BEGIN(msg,arg13)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN14(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7) __API_DR_BEGIN(msg,arg8) __API_DR_BEGIN(msg,arg9) __API_DR_BEGIN(msg,arg10) __API_DR_BEGIN(msg,arg11) __API_DR_BEGIN(msg,arg12) __API_DR_BEGIN(msg,arg13) __API_DR_BEGIN(msg,arg14)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN15(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_DR_BEGIN(msg,arg0) __API_DR_BEGIN(msg,arg1) __API_DR_BEGIN(msg,arg2) __API_DR_BEGIN(msg,arg3) __API_DR_BEGIN(msg,arg4) __API_DR_BEGIN(msg,arg5) __API_DR_BEGIN(msg,arg6) __API_DR_BEGIN(msg,arg7) __API_DR_BEGIN(msg,arg8) __API_DR_BEGIN(msg,arg9) __API_DR_BEGIN(msg,arg10) __API_DR_BEGIN(msg,arg11) __API_DR_BEGIN(msg,arg12) __API_DR_BEGIN(msg,arg13) __API_DR_BEGIN(msg,arg14) __API_DR_BEGIN(msg,arg15)
    #define __API_DEPRECATED_WITH_REPLACEMENT_BEGIN_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,NAME,...) NAME

    

#define __API_O(msg,x) __attribute__((availability(__API_OBSOLETED_PLATFORM_##x,message=msg)))

    #define __API_OBSOLETED_MSG0(msg,arg0) __API_O(msg,arg0)
    #define __API_OBSOLETED_MSG1(msg,arg0,arg1) __API_O(msg,arg0) __API_O(msg,arg1)
    #define __API_OBSOLETED_MSG2(msg,arg0,arg1,arg2) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2)
    #define __API_OBSOLETED_MSG3(msg,arg0,arg1,arg2,arg3) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3)
    #define __API_OBSOLETED_MSG4(msg,arg0,arg1,arg2,arg3,arg4) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4)
    #define __API_OBSOLETED_MSG5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5)
    #define __API_OBSOLETED_MSG6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6)
    #define __API_OBSOLETED_MSG7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7)
    #define __API_OBSOLETED_MSG8(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7) __API_O(msg,arg8)
    #define __API_OBSOLETED_MSG9(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7) __API_O(msg,arg8) __API_O(msg,arg9)
    #define __API_OBSOLETED_MSG10(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7) __API_O(msg,arg8) __API_O(msg,arg9) __API_O(msg,arg10)
    #define __API_OBSOLETED_MSG11(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7) __API_O(msg,arg8) __API_O(msg,arg9) __API_O(msg,arg10) __API_O(msg,arg11)
    #define __API_OBSOLETED_MSG12(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7) __API_O(msg,arg8) __API_O(msg,arg9) __API_O(msg,arg10) __API_O(msg,arg11) __API_O(msg,arg12)
    #define __API_OBSOLETED_MSG13(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7) __API_O(msg,arg8) __API_O(msg,arg9) __API_O(msg,arg10) __API_O(msg,arg11) __API_O(msg,arg12) __API_O(msg,arg13)
    #define __API_OBSOLETED_MSG14(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7) __API_O(msg,arg8) __API_O(msg,arg9) __API_O(msg,arg10) __API_O(msg,arg11) __API_O(msg,arg12) __API_O(msg,arg13) __API_O(msg,arg14)
    #define __API_OBSOLETED_MSG15(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_O(msg,arg0) __API_O(msg,arg1) __API_O(msg,arg2) __API_O(msg,arg3) __API_O(msg,arg4) __API_O(msg,arg5) __API_O(msg,arg6) __API_O(msg,arg7) __API_O(msg,arg8) __API_O(msg,arg9) __API_O(msg,arg10) __API_O(msg,arg11) __API_O(msg,arg12) __API_O(msg,arg13) __API_O(msg,arg14) __API_O(msg,arg15)
    #define __API_OBSOLETED_MSG_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,NAME,...) NAME

#define __API_O_BEGIN(msg, x, y) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_OBSOLETED_PLATFORM_##x,message=msg))), apply_to = __API_APPLY_TO)))

    #define __API_OBSOLETED_BEGIN0(msg,arg0) __API_O_BEGIN(msg,arg0)
    #define __API_OBSOLETED_BEGIN1(msg,arg0,arg1) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1)
    #define __API_OBSOLETED_BEGIN2(msg,arg0,arg1,arg2) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2)
    #define __API_OBSOLETED_BEGIN3(msg,arg0,arg1,arg2,arg3) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3)
    #define __API_OBSOLETED_BEGIN4(msg,arg0,arg1,arg2,arg3,arg4) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4)
    #define __API_OBSOLETED_BEGIN5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5)
    #define __API_OBSOLETED_BEGIN6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6)
    #define __API_OBSOLETED_BEGIN7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7)
    #define __API_OBSOLETED_BEGIN8(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7) __API_O_BEGIN(msg,arg8)
    #define __API_OBSOLETED_BEGIN9(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7) __API_O_BEGIN(msg,arg8) __API_O_BEGIN(msg,arg9)
    #define __API_OBSOLETED_BEGIN10(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7) __API_O_BEGIN(msg,arg8) __API_O_BEGIN(msg,arg9) __API_O_BEGIN(msg,arg10)
    #define __API_OBSOLETED_BEGIN11(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7) __API_O_BEGIN(msg,arg8) __API_O_BEGIN(msg,arg9) __API_O_BEGIN(msg,arg10) __API_O_BEGIN(msg,arg11)
    #define __API_OBSOLETED_BEGIN12(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7) __API_O_BEGIN(msg,arg8) __API_O_BEGIN(msg,arg9) __API_O_BEGIN(msg,arg10) __API_O_BEGIN(msg,arg11) __API_O_BEGIN(msg,arg12)
    #define __API_OBSOLETED_BEGIN13(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7) __API_O_BEGIN(msg,arg8) __API_O_BEGIN(msg,arg9) __API_O_BEGIN(msg,arg10) __API_O_BEGIN(msg,arg11) __API_O_BEGIN(msg,arg12) __API_O_BEGIN(msg,arg13)
    #define __API_OBSOLETED_BEGIN14(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7) __API_O_BEGIN(msg,arg8) __API_O_BEGIN(msg,arg9) __API_O_BEGIN(msg,arg10) __API_O_BEGIN(msg,arg11) __API_O_BEGIN(msg,arg12) __API_O_BEGIN(msg,arg13) __API_O_BEGIN(msg,arg14)
    #define __API_OBSOLETED_BEGIN15(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_O_BEGIN(msg,arg0) __API_O_BEGIN(msg,arg1) __API_O_BEGIN(msg,arg2) __API_O_BEGIN(msg,arg3) __API_O_BEGIN(msg,arg4) __API_O_BEGIN(msg,arg5) __API_O_BEGIN(msg,arg6) __API_O_BEGIN(msg,arg7) __API_O_BEGIN(msg,arg8) __API_O_BEGIN(msg,arg9) __API_O_BEGIN(msg,arg10) __API_O_BEGIN(msg,arg11) __API_O_BEGIN(msg,arg12) __API_O_BEGIN(msg,arg13) __API_O_BEGIN(msg,arg14) __API_O_BEGIN(msg,arg15)
    #define __API_OBSOLETED_BEGIN_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,NAME,...) NAME

#if __has_feature(attribute_availability_with_replacement)
    #define __API_OR(rep,x) __attribute__((availability(__API_OBSOLETED_PLATFORM_##x,replacement=rep)))
#else
    #define __API_OR(rep,x) __attribute__((availability(__API_OBSOLETED_PLATFORM_##x)))
#endif

    #define __API_OBSOLETED_REP0(msg,arg0) __API_OR(msg,arg0)
    #define __API_OBSOLETED_REP1(msg,arg0,arg1) __API_OR(msg,arg0) __API_OR(msg,arg1)
    #define __API_OBSOLETED_REP2(msg,arg0,arg1,arg2) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2)
    #define __API_OBSOLETED_REP3(msg,arg0,arg1,arg2,arg3) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3)
    #define __API_OBSOLETED_REP4(msg,arg0,arg1,arg2,arg3,arg4) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4)
    #define __API_OBSOLETED_REP5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5)
    #define __API_OBSOLETED_REP6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6)
    #define __API_OBSOLETED_REP7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7)
    #define __API_OBSOLETED_REP8(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7) __API_OR(msg,arg8)
    #define __API_OBSOLETED_REP9(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7) __API_OR(msg,arg8) __API_OR(msg,arg9)
    #define __API_OBSOLETED_REP10(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7) __API_OR(msg,arg8) __API_OR(msg,arg9) __API_OR(msg,arg10)
    #define __API_OBSOLETED_REP11(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7) __API_OR(msg,arg8) __API_OR(msg,arg9) __API_OR(msg,arg10) __API_OR(msg,arg11)
    #define __API_OBSOLETED_REP12(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7) __API_OR(msg,arg8) __API_OR(msg,arg9) __API_OR(msg,arg10) __API_OR(msg,arg11) __API_OR(msg,arg12)
    #define __API_OBSOLETED_REP13(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7) __API_OR(msg,arg8) __API_OR(msg,arg9) __API_OR(msg,arg10) __API_OR(msg,arg11) __API_OR(msg,arg12) __API_OR(msg,arg13)
    #define __API_OBSOLETED_REP14(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7) __API_OR(msg,arg8) __API_OR(msg,arg9) __API_OR(msg,arg10) __API_OR(msg,arg11) __API_OR(msg,arg12) __API_OR(msg,arg13) __API_OR(msg,arg14)
    #define __API_OBSOLETED_REP15(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_OR(msg,arg0) __API_OR(msg,arg1) __API_OR(msg,arg2) __API_OR(msg,arg3) __API_OR(msg,arg4) __API_OR(msg,arg5) __API_OR(msg,arg6) __API_OR(msg,arg7) __API_OR(msg,arg8) __API_OR(msg,arg9) __API_OR(msg,arg10) __API_OR(msg,arg11) __API_OR(msg,arg12) __API_OR(msg,arg13) __API_OR(msg,arg14) __API_OR(msg,arg15)
    #define __API_OBSOLETED_REP_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,NAME,...) NAME

#if __has_feature(attribute_availability_with_replacement)
    #define __API_OR_BEGIN(rep,x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_OBSOLETED_PLATFORM_##x,replacement=rep))), apply_to = __API_APPLY_TO)))
#else
    #define __API_OR_BEGIN(rep,x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_OBSOLETED_PLATFORM_##x))), apply_to = __API_APPLY_TO)))
#endif

    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN0(msg,arg0) __API_R_BEGIN(msg,arg0)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN1(msg,arg0,arg1) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN2(msg,arg0,arg1,arg2) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN3(msg,arg0,arg1,arg2,arg3) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN4(msg,arg0,arg1,arg2,arg3,arg4) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN8(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7) __API_R_BEGIN(msg,arg8)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN9(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7) __API_R_BEGIN(msg,arg8) __API_R_BEGIN(msg,arg9)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN10(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7) __API_R_BEGIN(msg,arg8) __API_R_BEGIN(msg,arg9) __API_R_BEGIN(msg,arg10)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN11(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7) __API_R_BEGIN(msg,arg8) __API_R_BEGIN(msg,arg9) __API_R_BEGIN(msg,arg10) __API_R_BEGIN(msg,arg11)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN12(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7) __API_R_BEGIN(msg,arg8) __API_R_BEGIN(msg,arg9) __API_R_BEGIN(msg,arg10) __API_R_BEGIN(msg,arg11) __API_R_BEGIN(msg,arg12)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN13(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7) __API_R_BEGIN(msg,arg8) __API_R_BEGIN(msg,arg9) __API_R_BEGIN(msg,arg10) __API_R_BEGIN(msg,arg11) __API_R_BEGIN(msg,arg12) __API_R_BEGIN(msg,arg13)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN14(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7) __API_R_BEGIN(msg,arg8) __API_R_BEGIN(msg,arg9) __API_R_BEGIN(msg,arg10) __API_R_BEGIN(msg,arg11) __API_R_BEGIN(msg,arg12) __API_R_BEGIN(msg,arg13) __API_R_BEGIN(msg,arg14)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN15(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7) __API_R_BEGIN(msg,arg8) __API_R_BEGIN(msg,arg9) __API_R_BEGIN(msg,arg10) __API_R_BEGIN(msg,arg11) __API_R_BEGIN(msg,arg12) __API_R_BEGIN(msg,arg13) __API_R_BEGIN(msg,arg14) __API_R_BEGIN(msg,arg15)
    #define __API_OBSOLETED_WITH_REPLACEMENT_BEGIN_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,NAME,...) NAME

    /*
     * API Unavailability
     * Use to specify that an API is unavailable for a particular platform.
     *
     * Example:
     *    __API_UNAVAILABLE(macos)
     *    __API_UNAVAILABLE(watchos, tvos)
     */

    #define __API_U(x) __attribute__((availability(__API_UNAVAILABLE_PLATFORM_##x)))

    #define __API_UNAVAILABLE0(arg0) __API_U(arg0)
    #define __API_UNAVAILABLE1(arg0,arg1) __API_U(arg0) __API_U(arg1)
    #define __API_UNAVAILABLE2(arg0,arg1,arg2) __API_U(arg0) __API_U(arg1) __API_U(arg2)
    #define __API_UNAVAILABLE3(arg0,arg1,arg2,arg3) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3)
    #define __API_UNAVAILABLE4(arg0,arg1,arg2,arg3,arg4) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4)
    #define __API_UNAVAILABLE5(arg0,arg1,arg2,arg3,arg4,arg5) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5)
    #define __API_UNAVAILABLE6(arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6)
    #define __API_UNAVAILABLE7(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7)
    #define __API_UNAVAILABLE8(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7) __API_U(arg8)
    #define __API_UNAVAILABLE9(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7) __API_U(arg8) __API_U(arg9)
    #define __API_UNAVAILABLE10(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7) __API_U(arg8) __API_U(arg9) __API_U(arg10)
    #define __API_UNAVAILABLE11(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7) __API_U(arg8) __API_U(arg9) __API_U(arg10) __API_U(arg11)
    #define __API_UNAVAILABLE12(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7) __API_U(arg8) __API_U(arg9) __API_U(arg10) __API_U(arg11) __API_U(arg12)
    #define __API_UNAVAILABLE13(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7) __API_U(arg8) __API_U(arg9) __API_U(arg10) __API_U(arg11) __API_U(arg12) __API_U(arg13)
    #define __API_UNAVAILABLE14(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7) __API_U(arg8) __API_U(arg9) __API_U(arg10) __API_U(arg11) __API_U(arg12) __API_U(arg13) __API_U(arg14)
    #define __API_UNAVAILABLE15(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_U(arg0) __API_U(arg1) __API_U(arg2) __API_U(arg3) __API_U(arg4) __API_U(arg5) __API_U(arg6) __API_U(arg7) __API_U(arg8) __API_U(arg9) __API_U(arg10) __API_U(arg11) __API_U(arg12) __API_U(arg13) __API_U(arg14) __API_U(arg15)
    #define __API_UNAVAILABLE_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,NAME,...) NAME

    #define __API_U_BEGIN(x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_UNAVAILABLE_PLATFORM_##x))), apply_to = __API_APPLY_TO)))

    #define __API_UNAVAILABLE_BEGIN0(arg0) __API_U_BEGIN(arg0)
    #define __API_UNAVAILABLE_BEGIN1(arg0,arg1) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1)
    #define __API_UNAVAILABLE_BEGIN2(arg0,arg1,arg2) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2)
    #define __API_UNAVAILABLE_BEGIN3(arg0,arg1,arg2,arg3) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3)
    #define __API_UNAVAILABLE_BEGIN4(arg0,arg1,arg2,arg3,arg4) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4)
    #define __API_UNAVAILABLE_BEGIN5(arg0,arg1,arg2,arg3,arg4,arg5) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5)
    #define __API_UNAVAILABLE_BEGIN6(arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6)
    #define __API_UNAVAILABLE_BEGIN7(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7)
    #define __API_UNAVAILABLE_BEGIN8(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7) __API_U_BEGIN(arg8)
    #define __API_UNAVAILABLE_BEGIN9(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7) __API_U_BEGIN(arg8) __API_U_BEGIN(arg9)
    #define __API_UNAVAILABLE_BEGIN10(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7) __API_U_BEGIN(arg8) __API_U_BEGIN(arg9) __API_U_BEGIN(arg10)
    #define __API_UNAVAILABLE_BEGIN11(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7) __API_U_BEGIN(arg8) __API_U_BEGIN(arg9) __API_U_BEGIN(arg10) __API_U_BEGIN(arg11)
    #define __API_UNAVAILABLE_BEGIN12(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7) __API_U_BEGIN(arg8) __API_U_BEGIN(arg9) __API_U_BEGIN(arg10) __API_U_BEGIN(arg11) __API_U_BEGIN(arg12)
    #define __API_UNAVAILABLE_BEGIN13(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7) __API_U_BEGIN(arg8) __API_U_BEGIN(arg9) __API_U_BEGIN(arg10) __API_U_BEGIN(arg11) __API_U_BEGIN(arg12) __API_U_BEGIN(arg13)
    #define __API_UNAVAILABLE_BEGIN14(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7) __API_U_BEGIN(arg8) __API_U_BEGIN(arg9) __API_U_BEGIN(arg10) __API_U_BEGIN(arg11) __API_U_BEGIN(arg12) __API_U_BEGIN(arg13) __API_U_BEGIN(arg14)
    #define __API_UNAVAILABLE_BEGIN15(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7) __API_U_BEGIN(arg8) __API_U_BEGIN(arg9) __API_U_BEGIN(arg10) __API_U_BEGIN(arg11) __API_U_BEGIN(arg12) __API_U_BEGIN(arg13) __API_U_BEGIN(arg14) __API_U_BEGIN(arg15)
    #define __API_UNAVAILABLE_BEGIN_GET_MACRO_93585900(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,NAME,...) NAME

 #endif /* __has_attribute(availability) */
#endif /* #if defined(__has_feature) && defined(__has_attribute) */

/*
 * Swift compiler version
 * Allows for project-agnostic "epochs" for frameworks imported into Swift via the Clang importer, like #if _compiler_version for Swift
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

#endif /* __AVAILABILITY_INTERNAL__ */


#ifndef __OPEN_SOURCE__
// This is explicitly outside the header guard
#ifndef __AVAILABILITY_VERSIONS_VERSION_HASH
#define __AVAILABILITY_VERSIONS_VERSION_HASH 93585900U
#define __AVAILABILITY_VERSIONS_VERSION_STRING "Local"
#define __AVAILABILITY_FILE "AvailabilityInternal.h"
#elif __AVAILABILITY_VERSIONS_VERSION_HASH != 93585900U
#pragma GCC error "Already found AvailabilityVersions version " __AVAILABILITY_FILE " from " __AVAILABILITY_VERSIONS_VERSION_STRING ", which is incompatible with AvailabilityInternal.h from Local. Mixing and matching Availability from different SDKs is not supported"
#endif /* __AVAILABILITY_VERSIONS_VERSION_HASH */
#endif /* __OPEN_SOURCE__ */
