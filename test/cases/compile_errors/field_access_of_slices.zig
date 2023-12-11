export fn entry() void {
    var slice: []i32 = undefined;
    _ = &slice;
    const info = @TypeOf(slice).unknown;
    _ = info;
}

// error
// backend=stage2
// target=native
//
// :4:32: error: type '[]i32' has no members
// :4:32: note: slice values have 'len' and 'ptr' members
