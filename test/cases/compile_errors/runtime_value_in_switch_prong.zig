pub export fn entry() void {
    var byte: u8 = 1;
    switch ((&byte).*) {
        byte => {},
        else => {},
    }
}

// error
// backend=stage2
// target=native
//
// :4:9: error: unable to resolve comptime value
// :4:9: note: switch prong values must be comptime-known
