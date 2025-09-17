pub export fn entry() void {
    var a: [:0]const u8 = "foo";
    _ = &a;
    switch (a) {
        ("--version"), ("version") => unreachable,
        else => {},
    }
}

// error
//
// :4:13: error: switch on type '[:0]const u8'
