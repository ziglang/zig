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
    #if defined(__has_builtin) && __has_builtin(__is_target_os)
        #if __is_target_os(macos)
            #define __MAC_OS_X_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
            #define __MAC_OS_X_VERSION_MAX_ALLOWED __MAC_14_0
        #endif
    #elif  __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ 
        #define __MAC_OS_X_VERSION_MIN_REQUIRED __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__
        #define __MAC_OS_X_VERSION_MAX_ALLOWED __MAC_14_0
    #endif /*  __has_builtin(__is_target_os) && __is_target_os(macos) */
#endif /* __MAC_OS_X_VERSION_MIN_REQUIRED */

#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin) && __has_builtin(__is_target_os)
        #if __is_target_os(ios)
            #define __IPHONE_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
            #define __IPHONE_OS_VERSION_MAX_ALLOWED __IPHONE_17_0
        #endif
    #elif  __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ 
        #define __IPHONE_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__
        #define __IPHONE_OS_VERSION_MAX_ALLOWED __IPHONE_17_0
    #endif /*  __has_builtin(__is_target_os) && __is_target_os(ios) */
#endif /* __IPHONE_OS_VERSION_MIN_REQUIRED */

#ifndef __WATCH_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin) && __has_builtin(__is_target_os)
        #if __is_target_os(watchos)
            #define __WATCH_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
            #define __WATCH_OS_VERSION_MAX_ALLOWED __WATCHOS_10_0
            /* for compatibility with existing code.  New code should use platform specific checks */
            #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_9_0
        #endif
    #elif  __ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__ 
        #define __WATCH_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__
        #define __WATCH_OS_VERSION_MAX_ALLOWED __WATCHOS_10_0
        /* for compatibility with existing code.  New code should use platform specific checks */
        #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_9_0
    #endif /*  __has_builtin(__is_target_os) && __is_target_os(watchos) */
#endif /* __WATCH_OS_VERSION_MIN_REQUIRED */

#ifndef __TV_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin) && __has_builtin(__is_target_os)
        #if __is_target_os(tvos)
            #define __TV_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
            #define __TV_OS_VERSION_MAX_ALLOWED __TVOS_17_0
            /* for compatibility with existing code.  New code should use platform specific checks */
            #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_9_0
        #endif
    #elif  __ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__ 
        #define __TV_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__
        #define __TV_OS_VERSION_MAX_ALLOWED __TVOS_17_0
        /* for compatibility with existing code.  New code should use platform specific checks */
        #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_9_0
    #endif /*  __has_builtin(__is_target_os) && __is_target_os(tvos) */
#endif /* __TV_OS_VERSION_MIN_REQUIRED */

#ifndef __BRIDGE_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin) && __has_builtin(__is_target_os)
        #if __is_target_os(bridgeos)
            #define __BRIDGE_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
            #define __BRIDGE_OS_VERSION_MAX_ALLOWED __BRIDGEOS_8_0
            /* for compatibility with existing code.  New code should use platform specific checks */
            #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_11_0
        #endif
    #endif 
#endif /* __BRIDGE_OS_VERSION_MIN_REQUIRED */

#ifndef __DRIVERKIT_VERSION_MIN_REQUIRED
    #if defined(__has_builtin) && __has_builtin(__is_target_os)
        #if __is_target_os(driverkit)
            #define __DRIVERKIT_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
            #define __DRIVERKIT_VERSION_MAX_ALLOWED __DRIVERKIT_23_0
        #endif
    #endif /*  __has_builtin(__is_target_os) && __is_target_os(driverkit) */
#endif /* __DRIVERKIT_VERSION_MIN_REQUIRED */

#ifndef __XR_OS_VERSION_MIN_REQUIRED
    #if defined(__has_builtin) && __has_builtin(__is_target_os)
        #if __is_target_os(xros)
            #define __XR_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__
            #define __XR_OS_VERSION_MAX_ALLOWED __XROS_1_0
            /* for compatibility with existing code.  New code should use platform specific checks */
            #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_17_0
        #endif
    #endif /*  __has_builtin(__is_target_os) && __is_target_os(xros) */
#endif /* __XR_OS_VERSION_MIN_REQUIRED */


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

