export fn entry() void {
    var slice: []i32 = undefined;
    const info = @TypeOf(slice).unknown;
    _ = info;
}

// error
// backend=stage2
// target=native
//
// :3:32: error: type '[]i32' has no members
// :3:32: note: slice values have 'len' and 'ptr' members
