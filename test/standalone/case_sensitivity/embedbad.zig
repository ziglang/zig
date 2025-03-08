pub fn main() u8 {
    return @embedFile("Foo.zig").len;
}
