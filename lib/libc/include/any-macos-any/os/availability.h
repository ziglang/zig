/*
 * Copyright (c) 2008-2017 Apple Inc. All rights reserved.
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */
 
#ifndef __OS_AVAILABILITY__
#define __OS_AVAILABILITY__

/* 
 * API_TO_BE_DEPRECATED is used as a version number in API that will be deprecated 
 * in an upcoming release. This soft deprecation is an intermediate step before formal 
 * deprecation to notify developers about the API before compiler warnings are generated.
 * You can find all places in your code that use soft deprecated API by redefining the 
 * value of this macro to your current minimum deployment target, for example:
 * (macOS)
 *   clang -DAPI_TO_BE_DEPRECATED=10.12 <other compiler flags>
 * (iOS)
 *   clang -DAPI_TO_BE_DEPRECATED=11.0 <other compiler flags>
 */
 
#ifndef API_TO_BE_DEPRECATED
#define API_TO_BE_DEPRECATED 100000
#endif

#ifndef API_TO_BE_DEPRECATED_MACOS
#define API_TO_BE_DEPRECATED_MACOS 100000
#endif

#ifndef API_TO_BE_DEPRECATED_IOS
#define API_TO_BE_DEPRECATED_IOS 100000
#endif

#ifndef API_TO_BE_DEPRECATED_TVOS
#define API_TO_BE_DEPRECATED_TVOS 100000
#endif

#ifndef API_TO_BE_DEPRECATED_WATCHOS
#define API_TO_BE_DEPRECATED_WATCHOS 100000
#endif

#ifndef __API_TO_BE_DEPRECATED_BRIDGEOS

#endif

#ifndef __API_TO_BE_DEPRECATED_MACCATALYST
#define __API_TO_BE_DEPRECATED_MACCATALYST 100000
#endif

#ifndef API_TO_BE_DEPRECATED_DRIVERKIT
#define API_TO_BE_DEPRECATED_DRIVERKIT 100000
#endif

#ifndef API_TO_BE_DEPRECATED_VISIONOS
#define API_TO_BE_DEPRECATED_VISIONOS 100000
#endif

#ifndef __OPEN_SOURCE__

#endif /* __OPEN_SOURCE__ */

#include <AvailabilityInternal.h>
#include <AvailabilityInternalLegacy.h>
#if __has_include(<AvailabilityInternalPrivate.h>)
  #include <AvailabilityInternalPrivate.h>
#endif