#include <AvailabilityInternalLegacy.h>

#if defined(__has_feature) && defined(__has_attribute)
 #if __has_attribute(availability)
   #define __API_AVAILABLE_PLATFORM_macos(x) macos,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_macos macos,unavailable
   #define __API_DEPRECATED_PLATFORM_macos(x,y) macos,introduced=x,deprecated=y
   #define __API_AVAILABLE_PLATFORM_macosx(x) macos,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_macosx macos,unavailable
   #define __API_DEPRECATED_PLATFORM_macosx(x,y) macos,introduced=x,deprecated=y
   #define __API_AVAILABLE_PLATFORM_ios(x) ios,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_ios ios,unavailable
   #define __API_DEPRECATED_PLATFORM_ios(x,y) ios,introduced=x,deprecated=y
   #define __API_AVAILABLE_PLATFORM_macCatalyst(x) macCatalyst,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_macCatalyst macCatalyst,unavailable
   #define __API_DEPRECATED_PLATFORM_macCatalyst(x,y) macCatalyst,introduced=x,deprecated=y
   #define __API_AVAILABLE_PLATFORM_macCatalyst(x) macCatalyst,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_macCatalyst macCatalyst,unavailable
   #define __API_DEPRECATED_PLATFORM_macCatalyst(x,y) macCatalyst,introduced=x,deprecated=y
   #define __API_AVAILABLE_PLATFORM_watchos(x) watchos,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_watchos watchos,unavailable
   #define __API_DEPRECATED_PLATFORM_watchos(x,y) watchos,introduced=x,deprecated=y
   #define __API_AVAILABLE_PLATFORM_tvos(x) tvos,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_tvos tvos,unavailable
   #define __API_DEPRECATED_PLATFORM_tvos(x,y) tvos,introduced=x,deprecated=y
   
   
   
   #define __API_AVAILABLE_PLATFORM_driverkit(x) driverkit,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_driverkit driverkit,unavailable
   #define __API_DEPRECATED_PLATFORM_driverkit(x,y) driverkit,introduced=x,deprecated=y
   #define __API_AVAILABLE_PLATFORM_xros(x) xros,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_xros xros,unavailable
   #define __API_DEPRECATED_PLATFORM_xros(x,y) xros,introduced=x,deprecated=y
   #define __API_AVAILABLE_PLATFORM_visionos(x) xros,introduced=x
   #define __API_UNAVAILABLE_PLATFORM_visionos xros,unavailable
   #define __API_DEPRECATED_PLATFORM_visionos(x,y) xros,introduced=x,deprecated=y
 #endif /* __has_attribute(availability) */
