export fn entry1() void {
    var frame: @Frame(foo) = undefined;
    @asyncCall(&frame, {}, foo, {});
}

fn foo() i32 {
    return 0;
}

// wrong type for argument tuple to @asyncCall
//
// tmp.zig:3:33: error: expected tuple or struct, found 'void'