#if defined(__has_feature) && defined(__has_attribute)
 #if __has_attribute(availability)

    /*
     * API Introductions
     *
     * Use to specify the release that a particular API became available.
     *
     * Platform names:
     *   macos, macOSApplicationExtension, macCatalyst, macCatalystApplicationExtension,
     *   ios, iOSApplicationExtension, tvos, tvOSApplicationExtension, watchos,
     *   watchOSApplicationExtension, driverkit, visionos, visionOSApplicationExtension
     *
     * Examples:
     *    API_AVAILABLE(macos(10.10))
     *    API_AVAILABLE(macos(10.9), ios(10.0))
     *    API_AVAILABLE(macos(10.4), ios(8.0), watchos(2.0), tvos(10.0))
     *    API_AVAILABLE(driverkit(19.0))
     */

    #define API_AVAILABLE(...) __API_AVAILABLE_GET_MACRO_93585900(__VA_ARGS__,__API_AVAILABLE15,__API_AVAILABLE14,__API_AVAILABLE13,__API_AVAILABLE12,__API_AVAILABLE11,__API_AVAILABLE10,__API_AVAILABLE9,__API_AVAILABLE8,__API_AVAILABLE7,__API_AVAILABLE6,__API_AVAILABLE5,__API_AVAILABLE4,__API_AVAILABLE3,__API_AVAILABLE2,__API_AVAILABLE1,__API_AVAILABLE0,0)(__VA_ARGS__)
    #define API_AVAILABLE_BEGIN(...) _Pragma("clang attribute push") __API_AVAILABLE_BEGIN_GET_MACRO_93585900(__VA_ARGS__,__API_AVAILABLE_BEGIN15,__API_AVAILABLE_BEGIN14,__API_AVAILABLE_BEGIN13,__API_AVAILABLE_BEGIN12,__API_AVAILABLE_BEGIN11,__API_AVAILABLE_BEGIN10,__API_AVAILABLE_BEGIN9,__API_AVAILABLE_BEGIN8,__API_AVAILABLE_BEGIN7,__API_AVAILABLE_BEGIN6,__API_AVAILABLE_BEGIN5,__API_AVAILABLE_BEGIN4,__API_AVAILABLE_BEGIN3,__API_AVAILABLE_BEGIN2,__API_AVAILABLE_BEGIN1,__API_AVAILABLE_BEGIN0,0)(__VA_ARGS__)
    #define API_AVAILABLE_END _Pragma("clang attribute pop")

    /*
     * API Deprecations
     *
     * Use to specify the release that a particular API became deprecated.
     *
     * Platform names:
     *   macos, macOSApplicationExtension, macCatalyst, macCatalystApplicationExtension,
     *   ios, iOSApplicationExtension, tvos, tvOSApplicationExtension, watchos,
     *   watchOSApplicationExtension, driverkit, visionos, visionOSApplicationExtension
     *
     * Examples:
     *
     *    API_DEPRECATED("Deprecated", macos(10.4, 10.8))
     *    API_DEPRECATED("Deprecated", macos(10.4, 10.8), ios(2.0, 3.0), watchos(2.0, 3.0), tvos(9.0, 10.0))
     *
     *    API_DEPRECATED_WITH_REPLACEMENT("-setName:", tvos(10.0, 10.4), ios(9.0, 10.0))
     *    API_DEPRECATED_WITH_REPLACEMENT("SomeClassName", macos(10.4, 10.6), watchos(2.0, 3.0))
     */
     
    #define API_DEPRECATED(...) __API_DEPRECATED_MSG_GET_MACRO_93585900(__VA_ARGS__,__API_DEPRECATED_MSG15,__API_DEPRECATED_MSG14,__API_DEPRECATED_MSG13,__API_DEPRECATED_MSG12,__API_DEPRECATED_MSG11,__API_DEPRECATED_MSG10,__API_DEPRECATED_MSG9,__API_DEPRECATED_MSG8,__API_DEPRECATED_MSG7,__API_DEPRECATED_MSG6,__API_DEPRECATED_MSG5,__API_DEPRECATED_MSG4,__API_DEPRECATED_MSG3,__API_DEPRECATED_MSG2,__API_DEPRECATED_MSG1,__API_DEPRECATED_MSG0,0,0)(__VA_ARGS__)
    #define API_DEPRECATED_WITH_REPLACEMENT(...) __API_DEPRECATED_REP_GET_MACRO_93585900(__VA_ARGS__,__API_DEPRECATED_REP15,__API_DEPRECATED_REP14,__API_DEPRECATED_REP13,__API_DEPRECATED_REP12,__API_DEPRECATED_REP11,__API_DEPRECATED_REP10,__API_DEPRECATED_REP9,__API_DEPRECATED_REP8,__API_DEPRECATED_REP7,__API_DEPRECATED_REP6,__API_DEPRECATED_REP5,__API_DEPRECATED_REP4,__API_DEPRECATED_REP3,__API_DEPRECATED_REP2,__API_DEPRECATED_REP1,__API_DEPRECATED_REP0,0,0)(__VA_ARGS__)

    #define API_DEPRECATED_BEGIN(...) _Pragma("clang attribute push") __API_DEPRECATED_BEGIN_GET_MACRO_93585900(__VA_ARGS__,__API_DEPRECATED_BEGIN15,__API_DEPRECATED_BEGIN14,__API_DEPRECATED_BEGIN13,__API_DEPRECATED_BEGIN12,__API_DEPRECATED_BEGIN11,__API_DEPRECATED_BEGIN10,__API_DEPRECATED_BEGIN9,__API_DEPRECATED_BEGIN8,__API_DEPRECATED_BEGIN7,__API_DEPRECATED_BEGIN6,__API_DEPRECATED_BEGIN5,__API_DEPRECATED_BEGIN4,__API_DEPRECATED_BEGIN3,__API_DEPRECATED_BEGIN2,__API_DEPRECATED_BEGIN1,__API_DEPRECATED_BEGIN0,0,0)(__VA_ARGS__)
    #define API_DEPRECATED_END _Pragma("clang attribute pop")

    #define API_DEPRECATED_WITH_REPLACEMENT_BEGIN(...) _Pragma("clang attribute push") __API_DEPRECATED_WITH_REPLACEMENT_BEGIN_GET_MACRO_93585900(__VA_ARGS__,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN15,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN14,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN13,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN12,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN11,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN10,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN9,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN8,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN7,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN6,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN5,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN4,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN3,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN2,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN1,__API_DEPRECATED_WITH_REPLACEMENT_BEGIN0,0,0)(__VA_ARGS__)
    #define API_DEPRECATED_WITH_REPLACEMENT_END _Pragma("clang attribute pop")

    /*
     * API Obsoletions
     *
     * Use to specify the release that a particular API became unavailable.
     *
     * Platform names:
     *   macos, macOSApplicationExtension, macCatalyst, macCatalystApplicationExtension,
     *   ios, iOSApplicationExtension, tvos, tvOSApplicationExtension, watchos,
     *   watchOSApplicationExtension, driverkit, visionos, visionOSApplicationExtension
     *
     * Examples:
     *
     *    API_OBSOLETED("No longer supported", macos(10.4, 10.8, 11.0))
     *    API_OBSOLETED("No longer supported", macos(10.4, 10.8, 11.0), ios(2.0, 3.0, 4.0), watchos(2.0, 3.0, 4.0), tvos(9.0, 10.0, 11.0))
     *
     *    API_OBSOLETED_WITH_REPLACEMENT("-setName:", tvos(10.0, 10.4, 12.0), ios(9.0, 10.0, 11.0))
     *    API_OBSOLETED_WITH_REPLACEMENT("SomeClassName", macos(10.4, 10.6, 11.0), watchos(2.0, 3.0, 4.0))
     */
    #define API_OBSOLETED(...) __API_OBSOLETED_MSG_GET_MACRO_93585900(__VA_ARGS__,__API_OBSOLETED_MSG15,__API_OBSOLETED_MSG14,__API_OBSOLETED_MSG13,__API_OBSOLETED_MSG12,__API_OBSOLETED_MSG11,__API_OBSOLETED_MSG10,__API_OBSOLETED_MSG9,__API_OBSOLETED_MSG8,__API_OBSOLETED_MSG7,__API_OBSOLETED_MSG6,__API_OBSOLETED_MSG5,__API_OBSOLETED_MSG4,__API_OBSOLETED_MSG3,__API_OBSOLETED_MSG2,__API_OBSOLETED_MSG1,__API_OBSOLETED_MSG0,0,0)(__VA_ARGS__)
    #define API_OBSOLETED_WITH_REPLACEMENT(...) __API_OBSOLETED_REP_GET_MACRO_93585900(__VA_ARGS__,__API_OBSOLETED_REP15,__API_OBSOLETED_REP14,__API_OBSOLETED_REP13,__API_OBSOLETED_REP12,__API_OBSOLETED_REP11,__API_OBSOLETED_REP10,__API_OBSOLETED_REP9,__API_OBSOLETED_REP8,__API_OBSOLETED_REP7,__API_OBSOLETED_REP6,__API_OBSOLETED_REP5,__API_OBSOLETED_REP4,__API_OBSOLETED_REP3,__API_OBSOLETED_REP2,__API_OBSOLETED_REP1,__API_OBSOLETED_REP0,0,0)(__VA_ARGS__)

    #define API_OBSOLETED_BEGIN(...) _Pragma("clang attribute push") __API_OBSOLETED_BEGIN_GET_MACRO_93585900(__VA_ARGS__,__API_OBSOLETED_BEGIN15,__API_OBSOLETED_BEGIN14,__API_OBSOLETED_BEGIN13,__API_OBSOLETED_BEGIN12,__API_OBSOLETED_BEGIN11,__API_OBSOLETED_BEGIN10,__API_OBSOLETED_BEGIN9,__API_OBSOLETED_BEGIN8,__API_OBSOLETED_BEGIN7,__API_OBSOLETED_BEGIN6,__API_OBSOLETED_BEGIN5,__API_OBSOLETED_BEGIN4,__API_OBSOLETED_BEGIN3,__API_OBSOLETED_BEGIN2,__API_OBSOLETED_BEGIN1,__API_OBSOLETED_BEGIN0,0,0)(__VA_ARGS__)
    #define API_OBSOLETED_END _Pragma("clang attribute pop")

    #define API_OBSOLETED_WITH_REPLACEMENT_BEGIN(...) _Pragma("clang attribute push") __API_OBSOLETED_WITH_REPLACEMENT_BEGIN_GET_MACRO_93585900(__VA_ARGS__,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN15,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN14,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN13,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN12,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN11,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN10,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN9,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN8,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN7,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN6,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN5,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN4,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN3,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN2,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN1,__API_OBSOLETED_WITH_REPLACEMENT_BEGIN0,0,0)(__VA_ARGS__)
    #define API_OBSOLETED_WITH_REPLACEMENT_END _Pragma("clang attribute pop")

    /*
     * API Unavailability
     * Use to specify that an API is unavailable for a particular platform.
     *
     * Example:
     *    API_UNAVAILABLE(macos)
     *    API_UNAVAILABLE(watchos, tvos)
     */

    #define API_UNAVAILABLE(...) __API_UNAVAILABLE_GET_MACRO_93585900(__VA_ARGS__,__API_UNAVAILABLE15,__API_UNAVAILABLE14,__API_UNAVAILABLE13,__API_UNAVAILABLE12,__API_UNAVAILABLE11,__API_UNAVAILABLE10,__API_UNAVAILABLE9,__API_UNAVAILABLE8,__API_UNAVAILABLE7,__API_UNAVAILABLE6,__API_UNAVAILABLE5,__API_UNAVAILABLE4,__API_UNAVAILABLE3,__API_UNAVAILABLE2,__API_UNAVAILABLE1,__API_UNAVAILABLE0,0)(__VA_ARGS__)

    #define API_UNAVAILABLE_BEGIN(...) _Pragma("clang attribute push") __API_UNAVAILABLE_BEGIN_GET_MACRO_93585900(__VA_ARGS__,__API_UNAVAILABLE_BEGIN15,__API_UNAVAILABLE_BEGIN14,__API_UNAVAILABLE_BEGIN13,__API_UNAVAILABLE_BEGIN12,__API_UNAVAILABLE_BEGIN11,__API_UNAVAILABLE_BEGIN10,__API_UNAVAILABLE_BEGIN9,__API_UNAVAILABLE_BEGIN8,__API_UNAVAILABLE_BEGIN7,__API_UNAVAILABLE_BEGIN6,__API_UNAVAILABLE_BEGIN5,__API_UNAVAILABLE_BEGIN4,__API_UNAVAILABLE_BEGIN3,__API_UNAVAILABLE_BEGIN2,__API_UNAVAILABLE_BEGIN1,__API_UNAVAILABLE_BEGIN0,0)(__VA_ARGS__)
    #define API_UNAVAILABLE_END _Pragma("clang attribute pop")
 #endif /* __has_attribute(availability) */
