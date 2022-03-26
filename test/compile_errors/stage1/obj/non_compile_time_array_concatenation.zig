fn f() []u8 {
    return s ++ "foo";
}
var s: [10]u8 = undefined;
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// non compile time array concatenation
//
// tmp.zig:2:12: error: unable to evaluate constant expression
