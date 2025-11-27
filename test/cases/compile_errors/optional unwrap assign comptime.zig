pub fn main() !void {
    comptime {
        var foo: ?u8 = null;
        foo.? = 10;
    }
}
// error
//
// 4:12: error: unable to unwrap null
