export fn foo() void {
    var x: @Vector(2, u1) = .{ 0, 1 };
    x = !x;
}

// error
// backend=stage2
// target=native
//
// :3:10: error: boolean not operation on type '@Vector(2, u1)'
