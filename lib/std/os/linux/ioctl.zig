const std = @import("../../std.zig");
const builtin = std.builtin;

const bits = switch (builtin.arch) {
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .powerpc,
    .powerpc64,
    .powerpc64le,
    .sparc,
    .sparcv9,
    .sparcel,
    => .{ .size = 13, .dir = 3, .none = 1, .read = 2, .write = 4 },
    else => .{ .size = 14, .dir = 2, .none = 0, .read = 1, .write = 2 },
};

const Direction = std.meta.Int(false, ioctl_bits.dir);

pub const Request = packed struct {
    nr: u8,
    type: u8,
    size: std.meta.Int(false, ioctl_bits.size),
    dir: Direction,
};

fn io_impl(dir: Direction, io_type: u8, nr: u8, comptime T: type) IoctlRequest {
    return .{
        .dir = dir,
        .size = @sizeOf(T),
        .type = io_type,
        .nr = nr,
    };
}

pub fn IO(io_type: u8, nr: u8) IoctlRequest {
    return io_impl(ioctl_bits.none, io_type, nr, void);
}

pub fn IOR(type: u8, nr: u8, comptime T: type) IoctlRequest {
    return io_impl(ioctl_bits.read, type, nr, T);
}

pub fn IOW(type: u8, nr: u8, comptime T: type) IoctlRequest {
    return io_impl(ioctl_bits.write, type, nr, T);
}

pub fn IOWR(type: u8, nr: u8, comptime T: type) IoctlRequest {
    return io_impl(ioctl_bits.read | bits.write, type, nr, T);
}

test "Ioctl.Cmd size" {
    std.testing.expectEqual(32, @bitSizeOf(Ioctl.Cmd));
}
