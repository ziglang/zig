// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Target = std.Target;

pub const macos = @import("darwin/macos.zig");

/// Detect SDK path on Darwin.
/// Calls `xcrun --sdk <target_sdk> --show-sdk-path` which result can be used to specify
/// `--sysroot` of the compiler.
/// The caller needs to free the resulting path slice.
pub fn getSDKPath(allocator: *Allocator, target: Target) !?[]u8 {
    const is_simulator_abi = target.abi == .simulator;
    const sdk = switch (target.os.tag) {
        .macos => "macosx",
        .ios => if (is_simulator_abi) "iphonesimulator" else "iphoneos",
        .watchos => if (is_simulator_abi) "watchsimulator" else "watchos",
        .tvos => if (is_simulator_abi) "appletvsimulator" else "appletvos",
        else => return null,
    };

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
    const sysroot = try allocator.dupe(u8, mem.trimRight(u8, result.stdout, "\r\n"));
    return sysroot;
}

test "" {
    _ = @import("darwin/macos.zig");
}