#endif /* #if defined(__has_feature) && defined(__has_attribute) */

/* 
 * Evaluate to nothing for compilers that don't support clang language extensions.
 */

#ifndef API_AVAILABLE
  #define API_AVAILABLE(...)
#endif

#ifndef API_AVAILABLE_BEGIN
  #define API_AVAILABLE_BEGIN(...)
#endif

#ifndef API_AVAILABLE_END
  #define API_AVAILABLE_END(...)
#endif

#ifndef API_DEPRECATED
  #define API_DEPRECATED(...)
#endif

#ifndef API_DEPRECATED_BEGIN
  #define API_DEPRECATED_BEGIN(...)
#endif

#ifndef API_DEPRECATED_END
  #define API_DEPRECATED_END(...)
#endif

#ifndef API_DEPRECATED_WITH_REPLACEMENT
  #define API_DEPRECATED_WITH_REPLACEMENT(...)
#endif

#ifndef API_DEPRECATED_WITH_REPLACEMENT_BEGIN
  #define API_DEPRECATED_WITH_REPLACEMENT_BEGIN(...)
#endif

#ifndef API_DEPRECATED_WITH_REPLACEMENT_END
  #define API_DEPRECATED_WITH_REPLACEMENT_END(...)
#endif

#ifndef API_OBSOLETED
  #define API_OBSOLETED(...)