#endif /* defined(__has_feature) && defined(__has_attribute) */

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
    #define __API_AVAILABLE_GET_MACRO(_0,_1,_2,_3,_4,_5,_6,_7,NAME,...) NAME
    
    #define __API_A_BEGIN(x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_AVAILABLE_PLATFORM_##x))), apply_to = __API_APPLY_TO)))
    
    #define __API_AVAILABLE_BEGIN0(arg0) __API_A_BEGIN(arg0)
    #define __API_AVAILABLE_BEGIN1(arg0,arg1) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1)
    #define __API_AVAILABLE_BEGIN2(arg0,arg1,arg2) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2)
    #define __API_AVAILABLE_BEGIN3(arg0,arg1,arg2,arg3) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3)
    #define __API_AVAILABLE_BEGIN4(arg0,arg1,arg2,arg3,arg4) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4)
    #define __API_AVAILABLE_BEGIN5(arg0,arg1,arg2,arg3,arg4,arg5) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5)
    #define __API_AVAILABLE_BEGIN6(arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6)
    #define __API_AVAILABLE_BEGIN7(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_A_BEGIN(arg0) __API_A_BEGIN(arg1) __API_A_BEGIN(arg2) __API_A_BEGIN(arg3) __API_A_BEGIN(arg4) __API_A_BEGIN(arg5) __API_A_BEGIN(arg6) __API_A_BEGIN(arg7)
    #define __API_AVAILABLE_BEGIN_GET_MACRO(_0,_1,_2,_3,_4,_5,_6,_7,NAME,...) NAME

    

    #define __API_D(msg,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x,message=msg)))
  
    #define __API_DEPRECATED_MSG0(msg,arg0) __API_D(msg,arg0)
    #define __API_DEPRECATED_MSG1(msg,arg0,arg1) __API_D(msg,arg0) __API_D(msg,arg1)
    #define __API_DEPRECATED_MSG2(msg,arg0,arg1,arg2) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2)
    #define __API_DEPRECATED_MSG3(msg,arg0,arg1,arg2,arg3) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3)
    #define __API_DEPRECATED_MSG4(msg,arg0,arg1,arg2,arg3,arg4) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4)
    #define __API_DEPRECATED_MSG5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5)
    #define __API_DEPRECATED_MSG6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6)
    #define __API_DEPRECATED_MSG7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_D(msg,arg0) __API_D(msg,arg1) __API_D(msg,arg2) __API_D(msg,arg3) __API_D(msg,arg4) __API_D(msg,arg5) __API_D(msg,arg6) __API_D(msg,arg7)
    #define __API_DEPRECATED_MSG_GET_MACRO(_0,_1,_2,_3,_4,_5,_6,_7,_8,NAME,...) NAME

    #define __API_D_BEGIN(msg, x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x,message=msg))), apply_to = __API_APPLY_TO)))

    #define __API_DEPRECATED_BEGIN0(msg,arg0) __API_D_BEGIN(msg,arg0)
    #define __API_DEPRECATED_BEGIN1(msg,arg0,arg1) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1)
    #define __API_DEPRECATED_BEGIN2(msg,arg0,arg1,arg2) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2)
    #define __API_DEPRECATED_BEGIN3(msg,arg0,arg1,arg2,arg3) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3)
    #define __API_DEPRECATED_BEGIN4(msg,arg0,arg1,arg2,arg3,arg4) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4)
    #define __API_DEPRECATED_BEGIN5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5)
    #define __API_DEPRECATED_BEGIN6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6)
    #define __API_DEPRECATED_BEGIN7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_D_BEGIN(msg,arg0) __API_D_BEGIN(msg,arg1) __API_D_BEGIN(msg,arg2) __API_D_BEGIN(msg,arg3) __API_D_BEGIN(msg,arg4) __API_D_BEGIN(msg,arg5) __API_D_BEGIN(msg,arg6) __API_D_BEGIN(msg,arg7)
    #define __API_DEPRECATED_BEGIN_GET_MACRO(_0,_1,_2,_3,_4,_5,_6,_7,_8,NAME,...) NAME

    #if __has_feature(attribute_availability_with_replacement)
        #define __API_R(rep,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x,replacement=rep)))
    #else
        #define __API_R(rep,x) __attribute__((availability(__API_DEPRECATED_PLATFORM_##x)))
    #endif

    #define __API_DEPRECATED_REP0(msg,arg0) __API_R(msg,arg0)
    #define __API_DEPRECATED_REP1(msg,arg0,arg1) __API_R(msg,arg0) __API_R(msg,arg1)
    #define __API_DEPRECATED_REP2(msg,arg0,arg1,arg2) __API_R(msg,arg0) __API_R(msg,arg1) __API_R(msg,arg2)
    #define __API_DEPRECATED_REP3(msg,arg0,arg1,arg2,arg3) __API_R(msg,arg0) __API_R(msg,arg1) __API_R(msg,arg2) __API_R(msg,arg3)
    #define __API_DEPRECATED_REP4(msg,arg0,arg1,arg2,arg3,arg4) __API_R(msg,arg0) __API_R(msg,arg1) __API_R(msg,arg2) __API_R(msg,arg3) __API_R(msg,arg4)
    #define __API_DEPRECATED_REP5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_R(msg,arg0) __API_R(msg,arg1) __API_R(msg,arg2) __API_R(msg,arg3) __API_R(msg,arg4) __API_R(msg,arg5)
    #define __API_DEPRECATED_REP6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_R(msg,arg0) __API_R(msg,arg1) __API_R(msg,arg2) __API_R(msg,arg3) __API_R(msg,arg4) __API_R(msg,arg5) __API_R(msg,arg6)
    #define __API_DEPRECATED_REP7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_R(msg,arg0) __API_R(msg,arg1) __API_R(msg,arg2) __API_R(msg,arg3) __API_R(msg,arg4) __API_R(msg,arg5) __API_R(msg,arg6) __API_R(msg,arg7)
    #define __API_DEPRECATED_REP_GET_MACRO(_0,_1,_2,_3,_4,_5,_6,_7,_8,NAME,...) NAME

    #if __has_feature(attribute_availability_with_replacement)
        #define __API_R_BEGIN(rep,x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x,replacement=rep))), apply_to = __API_APPLY_TO)))    
    #else
        #define __API_R_BEGIN(rep,x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_DEPRECATED_PLATFORM_##x))), apply_to = __API_APPLY_TO)))    
    #endif

    #define __API_DEPRECATED_BEGIN_REP0(msg,arg0) __API_R_BEGIN(msg,arg0)
    #define __API_DEPRECATED_BEGIN_REP1(msg,arg0,arg1) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1)
    #define __API_DEPRECATED_BEGIN_REP2(msg,arg0,arg1,arg2) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2)
    #define __API_DEPRECATED_BEGIN_REP3(msg,arg0,arg1,arg2,arg3) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3)
    #define __API_DEPRECATED_BEGIN_REP4(msg,arg0,arg1,arg2,arg3,arg4) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4)
    #define __API_DEPRECATED_BEGIN_REP5(msg,arg0,arg1,arg2,arg3,arg4,arg5) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5)
    #define __API_DEPRECATED_BEGIN_REP6(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6)
    #define __API_DEPRECATED_BEGIN_REP7(msg,arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_R_BEGIN(msg,arg0) __API_R_BEGIN(msg,arg1) __API_R_BEGIN(msg,arg2) __API_R_BEGIN(msg,arg3) __API_R_BEGIN(msg,arg4) __API_R_BEGIN(msg,arg5) __API_R_BEGIN(msg,arg6) __API_R_BEGIN(msg,arg7)
    #define __API_DEPRECATED_BEGIN_REP_GET_MACRO(_0,_1,_2,_3,_4,_5,_6,_7,_8,NAME,...) NAME

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
    #define __API_UNAVAILABLE_GET_MACRO(_0,_1,_2,_3,_4,_5,_6,_7,NAME,...) NAME

    #define __API_U_BEGIN(x) _Pragma(__API_RANGE_STRINGIFY (clang attribute (__attribute__((availability(__API_UNAVAILABLE_PLATFORM_##x))), apply_to = __API_APPLY_TO)))

    #define __API_UNAVAILABLE_BEGIN0(arg0) __API_U_BEGIN(arg0)
    #define __API_UNAVAILABLE_BEGIN1(arg0,arg1) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1)
    #define __API_UNAVAILABLE_BEGIN2(arg0,arg1,arg2) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2)
    #define __API_UNAVAILABLE_BEGIN3(arg0,arg1,arg2,arg3) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3)
    #define __API_UNAVAILABLE_BEGIN4(arg0,arg1,arg2,arg3,arg4) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4)
    #define __API_UNAVAILABLE_BEGIN5(arg0,arg1,arg2,arg3,arg4,arg5) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5)
    #define __API_UNAVAILABLE_BEGIN6(arg0,arg1,arg2,arg3,arg4,arg5,arg6) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6)
    #define __API_UNAVAILABLE_BEGIN7(arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7) __API_U_BEGIN(arg0) __API_U_BEGIN(arg1) __API_U_BEGIN(arg2) __API_U_BEGIN(arg3) __API_U_BEGIN(arg4) __API_U_BEGIN(arg5) __API_U_BEGIN(arg6) __API_U_BEGIN(arg7)
    #define __API_UNAVAILABLE_BEGIN_GET_MACRO(_0,_1,_2,_3,_4,_5,_6,_7,NAME,...) NAME

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

/*
 * If __SPI_AVAILABLE has not been defined elsewhere, disable it.
 */
 
#ifndef __SPI_AVAILABLE
  #define __SPI_AVAILABLE(...)
#endif

#endif /* __AVAILABILITY_INTERNAL__ */
