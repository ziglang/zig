fn f() []u8 {
    return s ++ "foo";
}
var s: [10]u8 = undefined;
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:12: error: unable to evaluate constant expression
