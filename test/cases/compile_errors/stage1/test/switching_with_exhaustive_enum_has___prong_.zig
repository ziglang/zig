const E = enum{
    a,
    b,
};
pub export fn entry() void {
    var e: E = .b;
    switch (e) {
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
// tmp.zig:7:5: error: switch on exhaustive enum has `_` prong