#endif

#ifndef API_OBSOLETED_BEGIN
  #define API_OBSOLETED_BEGIN(...)
#endif

#ifndef API_OBSOLETED_END
  #define API_OBSOLETED_END(...)
#endif

#ifndef API_OBSOLETED_WITH_REPLACEMENT
  #define API_OBSOLETED_WITH_REPLACEMENT(...)
#endif

#ifndef API_OBSOLETED_WITH_REPLACEMENT_BEGIN
  #define API_OBSOLETED_WITH_REPLACEMENT_BEGIN(...)
#endif

#ifndef API_OBSOLETED_WITH_REPLACEMENT_END
  #define API_OBSOLETED_WITH_REPLACEMENT_END(...)
#endif

#ifndef API_UNAVAILABLE
  #define API_UNAVAILABLE(...)
#endif

#ifndef API_UNAVAILABLE_BEGIN
  #define API_UNAVAILABLE_BEGIN(...)
#endif

#ifndef API_UNAVAILABLE_END
  #define API_UNAVAILABLE_END(...)
#endif

#if __has_include(<AvailabilityProhibitedInternal.h>)
  #include <AvailabilityProhibitedInternal.h>
#endif

/*
 * If SPI decorations have not been defined elsewhere, disable them.
 */

#ifndef SPI_AVAILABLE
  #define SPI_AVAILABLE(...)
