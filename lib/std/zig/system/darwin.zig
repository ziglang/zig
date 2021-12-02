const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Target = std.Target;
const Version = std.builtin.Version;

pub const macos = @import("darwin/macos.zig");

/// Check if SDK is installed on Darwin without triggering CLT installation popup window.
/// Note: simply invoking `xcrun` will inevitably trigger the CLT installation popup.
/// Therefore, we resort to the same tool used by Homebrew, namely, invoking `xcode-select --print-path`
/// and checking if the status is nonzero or the returned string in nonempty.
/// https://github.com/Homebrew/brew/blob/e119bdc571dcb000305411bc1e26678b132afb98/Library/Homebrew/brew.sh#L630
pub fn isDarwinSDKInstalled(allocator: Allocator) bool {
    const argv = &[_][]const u8{ "/usr/bin/xcode-select", "--print-path" };
    const result = std.ChildProcess.exec(.{ .allocator = allocator, .argv = argv }) catch return false;
    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }
    if (result.stderr.len != 0 or result.term.Exited != 0) {
        // We don't actually care if there were errors as this is best-effort check anyhow.
        return false;
    }
    return result.stdout.len > 0;
}

/// Detect SDK on Darwin.
/// Calls `xcrun --sdk <target_sdk> --show-sdk-path` which fetches the path to the SDK sysroot (if any).
/// Subsequently calls `xcrun --sdk <target_sdk> --show-sdk-version` which fetches version of the SDK.
/// The caller needs to deinit the resulting struct.
pub fn getDarwinSDK(allocator: Allocator, target: Target) ?DarwinSDK {
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
        const result = std.ChildProcess.exec(.{ .allocator = allocator, .argv = argv }) catch return null;
        defer {
            allocator.free(result.stderr);
            allocator.free(result.stdout);
        }
        if (result.stderr.len != 0 or result.term.Exited != 0) {
            // We don't actually care if there were errors as this is best-effort check anyhow
            // and in the worst case the user can specify the sysroot manually.
            return null;
        }
        const path = allocator.dupe(u8, mem.trimRight(u8, result.stdout, "\r\n")) catch return null;
        break :path path;
    };
    const version = version: {
        const argv = &[_][]const u8{ "/usr/bin/xcrun", "--sdk", sdk, "--show-sdk-version" };
        const result = std.ChildProcess.exec(.{ .allocator = allocator, .argv = argv }) catch return null;
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

    pub fn deinit(self: DarwinSDK, allocator: Allocator) void {
        allocator.free(self.path);
    }
};

test "" {
    _ = @import("darwin/macos.zig");
}
