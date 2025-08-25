export fn foo() void {
    if (2 == undefined) {}
}

export fn bar(x: u32) void {
    if (x == undefined) {}
}

// error
//
// :2:11: error: use of undefined value here causes illegal behavior
// :6:11: error: use of undefined value here causes illegal behavior
