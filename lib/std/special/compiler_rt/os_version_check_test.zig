const __isPlatformVersionAtLeast = @import("os_version_check.zig").__isPlatformVersionAtLeast;
const testing = @import("std").testing;

test "isPlatformVersionAtLeast" {
    // Note: this test depends on the actual host OS version since it is merely calling into the
    // native Darwin API.
    const macos_platform_constant = 1;
    try testing.expect(__isPlatformVersionAtLeast(macos_platform_constant, 10, 0, 15) == 1);
    try testing.expect(__isPlatformVersionAtLeast(macos_platform_constant, 99, 0, 0) == 0);
}
