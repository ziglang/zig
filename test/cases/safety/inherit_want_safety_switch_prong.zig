const std = @import("std");
const general = switch (@import("builtin").mode) {
    .ReleaseSafe, .Debug => true,
    .ReleaseFast, .ReleaseSmall => false,
};
const want = !general;
pub fn panic(_: []const u8, _: @TypeOf(@errorReturnTrace()), _: ?usize) noreturn {
    std.process.exit(@intFromBool(general));
}
var i: usize = ~@as(usize, 0);
pub fn main() void {
    @setRuntimeSafety(want);
    switch (0) {
        else => i += 1,
    }
    std.process.exit(@intFromBool(want));
}
// run
// backend=llvm
// target=native
