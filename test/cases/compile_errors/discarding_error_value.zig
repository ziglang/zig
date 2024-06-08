export fn entry1() void {
    _ = foo();
}
fn foo() !void {
    return error.OutOfMemory;
}
export fn entry2() void {
    const x: error{a} = undefined;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: error union is discarded
// :2:12: note: consider using 'try', 'catch', or 'if'
// :9:9: error: error set is discarded
