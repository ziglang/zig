export fn foo() void {
    var b: u8[40] = undefined;
    _ = b;
}

// error
// backend=stage2
// target=native
//
// :2:14: error: element access of non-indexable type 'type'
