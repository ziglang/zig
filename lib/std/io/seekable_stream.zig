// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");

pub fn SeekableStream(
    comptime Context: type,
    comptime SeekErrorType: type,
    comptime GetSeekPosErrorType: type,
    comptime seekToFn: fn (context: Context, pos: u64) SeekErrorType!void,
    comptime seekByFn: fn (context: Context, pos: i64) SeekErrorType!void,
    comptime getPosFn: fn (context: Context) GetSeekPosErrorType!u64,
    comptime getEndPosFn: fn (context: Context) GetSeekPosErrorType!u64,
) type {
    return struct {
        context: Context,

        const Self = @This();
        pub const SeekError = SeekErrorType;
        pub const GetSeekPosError = GetSeekPosErrorType;

        pub fn seekTo(self: Self, pos: u64) SeekError!void {
            return seekToFn(self.context, pos);
        }

        pub fn seekBy(self: Self, amt: i64) SeekError!void {
            return seekByFn(self.context, amt);
        }

        pub fn getEndPos(self: Self) GetSeekPosError!u64 {
            return getEndPosFn(self.context);
        }

        pub fn getPos(self: Self) GetSeekPosError!u64 {
            return getPosFn(self.context);
        }
    };
}
