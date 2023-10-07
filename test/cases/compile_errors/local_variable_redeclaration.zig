export fn f() void {
    const a: i32 = 0;
    var a = 0;
}

// error
// backend=stage2
// target=native
//
// :3:9: error: redeclaration of local constant 'a'
// :2:11: note: previous declaration here
