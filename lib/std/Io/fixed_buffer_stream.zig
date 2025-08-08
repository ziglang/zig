const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;

/// Deprecated in favor of `std.Io.Reader.fixed` and `std.Io.Writer.fixed`.
pub fn FixedBufferStream(comptime Buffer: type) type {
    return struct {
        /// `Buffer` is either a `[]u8` or `[]const u8`.
        buffer: Buffer,
        pos: usize,

        pub const ReadError = error{};
        pub const WriteError = error{NoSpaceLeft};
        pub const SeekError = error{};
        pub const GetSeekPosError = error{};

        pub const Reader = io.GenericReader(*Self, ReadError, read);

        const Self = @This();

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn read(self: *Self, dest: []u8) ReadError!usize {
            const size = @min(dest.len, self.buffer.len - self.pos);
            const end = self.pos + size;

            @memcpy(dest[0..size], self.buffer[self.pos..end]);
            self.pos = end;

            return size;
        }

        pub fn seekTo(self: *Self, pos: u64) SeekError!void {
            self.pos = @min(std.math.lossyCast(usize, pos), self.buffer.len);
        }

        pub fn seekBy(self: *Self, amt: i64) SeekError!void {
            if (amt < 0) {
                const abs_amt = @abs(amt);
                const abs_amt_usize = std.math.cast(usize, abs_amt) orelse std.math.maxInt(usize);
                if (abs_amt_usize > self.pos) {
                    self.pos = 0;
                } else {
                    self.pos -= abs_amt_usize;
                }
            } else {
                const amt_usize = std.math.cast(usize, amt) orelse std.math.maxInt(usize);
                const new_pos = std.math.add(usize, self.pos, amt_usize) catch std.math.maxInt(usize);
                self.pos = @min(self.buffer.len, new_pos);
            }
        }

        pub fn getEndPos(self: *Self) GetSeekPosError!u64 {
            return self.buffer.len;
        }

        pub fn getPos(self: *Self) GetSeekPosError!u64 {
            return self.pos;
        }

        pub fn reset(self: *Self) void {
            self.pos = 0;
        }
    };
}

pub fn fixedBufferStream(buffer: anytype) FixedBufferStream(Slice(@TypeOf(buffer))) {
    return .{ .buffer = buffer, .pos = 0 };
}

fn Slice(comptime T: type) type {
    switch (@typeInfo(T)) {
        .pointer => |ptr_info| {
            var new_ptr_info = ptr_info;
            switch (ptr_info.size) {
                .slice => {},
                .one => switch (@typeInfo(ptr_info.child)) {
                    .array => |info| new_ptr_info.child = info.child,
                    else => @compileError("invalid type given to fixedBufferStream"),
                },
                else => @compileError("invalid type given to fixedBufferStream"),
            }
            new_ptr_info.size = .slice;
            return @Type(.{ .pointer = new_ptr_info });
        },
        else => @compileError("invalid type given to fixedBufferStream"),
    }
}

test "input" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7 };
    var fbs = fixedBufferStream(&bytes);

    var dest: [4]u8 = undefined;

    var read = try fbs.reader().read(&dest);
    try testing.expect(read == 4);
    try testing.expect(mem.eql(u8, dest[0..4], bytes[0..4]));

    read = try fbs.reader().read(&dest);
    try testing.expect(read == 3);
    try testing.expect(mem.eql(u8, dest[0..3], bytes[4..7]));

    read = try fbs.reader().read(&dest);
    try testing.expect(read == 0);

    try fbs.seekTo((try fbs.getEndPos()) + 1);
    read = try fbs.reader().read(&dest);
    try testing.expect(read == 0);
}
