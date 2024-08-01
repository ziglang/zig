const std = @import("../../std.zig");

const bits = switch (@import("builtin").cpu.arch) {
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .powerpc,
    .powerpcle,
    .powerpc64,
    .powerpc64le,
    .sparc,
    .sparc64,
    => .{ .size = 13, .dir = 3, .none = 1, .read = 2, .write = 4 },
    else => .{ .size = 14, .dir = 2, .none = 0, .read = 2, .write = 1 },
};

const Direction = std.meta.Int(.unsigned, bits.dir);

pub const Request = packed struct {
    nr: u8,
    io_type: u8,
    size: std.meta.Int(.unsigned, bits.size),
    dir: Direction,
};

fn io_impl(dir: Direction, io_type: u8, nr: u8, comptime T: type) u32 {
    const request = Request{
        .dir = dir,
        .size = @sizeOf(T),
        .io_type = io_type,
        .nr = nr,
    };
    return @as(u32, @bitCast(request));
}

pub fn IO(io_type: u8, nr: u8) u32 {
    return io_impl(bits.none, io_type, nr, void);
}

pub fn IOR(io_type: u8, nr: u8, comptime T: type) u32 {
    return io_impl(bits.read, io_type, nr, T);
}

pub fn IOW(io_type: u8, nr: u8, comptime T: type) u32 {
    return io_impl(bits.write, io_type, nr, T);
}

pub fn IOWR(io_type: u8, nr: u8, comptime T: type) u32 {
    return io_impl(bits.read | bits.write, io_type, nr, T);
}

comptime {
    std.debug.assert(@bitSizeOf(Request) == 32);
}
