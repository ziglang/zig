const std = @import("../std.zig");
const InStream = std.io.InStream;

pub fn SeekableStream(comptime SeekErrorType: type, comptime GetSeekPosErrorType: type) type {
    return struct {
        const Self = @This();
        pub const SeekError = SeekErrorType;
        pub const GetSeekPosError = GetSeekPosErrorType;

        seekToFn: fn (self: *Self, pos: u64) SeekError!void,
        seekForwardFn: fn (self: *Self, pos: i64) SeekError!void,

        getPosFn: fn (self: *Self) GetSeekPosError!u64,
        getEndPosFn: fn (self: *Self) GetSeekPosError!u64,

        pub fn seekTo(self: *Self, pos: u64) SeekError!void {
            return self.seekToFn(self, pos);
        }

        pub fn seekForward(self: *Self, amt: i64) SeekError!void {
            return self.seekForwardFn(self, amt);
        }

        pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
            return self.getEndPosFn(self);
        }

        pub fn getPos(self: *Self) GetSeekPosError!u64 {
            return self.getPosFn(self);
        }
    };
}
