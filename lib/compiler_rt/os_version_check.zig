const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .internal else .weak;
const panic = @import("common.zig").panic;

const have_availability_version_check = builtin.os.tag.isDarwin() and
    builtin.os.version_range.semver.min.order(.{ .major = 10, .minor = 15, .patch = 0 }).compare(.gte);

comptime {
    if (have_availability_version_check) {
        @export(__isPlatformVersionAtLeast, .{ .name = "__isPlatformVersionAtLeast", .linkage = linkage });
    }
}

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

const __isPlatformVersionAtLeast = if (have_availability_version_check) struct {
    inline fn constructVersion(major: u32, minor: u32, subminor: u32) u32 {
        return ((major & 0xffff) << 16) | ((minor & 0xff) << 8) | (subminor & 0xff);
    }

    // Darwin-only
    fn __isPlatformVersionAtLeast(platform: u32, major: u32, minor: u32, subminor: u32) callconv(.C) i32 {
        const build_version = dyld_build_version_t{
            .platform = platform,
            .version = constructVersion(major, minor, subminor),
        };
        return @intFromBool(_availability_version_check(1, &[_]dyld_build_version_t{build_version}));
    }

    // _availability_version_check darwin API support.
    const dyld_platform_t = u32;
    const dyld_build_version_t = extern struct {
        platform: dyld_platform_t,
        version: u32,
    };
    // Darwin-only
    extern "c" fn _availability_version_check(count: u32, versions: [*c]const dyld_build_version_t) bool;
}.__isPlatformVersionAtLeast else struct {};

test "isPlatformVersionAtLeast" {
    if (!have_availability_version_check) return error.SkipZigTest;

    // Note: this test depends on the actual host OS version since it is merely calling into the
    // native Darwin API.
    const macos_platform_constant = 1;
    try testing.expect(__isPlatformVersionAtLeast(macos_platform_constant, 10, 0, 15) == 1);
    try testing.expect(__isPlatformVersionAtLeast(macos_platform_constant, 99, 0, 0) == 0);
}
