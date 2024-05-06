pub export fn entry1() void {
    var a: anyerror = undefined;
    _ = &a;
    switch (a) {
        inline else => {},
    }
}
const E = enum(u8) { a, _ };
pub export fn entry2() void {
    var a: E = undefined;
    _ = &a;
    switch (a) {
        inline else => {},
    }
}
pub export fn entry3() void {
    var a: *u32 = undefined;
    _ = &a;
    switch (a) {
        inline else => {},
    }
}

// error
// backend=stage2
// target=native
//
// :5:21: error: cannot enumerate values of type 'anyerror' for 'inline else'
// :13:21: error: cannot enumerate values of type 'tmp.E' for 'inline else'
// :8:11: note: enum declared here
// :20:21: error: cannot enumerate values of type '*u32' for 'inline else'
