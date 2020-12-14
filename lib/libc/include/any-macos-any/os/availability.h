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

#include <AvailabilityInternal.h>



#if defined(__has_feature) && defined(__has_attribute)
 #if __has_attribute(availability)

    /*
     * API Introductions
     *
     * Use to specify the release that a particular API became available.
     *
     * Platform names:
     *   macos, ios, tvos, watchos
     *
     * Examples:
     *    API_AVAILABLE(macos(10.10))
     *    API_AVAILABLE(macos(10.9), ios(10.0))
     *    API_AVAILABLE(macos(10.4), ios(8.0), watchos(2.0), tvos(10.0))
     */

    #define API_AVAILABLE(...) __API_AVAILABLE_GET_MACRO(__VA_ARGS__,__API_AVAILABLE7, __API_AVAILABLE6, __API_AVAILABLE5, __API_AVAILABLE4, __API_AVAILABLE3, __API_AVAILABLE2, __API_AVAILABLE1, 0)(__VA_ARGS__)

    #define API_AVAILABLE_BEGIN(...) _Pragma("clang attribute push") __API_AVAILABLE_BEGIN_GET_MACRO(__VA_ARGS__,__API_AVAILABLE_BEGIN7,__API_AVAILABLE_BEGIN6, __API_AVAILABLE_BEGIN5, __API_AVAILABLE_BEGIN4, __API_AVAILABLE_BEGIN3, __API_AVAILABLE_BEGIN2, __API_AVAILABLE_BEGIN1, 0)(__VA_ARGS__)
    #define API_AVAILABLE_END _Pragma("clang attribute pop")

    /*
     * API Deprecations
     *
     * Use to specify the release that a particular API became unavailable.
     *
     * Platform names:
     *   macos, ios, tvos, watchos
     *
     * Examples:
     *
     *    API_DEPRECATED("No longer supported", macos(10.4, 10.8))
     *    API_DEPRECATED("No longer supported", macos(10.4, 10.8), ios(2.0, 3.0), watchos(2.0, 3.0), tvos(9.0, 10.0))
     *
     *    API_DEPRECATED_WITH_REPLACEMENT("-setName:", tvos(10.0, 10.4), ios(9.0, 10.0))
     *    API_DEPRECATED_WITH_REPLACEMENT("SomeClassName", macos(10.4, 10.6), watchos(2.0, 3.0))
     */

    #define API_DEPRECATED(...) __API_DEPRECATED_MSG_GET_MACRO(__VA_ARGS__,__API_DEPRECATED_MSG8,__API_DEPRECATED_MSG7, __API_DEPRECATED_MSG6,__API_DEPRECATED_MSG5,__API_DEPRECATED_MSG4,__API_DEPRECATED_MSG3,__API_DEPRECATED_MSG2,__API_DEPRECATED_MSG1, 0)(__VA_ARGS__)
    #define API_DEPRECATED_WITH_REPLACEMENT(...) __API_DEPRECATED_REP_GET_MACRO(__VA_ARGS__,__API_DEPRECATED_REP8,__API_DEPRECATED_REP7, __API_DEPRECATED_REP6,__API_DEPRECATED_REP5,__API_DEPRECATED_REP4,__API_DEPRECATED_REP3,__API_DEPRECATED_REP2,__API_DEPRECATED_REP1, 0)(__VA_ARGS__)

    #define API_DEPRECATED_BEGIN(...) _Pragma("clang attribute push") __API_DEPRECATED_BEGIN_MSG_GET_MACRO(__VA_ARGS__,__API_DEPRECATED_BEGIN_MSG8,__API_DEPRECATED_BEGIN_MSG7, __API_DEPRECATED_BEGIN_MSG6, __API_DEPRECATED_BEGIN_MSG5, __API_DEPRECATED_BEGIN_MSG4, __API_DEPRECATED_BEGIN_MSG3, __API_DEPRECATED_BEGIN_MSG2, __API_DEPRECATED_BEGIN_MSG1, 0)(__VA_ARGS__)
    #define API_DEPRECATED_END _Pragma("clang attribute pop")

    #define API_DEPRECATED_WITH_REPLACEMENT_BEGIN(...) _Pragma("clang attribute push") __API_DEPRECATED_BEGIN_REP_GET_MACRO(__VA_ARGS__,__API_DEPRECATED_BEGIN_REP8,__API_DEPRECATED_BEGIN_REP7, __API_DEPRECATED_BEGIN_REP6, __API_DEPRECATED_BEGIN_REP5, __API_DEPRECATED_BEGIN_REP4, __API_DEPRECATED_BEGIN_REP3, __API_DEPRECATED_BEGIN_REP2, __API_DEPRECATED_BEGIN_REP1, 0)(__VA_ARGS__)
    #define API_DEPRECATED_WITH_REPLACEMENT_END _Pragma("clang attribute pop")


    /*
     * API Unavailability
     * Use to specify that an API is unavailable for a particular platform.
     *
     * Example:
     *    API_UNAVAILABLE(macos)
     *    API_UNAVAILABLE(watchos, tvos)
     */

    #define API_UNAVAILABLE(...) __API_UNAVAILABLE_GET_MACRO(__VA_ARGS__,__API_UNAVAILABLE7,__API_UNAVAILABLE6, __API_UNAVAILABLE5, __API_UNAVAILABLE4,__API_UNAVAILABLE3,__API_UNAVAILABLE2,__API_UNAVAILABLE1, 0)(__VA_ARGS__)

    #define API_UNAVAILABLE_BEGIN(...) _Pragma("clang attribute push") __API_UNAVAILABLE_BEGIN_GET_MACRO(__VA_ARGS__,__API_UNAVAILABLE_BEGIN7,__API_UNAVAILABLE_BEGIN6, __API_UNAVAILABLE_BEGIN5, __API_UNAVAILABLE_BEGIN4, __API_UNAVAILABLE_BEGIN3, __API_UNAVAILABLE_BEGIN2, __API_UNAVAILABLE_BEGIN1, 0)(__VA_ARGS__)
    #define API_UNAVAILABLE_END _Pragma("clang attribute pop")
 #else

    /* 
     * Evaluate to nothing for compilers that don't support availability.
     */
   
     #define API_AVAILABLE(...)
     #define API_AVAILABLE_BEGIN(...)
     #define API_AVAILABLE_END
     #define API_DEPRECATED(...)
     #define API_DEPRECATED_WITH_REPLACEMENT(...)
     #define API_DEPRECATED_BEGIN(...)
     #define API_DEPRECATED_END
     #define API_DEPRECATED_WITH_REPLACEMENT_BEGIN(...)
     #define API_DEPRECATED_WITH_REPLACEMENT_END
     #define API_UNAVAILABLE(...)
     #define API_UNAVAILABLE_BEGIN(...)
     #define API_UNAVAILABLE_END
 #endif /* __has_attribute(availability) */
