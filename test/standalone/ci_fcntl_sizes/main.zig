// To test: zig test test-flock-aarch64.zig -lc

const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("fcntl.h");
});

//pub const Flock = extern struct {
//    type: i16,       // 2
//    whence: i16,     // 2
//                     // 4 bytes alignment
//    start: off_t,    // 8
//    len: off_t,      // 8
//    pid: pid_t,      // 4
//    __unused: [4]u8, // 4
//};                   // == 32 bytes

// x86_64
// field l_type, size: 2, alignment 2
// field l_whence, size: 2, alignment 2
// field l_start, size: 8, alignment 8
// field l_len, size: 8, alignment 8
// field l_pid, size: 4, alignment 4
// total size: 32 and alignment 8

// aarch64 = ARM64
// ???

test "Print all sizes" {
    inline for (@typeInfo(c.struct_flock).Struct.fields) |field| {
        std.debug.print("field {s}, size: {d}, alignment {d}\n", .{ field.name, @sizeOf(field.type), field.alignment });
    }
    std.debug.print("total size: {d} and alignment {d}\n", .{ @sizeOf(c.struct_flock), @alignOf(c.struct_flock) });
}

test "Test size of struct flock on aarch64 linux" {
    try expect(@sizeOf(std.os.Flock) == 32);
    try expect(@sizeOf(std.os.Flock) == @sizeOf(c.struct_flock));
}

test "Test Zig's fcntl constants match C's on aarch64 linux" {
    try expect(std.os.F.WRLCK == c.F_WRLCK);
    try expect(std.os.SEEK.SET == c.SEEK_SET);
    try expect(std.os.F.SETLK == c.F_SETLK);
}

test "Test initializing struct flock on aarch64 linux" {
    var struct_flock = std.mem.zeroInit(std.os.Flock, .{ .start = 3, .len = 1, .type = std.os.F.WRLCK, .whence = std.os.SEEK.SET });
    try expect(struct_flock.type == c.F_WRLCK);
    try expect(struct_flock.whence == c.SEEK_SET);
    try expect(struct_flock.start == 3);
    try expect(struct_flock.len == 1);
    try expect(struct_flock.pid == 0);
    // try expect(std.mem.eql(u8, &(struct_flock.__unused), &([_]u8{ 0, 0, 0, 0 })));
}
