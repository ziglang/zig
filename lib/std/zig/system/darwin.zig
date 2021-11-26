const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Target = std.Target;
const Version = std.builtin.Version;

pub const macos = @import("darwin/macos.zig");

/// Detect SDK on Darwin.
/// Calls `xcrun --sdk <target_sdk> --show-sdk-path` which fetches the path to the SDK sysroot (if any).
/// Subsequently calls `xcrun --sdk <target_sdk> --show-sdk-version` which fetches version of the SDK.
/// The caller needs to deinit the resulting struct.
pub fn getDarwinSDK(allocator: *Allocator, target: Target) !?DarwinSDK {
    const is_simulator_abi = target.abi == .simulator;
    const sdk = switch (target.os.tag) {
        .macos => "macosx",
        .ios => if (is_simulator_abi) "iphonesimulator" else "iphoneos",
        .watchos => if (is_simulator_abi) "watchsimulator" else "watchos",
        .tvos => if (is_simulator_abi) "appletvsimulator" else "appletvos",
        else => return null,
    };
    const path = path: {
        const argv = &[_][]const u8{ "xcrun", "--sdk", sdk, "--show-sdk-path" };
        const result = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = argv });
        defer {
            allocator.free(result.stderr);
            allocator.free(result.stdout);
        }
        if (result.stderr.len != 0 or result.term.Exited != 0) {
            // We don't actually care if there were errors as this is best-effort check anyhow
            // and in the worst case the user can specify the sysroot manually.
            return null;
        }
        const path = try allocator.dupe(u8, mem.trimRight(u8, result.stdout, "\r\n"));
        break :path path;
    };
    const version = version: {
        const argv = &[_][]const u8{ "xcrun", "--sdk", sdk, "--show-sdk-version" };
        const result = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = argv });
        defer {
            allocator.free(result.stderr);
            allocator.free(result.stdout);
        }
        if (result.stderr.len != 0 or result.term.Exited != 0) {
            // We don't actually care if there were errors as this is best-effort check anyhow
            // and in the worst case the user can specify the sysroot manually.
            return null;
        }
        const raw_version = mem.trimRight(u8, result.stdout, "\r\n");
        const version = Version.parse(raw_version) catch Version{
            .major = 0,
            .minor = 0,
        };
        break :version version;
    };
    return DarwinSDK{
        .path = path,
        .version = version,
    };
}

pub const DarwinSDK = struct {
    path: []const u8,
    version: Version,

    pub fn deinit(self: DarwinSDK, allocator: *Allocator) void {
        allocator.free(self.path);
    }
};

test "" {
    _ = @import("darwin/macos.zig");
}
