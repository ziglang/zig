const E = enum(u8) {
    a,
    b,
    _,
};
const U = union(E) {
    a: i32,
    b: u32,
};
pub export fn entry() void {
    var e: E = .b;
    switch (e) { // error: switch not handling the tag `b`
        .a => {},
        _ => {},
    }
    switch (e) { // error: switch on non-exhaustive enum must include `else` or `_` prong
        .a => {},
        .b => {},
    }
    var u = U{.a = 2};
    switch (u) { // error: `_` prong not allowed when switching on tagged union
        .a => {},
        .b => {},
        _ => {},
    }
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:12:5: error: enumeration value 'E.b' not handled in switch
// tmp.zig:16:5: error: switch on non-exhaustive enum must include `else` or `_` prong
// tmp.zig:21:5: error: `_` prong not allowed when switching on tagged union
