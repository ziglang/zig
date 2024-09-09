pub const Header = packed struct { v: u32 };

pub fn main() void {
    const buf: []const u8 = &@as([4]u8, @bitCast(@as(u32, 1)));
    const w = buf[0..@sizeOf(Header)];
    const hdr: *align(1) const Header = @ptrCast(w);
    if (hdr.v != 1) unreachable;
}

// compile
//
