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
    _ = &u;
    _ = &s;
}

// error
// backend=stage2
// target=native
//
// :11:20: error: expected type 'u8', found '?u8'
// :11:20: note: cannot convert optional to payload type
// :11:20: note: consider using '.?', 'orelse', or 'if'
