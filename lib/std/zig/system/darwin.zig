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
    const result = std.process.Child.exec(.{
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
/// Calls `xcrun --sdk <target_sdk> --show-sdk-path` which fetches the path to the SDK sysroot (if any).
/// Subsequently calls `xcrun --sdk <target_sdk> --show-sdk-version` which fetches version of the SDK.
/// The caller needs to deinit the resulting struct.
/// stderr from xcrun is ignored.
/// If error.OutOfMemory occurs in Allocator, this function returns null.
pub fn getSdk(allocator: Allocator, target: Target) ?Sdk {
    const is_simulator_abi = target.abi == .simulator;
    const sdk = switch (target.os.tag) {
        .macos => "macosx",
        .ios => if (is_simulator_abi) "iphonesimulator" else "iphoneos",
        .watchos => if (is_simulator_abi) "watchsimulator" else "watchos",
        .tvos => if (is_simulator_abi) "appletvsimulator" else "appletvos",
        else => return null,
    };
    const path = path: {
        const argv = &[_][]const u8{ "/usr/bin/xcrun", "--sdk", sdk, "--show-sdk-path" };
        const result = std.process.Child.exec(.{ .allocator = allocator, .argv = argv }) catch return null;
        defer {
            allocator.free(result.stderr);
            allocator.free(result.stdout);
        }
        switch (result.term) {
            .Exited => |code| if (code != 0) return null,
            else => return null,
        }
        const path = allocator.dupe(u8, mem.trimRight(u8, result.stdout, "\r\n")) catch return null;
        break :path path;
    };
    const version = version: {
        const argv = &[_][]const u8{ "/usr/bin/xcrun", "--sdk", sdk, "--show-sdk-version" };
        const result = std.process.Child.exec(.{ .allocator = allocator, .argv = argv }) catch return null;
        defer {
            allocator.free(result.stderr);
            allocator.free(result.stdout);
        }
        switch (result.term) {
            .Exited => |code| if (code != 0) return null,
            else => return null,
        }
        const raw_version = mem.trimRight(u8, result.stdout, "\r\n");
        const version = parseSdkVersion(raw_version) orelse Version{
            .major = 0,
            .minor = 0,
            .patch = 0,
        };
        break :version version;
    };
    return Sdk{
        .path = path,
        .version = version,
    };
}

// Versions reported by Apple aren't exactly semantically valid as they usually omit
// the patch component. Hence, we do a simple check for the number of components and
// add the missing patch value if needed.
fn parseSdkVersion(raw: []const u8) ?Version {
    var buffer: [128]u8 = undefined;
    if (raw.len > buffer.len) return null;
    @memcpy(buffer[0..raw.len], raw);
    const dots_count = mem.count(u8, raw, ".");
    if (dots_count < 1) return null;
    const len = if (dots_count < 2) blk: {
        const patch_suffix = ".0";
        buffer[raw.len..][0..patch_suffix.len].* = patch_suffix.*;
        break :blk raw.len + patch_suffix.len;
    } else raw.len;
    return Version.parse(buffer[0..len]) catch null;
}

pub const Sdk = struct {
    path: []const u8,
    version: Version,

    pub fn deinit(self: Sdk, allocator: Allocator) void {
        allocator.free(self.path);
    }
};

test {
    _ = macos;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn testParseSdkVersionSuccess(exp: Version, raw: []const u8) !void {
    const maybe_ver = parseSdkVersion(raw);
    try expect(maybe_ver != null);
    const ver = maybe_ver.?;
    try expectEqual(exp.major, ver.major);
    try expectEqual(exp.minor, ver.minor);
    try expectEqual(exp.patch, ver.patch);
}

test "parseSdkVersion" {
    try testParseSdkVersionSuccess(.{ .major = 13, .minor = 4, .patch = 0 }, "13.4");
    try testParseSdkVersionSuccess(.{ .major = 13, .minor = 4, .patch = 1 }, "13.4.1");
    try testParseSdkVersionSuccess(.{ .major = 11, .minor = 15, .patch = 0 }, "11.15");

    try expect(parseSdkVersion("11") == null);
}
