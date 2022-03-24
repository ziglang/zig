pub export fn entry() void {
    var res: []i32 = undefined;
    res = myAlloc(i32);
}
fn myAlloc(comptime arg: type) anyerror!arg{
    unreachable;
}

// generic function call assigned to incorrect type
//
// tmp.zig:3:18: error: expected type '[]i32', found 'anyerror!i32
