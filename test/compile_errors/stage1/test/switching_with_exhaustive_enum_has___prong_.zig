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

// switching with exhaustive enum has '_' prong 
//
// tmp.zig:7:5: error: switch on exhaustive enum has `_` prong
