export fn entry1() void {
    @trap();
    @trap();
}
export fn entry2() void {
    @panic("");
    @panic("");
}
export fn entry3() void {
    @compileError("");
    @compileError("");
}

// error
// backend=stage2
// target=native
//
// :3:5: error: unreachable code
// :2:5: note: control flow is diverted here
// :7:5: error: unreachable code
// :6:5: note: control flow is diverted here
// :11:5: error: unreachable code
// :10:5: note: control flow is diverted here
