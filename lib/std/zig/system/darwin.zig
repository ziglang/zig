const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Target = std.Target;
const Version = std.SemanticVersion;

pub const macos = @import("darwin/macos.zig");

/// Check if SDK is installed on Darwin without triggering CLT installation popup window.
/// Note: simply invoking `xcrun` will inevitably trigger the CLT installation popup.
/// Therefore, we resort to invoking `xcode-select --print-path` and checking
/// if the status is nonzero.
/// stderr from xcode-select is ignored.
/// If error.OutOfMemory occurs in Allocator, this function returns null.
pub fn isSdkInstalled(allocator: Allocator) bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "/usr/bin/xcode-select", "--print-path" },
    }) catch return false;

    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }

    return switch (result.term) {
        .Exited => |code| if (code == 0) result.stdout.len > 0 else false,
        else => false,
    };
}

/// Detect SDK on Darwin.
/// Calls `xcrun --sdk <target_sdk> --show-sdk-path` which fetches the path to the SDK.
/// Caller owns the memory.
/// stderr from xcrun is ignored.
/// If error.OutOfMemory occurs in Allocator, this function returns null.
pub fn getSdk(allocator: Allocator, target: Target) ?[]const u8 {
    const is_simulator_abi = target.abi == .simulator;
    const sdk = switch (target.os.tag) {
        .macos => "macosx",
        .ios => switch (target.abi) {
            .simulator => "iphonesimulator",
            .macabi => "macosx",
            else => "iphoneos",
        },
        .watchos => if (is_simulator_abi) "watchsimulator" else "watchos",
        .tvos => if (is_simulator_abi) "appletvsimulator" else "appletvos",
        else => return null,
    };
    const argv = &[_][]const u8{ "/usr/bin/xcrun", "--sdk", sdk, "--show-sdk-path" };
    const result = std.process.Child.run(.{ .allocator = allocator, .argv = argv }) catch return null;
    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }
    switch (result.term) {
        .Exited => |code| if (code != 0) return null,
        else => return null,
    }
    return allocator.dupe(u8, mem.trimRight(u8, result.stdout, "\r\n")) catch null;
}

test {
    _ = macos;
}
