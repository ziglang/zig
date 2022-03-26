fn maybe(is: bool) ?u8 {
    if (is) return @as(u8, 10) else return null;
}
const U = union {
    Ye: u8,
};
const S = struct {
    num: u8,
};
export fn entry() void {
    var u = U{ .Ye = maybe(false) };
    var s = S{ .num = maybe(false) };
    _ = u;
    _ = s;
}

// assigning to struct or union fields that are not optionals with a function that returns an optional
//
// tmp.zig:11:27: error: cannot convert optional to payload type. consider using `.?`, `orelse`, or `if`. expected type 'u8', found '?u8'
