export fn entry1() void {
    var frame: @Frame(foo) = undefined;
    @asyncCall(&frame, {}, foo, {});
}

fn foo() i32 {
    return 0;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:33: error: expected tuple or struct, found 'void'
