fn ignore(comptime param: anytype) void {_ = param;}

export fn foo() void {
    const MyStruct = struct {
        wrong_type: []u8 = "foo",
    };

    comptime ignore(@typeInfo(MyStruct).Struct.fields[0]);
}

// error
// backend=stage2
// target=native
//
// :4:22: error: expected type '[]u8', found '*const [3:0]u8'
// :4:22: note: cast discards const qualifier
