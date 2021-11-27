const testing = @import("std").testing;

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
// our implementation differs by simply removing that backwards compatability support. We only use
// the newer codepath, which merely calls out to the Darwin _availability_version_check API which is
// available on macOS 10.15+, iOS 13+, tvOS 13+ and watchOS 6+.

inline fn constructVersion(major: u32, minor: u32, subminor: u32) u32 {
    return ((major & 0xffff) << 16) | ((minor & 0xff) << 8) | (subminor & 0xff);
}

// Darwin-only
pub fn __isPlatformVersionAtLeast(platform: u32, major: u32, minor: u32, subminor: u32) callconv(.C) i32 {
    return if (_availability_version_check(1, &[_]dyld_build_version_t{
        .{ .platform = platform, .version = constructVersion(major, minor, subminor) },
    })) 1 else 0;
}

// TODO(future): If anyone wishes to build Objective-C code for Android, we would need to port this
// logic.
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

// int32_t __isPlatformVersionAtLeast(int32_t Major, int32_t Minor, int32_t Subminor) {
//   (int32_t) Minor;
//   (int32_t) Subminor;
//   static pthread_once_t once = PTHREAD_ONCE_INIT;
//   pthread_once(&once, readSystemProperties);

//   return SdkVersion >= Major ||
//          (IsPreRelease && Major == __ANDROID_API_FUTURE__);
// }

// #endif

// _availability_version_check darwin API support.
const dyld_platform_t = u32;
const dyld_build_version_t = extern struct {
    platform: dyld_platform_t,
    version: u32,
};
// Darwin-only
extern "c" fn _availability_version_check(count: u32, versions: [*c]const dyld_build_version_t) bool;

test "isPlatformVersionAtLeast" {
    // Note: this test depends on the actual host OS version since it is merely calling into the
    // native Darwin API.
    const macos_platform_constant = 1;
    try testing.expect(__isPlatformVersionAtLeast(macos_platform_constant, 10, 0, 15) == 1);
    try testing.expect(__isPlatformVersionAtLeast(macos_platform_constant, 99, 0, 0) == 0);
}