#endif

#ifndef SPI_AVAILABLE_BEGIN
  #define SPI_AVAILABLE_BEGIN(...)
#endif

#ifndef SPI_AVAILABLE_END
  #define SPI_AVAILABLE_END(...)
#endif

#ifndef SPI_DEPRECATED
  #define SPI_DEPRECATED(...)
#endif

#ifndef SPI_DEPRECATED_WITH_REPLACEMENT
  #define SPI_DEPRECATED_WITH_REPLACEMENT(...)
#endif

#endif /* __OS_AVAILABILITY__ */

#ifndef __OPEN_SOURCE__
// This is explicitly outside the header guard
#ifndef __AVAILABILITY_VERSIONS_VERSION_HASH
#define __AVAILABILITY_VERSIONS_VERSION_HASH 93585900U
#define __AVAILABILITY_VERSIONS_VERSION_STRING "Local"
#define __AVAILABILITY_FILE "os/availability.h"
#elif __AVAILABILITY_VERSIONS_VERSION_HASH != 93585900U
#pragma GCC error "Already found AvailabilityVersions version " __AVAILABILITY_FILE " from " __AVAILABILITY_VERSIONS_VERSION_STRING ", which is incompatible with os/availability.h from Local. Mixing and matching Availability from different SDKs is not supported"
#endif /* __AVAILABILITY_VERSIONS_VERSION_HASH */
#endif /* __OPEN_SOURCE__ */
