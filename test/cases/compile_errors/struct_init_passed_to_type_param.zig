const MyStruct = struct { x: i32 };

fn hi(comptime T: type) usize {
    return @sizeOf(T);
}

export const value = hi(MyStruct{ .x = 12 });

// error
// backend=stage2
// target=native
//
// :7:33: error: expected type 'type', found 'tmp.MyStruct'
// :1:18: note: struct declared here
// :3:19: note: parameter type declared here
