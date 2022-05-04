fn ignore(comptime param: anytype) void {_ = param;}

export fn foo() void {
    const MyStruct = struct {
        wrong_type: []u8 = "foo",
    };

    comptime ignore(@typeInfo(MyStruct).Struct.fields[0]);
}

// error
// backend=stage1
// target=native
//
// :5:28: error: cannot cast pointer to array literal to slice type '[]u8'
// :5:28: note: cast discards const qualifier
