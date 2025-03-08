pub fn main() u8 {
    return @embedFile("foo.zig").len;
}
