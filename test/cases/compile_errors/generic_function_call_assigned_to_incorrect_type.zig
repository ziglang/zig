pub export fn entry() void {
    var res: []i32 = undefined;
    res = myAlloc(i32);
}
fn myAlloc(comptime arg: type) anyerror!arg {
    unreachable;
}

// error
// backend=stage2
// target=native
//
// :3:18: error: expected type '[]i32', found 'anyerror!i32'
