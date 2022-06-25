const std = @import("../std.zig");

pub fn SeekMethods(
    comptime Self: type,
    comptime Context: type,
) type {
    return struct {
        pub const seek_interface_id = @typeName(Context) ++ ".Seeker";
        const ContextType = if (@typeInfo(Context) == .Pointer) @typeInfo(Context).Pointer.child else Context;
        pub const SeekError = std.meta.getReturnErrorType(ContextType.seekBy);
        pub const GetSeekPosError = std.meta.getReturnErrorType(ContextType.getPos);

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
