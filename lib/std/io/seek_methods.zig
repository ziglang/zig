const std = @import("../std.zig");

pub fn SeekMethods(
    comptime Self: type,
    comptime SeekErrorType: type,
    comptime GetSeekPosErrorType: type,
) type {
    return struct {
        pub const seek_interface_id = @typeName(@TypeOf(Self.context)) ++ ".Seeker";
        pub const SeekError = SeekErrorType;
        pub const GetSeekPosError = GetSeekPosErrorType;

        pub fn seekTo(self: Self, pos: u64) SeekError!void {
            return self.context.seekTo(pos);
        }

        pub fn seekBy(self: Self, amt: i64) SeekError!void {
            return self.context.seekBy(amt);
        }

        pub fn getEndPos(self: Self) GetSeekPosError!u64 {
            return self.context.getEndPos();
        }

        pub fn getPos(self: Self) GetSeekPosError!u64 {
            return self.context.getPos();
        }
    };
}
