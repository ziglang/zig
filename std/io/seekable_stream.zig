const std = @import("../index.zig");
const InStream = std.io.InStream;

pub fn SeekableStream(comptime SeekErrorType: type, comptime GetSeekPosErrorType: type) type {
    return struct {
        const Self = @This();
        pub const SeekError = SeekErrorType;
        pub const GetSeekPosError = GetSeekPosErrorType;

        seekToFn: fn (self: *Self, pos: usize) SeekError!void,
        seekForwardFn: fn (self: *Self, pos: isize) SeekError!void,

        getPosFn: fn (self: *Self) GetSeekPosError!usize,
        getEndPosFn: fn (self: *Self) GetSeekPosError!usize,

        pub fn seekTo(self: *Self, pos: usize) SeekError!void {
            return self.seekToFn(self, pos);
        }

        pub fn seekForward(self: *Self, amt: isize) SeekError!void {
            return self.seekForwardFn(self, amt);
        }

        pub fn getEndPos(self: *Self) GetSeekPosError!usize {
            return self.getEndPosFn(self);
        }

        pub fn getPos(self: *Self) GetSeekPosError!usize {
            return self.getPosFn(self);
        }
    };
}
