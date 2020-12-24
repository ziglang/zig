#ifndef __XPC_AVAILABILITY_H__
#define __XPC_AVAILABILITY_H__

#include <Availability.h>

// Certain parts of the project use all the project's headers but have to build
// against newer OSX SDKs than ebuild uses -- liblaunch_host being the example.
// So we need to define these.
#ifndef __MAC_10_16
#define __MAC_10_16 101600
#endif // __MAC_10_16

#ifndef __MAC_10_15
#define __MAC_10_15 101500
#define __AVAILABILITY_INTERNAL__MAC_10_15 \
__attribute__((availability(macosx, introduced=10.15)))
#endif // __MAC_10_15

#ifndef __MAC_10_14
#define __MAC_10_14 101400
#define __AVAILABILITY_INTERNAL__MAC_10_14 \
__attribute__((availability(macosx, introduced=10.14)))
#endif // __MAC_10_14

#ifndef __MAC_10_13
#define __MAC_10_13 101300
#define __AVAILABILITY_INTERNAL__MAC_10_13 \
	__attribute__((availability(macosx, introduced=10.13)))
#endif // __MAC_10_13

#ifndef __MAC_10_12
#define __MAC_10_12 101200
#define __AVAILABILITY_INTERNAL__MAC_10_12 \
	__attribute__((availability(macosx, introduced=10.12)))
#endif // __MAC_10_12

#ifndef __MAC_10_11
#define __MAC_10_11 101100
#define __AVAILABILITY_INTERNAL__MAC_10_11 \
	__attribute__((availability(macosx, introduced=10.11)))
#endif // __MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11
#endif // __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11

#ifndef __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_13
#define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_13
#endif // __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_13

#if __has_include(<simulator_host.h>)
#include <simulator_host.h>
#else // __has_include(<simulator_host.h>)
#ifndef IPHONE_SIMULATOR_HOST_MIN_VERSION_REQUIRED
#define IPHONE_SIMULATOR_HOST_MIN_VERSION_REQUIRED 999999
#endif // IPHONE_SIMULATOR_HOST_MIN_VERSION_REQUIRED
#endif // __has_include(<simulator_host.h>)

#ifndef __WATCHOS_UNAVAILABLE
#define __WATCHOS_UNAVAILABLE
#endif

#ifndef __TVOS_UNAVAILABLE
#define __TVOS_UNAVAILABLE
#endif

// simulator host-side bits build against SDKs not having __*_AVAILABLE() yet
#ifndef __OSX_AVAILABLE
#define __OSX_AVAILABLE(...)
#endif

#ifndef __IOS_AVAILABLE
#define __IOS_AVAILABLE(...)
#endif

#ifndef __TVOS_AVAILABLE
#define __TVOS_AVAILABLE(...)
#endif

#ifndef __WATCHOS_AVAILABLE
#define __WATCHOS_AVAILABLE(...)
#endif

#ifndef __API_AVAILABLE
#define __API_AVAILABLE(...)
#endif

#endif // __XPC_AVAILABILITY_H__