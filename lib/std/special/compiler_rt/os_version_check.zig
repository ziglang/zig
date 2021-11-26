// Ported from llvm-project 13.0.0 d7b669b3a30345cfcdb2fde2af6f48aa4b94845d
//
// https://github.com/llvm/llvm-project/blob/llvmorg-13.0.0/compiler-rt/lib/builtins/os_version_check.c

// The compiler generates calls to __isPlatformVersionAtLeast() when Objective-C's @available
// function is invoked.
//
// Old versions of clang would instead emit calls to __isOSVersionAtLeast(), which is still
// supported in clang's compiler-rt implementation today in case anyone tries to link an object file
// produced with an old clang version. This requires dynamically loading frameworks, parsing a
// system plist file, and generally adds a fair amount of complexity to the implementation and so
// our implementation differs by simply removing that backwards compatability support. This means
// our implementation uses only the newer codepath which merely shells out to the Darwin
// _availability_version_check API which is available on macOS 10.15+, iOS 13+, tvOS 13+ and
// watchOS 6+.

// #ifdef __APPLE__

// #include <TargetConditionals.h>
// #include <dispatch/dispatch.h>
// #include <dlfcn.h>
// #include <stdint.h>
// #include <stdio.h>
// #include <stdlib.h>
// #include <string.h>

// static dispatch_once_t DispatchOnceCounter;

// // _availability_version_check darwin API support.
// typedef uint32_t dyld_platform_t;

// typedef struct {
//   dyld_platform_t platform;
//   uint32_t version;
// } dyld_build_version_t;

// typedef bool (*AvailabilityVersionCheckFuncTy)(uint32_t count,
//                                                dyld_build_version_t versions[]);

// static AvailabilityVersionCheckFuncTy AvailabilityVersionCheck;

// static void initializeAvailabilityCheck(void *Unused) {
//   (void)Unused;
//   // Use the new API if it's is available.
//   AvailabilityVersionCheck = (AvailabilityVersionCheckFuncTy)dlsym(
//       RTLD_DEFAULT, "_availability_version_check");
//
//   // TODO: panic if AvailabilityVersionCheck == NULL
// }

// static inline uint32_t ConstructVersion(uint32_t Major, uint32_t Minor,
//                                         uint32_t Subminor) {
//   return ((Major & 0xffff) << 16) | ((Minor & 0xff) << 8) | (Subminor & 0xff);
// }

// int32_t __isPlatformVersionAtLeast(uint32_t Platform, uint32_t Major,
//                                    uint32_t Minor, uint32_t Subminor) {
//   dispatch_once_f(&DispatchOnceCounter, NULL, initializeAvailabilityCheck);

//   dyld_build_version_t Versions[] = {
//       {Platform, ConstructVersion(Major, Minor, Subminor)}};
//   return AvailabilityVersionCheck(1, Versions);
// }

// #elif __ANDROID__

// #include <pthread.h>
// #include <stdlib.h>
// #include <string.h>
// #include <sys/system_properties.h>

// static int SdkVersion;
// static int IsPreRelease;

// static void readSystemProperties(void) {
//   char buf[PROP_VALUE_MAX];

//   if (__system_property_get("ro.build.version.sdk", buf) == 0) {
//     // When the system property doesn't exist, defaults to future API level.
//     SdkVersion = __ANDROID_API_FUTURE__;
//   } else {
//     SdkVersion = atoi(buf);
//   }

//   if (__system_property_get("ro.build.version.codename", buf) == 0) {
//     IsPreRelease = 1;
//   } else {
//     IsPreRelease = strcmp(buf, "REL") != 0;
//   }
//   return;
// }

// int32_t __isOSVersionAtLeast(int32_t Major, int32_t Minor, int32_t Subminor) {
//   (int32_t) Minor;
//   (int32_t) Subminor;
//   static pthread_once_t once = PTHREAD_ONCE_INIT;
//   pthread_once(&once, readSystemProperties);

//   return SdkVersion >= Major ||
//          (IsPreRelease && Major == __ANDROID_API_FUTURE__);
// }

// #else

// // Silence an empty translation unit warning.
// typedef int unused;

// #endif
