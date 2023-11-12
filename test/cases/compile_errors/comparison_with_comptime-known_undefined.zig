pub fn entry() void {
    var foo: ?*i32 = undefined;
    if (foo == undefined) {}
}

// error
// backend=stage2
// target=native
//
// :3:13: error: use of undefined value here causes undefined behavior
