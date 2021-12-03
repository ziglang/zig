pub const NativePaths = @import("system/NativePaths.zig");
pub const NativeTargetInfo = @import("system/NativeTargetInfo.zig");

pub const windows = @import("system/windows.zig");
pub const darwin = @import("system/darwin.zig");
pub const linux = @import("system/linux.zig");

test {
    _ = NativePaths;
    _ = NativeTargetInfo;

    _ = darwin;
    _ = linux;
    _ = windows;
}
