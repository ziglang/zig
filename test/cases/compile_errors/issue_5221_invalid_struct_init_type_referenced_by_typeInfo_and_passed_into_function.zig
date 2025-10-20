fn ignore(comptime param: anytype) void {
    _ = param;
}

export fn foo() void {
    const MyStruct = struct {
        wrong_type: []u8 = "foo",
    };

    comptime ignore(@typeInfo(MyStruct).@"struct".fields[0]);
}

// error
//
// :7:28: error: expected type '[]u8', found '*const [3:0]u8'
// :7:28: note: cast discards const qualifier
