export fn entry() void {
    var slice: []i32 = undefined;
    _ = &slice;
    const info = @TypeOf(slice).unknown;
    _ = info;
}

// error
//
// :4:32: error: type '[]i32' has no members
// :4:32: note: slice values have 'len' and 'ptr' members