#else

    /* 
     * Evaluate to nothing for compilers that don't support clang language extensions.
     */

    #define API_AVAILABLE(...)
    #define API_AVAILABLE_BEGIN(...)
    #define API_AVAILABLE_END
    #define API_DEPRECATED(...)
    #define API_DEPRECATED_WITH_REPLACEMENT(...)
    #define API_DEPRECATED_BEGIN(...)
    #define API_DEPRECATED_END
    #define API_DEPRECATED_WITH_REPLACEMENT_BEGIN(...)
    #define API_DEPRECATED_WITH_REPLACEMENT_END
    #define API_UNAVAILABLE(...)
    #define API_UNAVAILABLE_BEGIN(...)
    #define API_UNAVAILABLE_END
#endif /* #if defined(__has_feature) && defined(__has_attribute) */

#if __has_include(<AvailabilityProhibitedInternal.h>)
  #include <AvailabilityProhibitedInternal.h>
#endif

/*
 * If SPI decorations have not been defined elsewhere, disable them.
 */

#ifndef SPI_AVAILABLE
  #define SPI_AVAILABLE(...)
#endif

#ifndef SPI_DEPRECATED
  #define SPI_DEPRECATED(...)
#endif

#ifndef SPI_DEPRECATED_WITH_REPLACEMENT
  #define SPI_DEPRECATED_WITH_REPLACEMENT(...)
#endif

#endif /* __OS_AVAILABILITY__ */