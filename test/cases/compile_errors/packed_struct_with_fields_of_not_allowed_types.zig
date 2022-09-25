export fn entry1() void {
    _ = @sizeOf(packed struct {
        x: anyerror,
    });
}
export fn entry2() void {
    _ = @sizeOf(packed struct {
        x: [2]u24,
    });
}
export fn entry3() void {
    _ = @sizeOf(packed struct {
        x: anyerror!u32,
    });
}
export fn entry4() void {
    _ = @sizeOf(packed struct {
        x: S,
    });
}
export fn entry5() void {
    _ = @sizeOf(packed struct {
        x: U,
    });
}
export fn entry6() void {
    _ = @sizeOf(packed struct {
        x: ?anyerror,
    });
}
export fn entry7() void {
    _ = @sizeOf(packed struct {
        x: enum { A, B },
    });
}
export fn entry8() void {
    _ = @sizeOf(packed struct {
        x: fn () void,
    });
}
export fn entry9() void {
    _ = @sizeOf(packed struct {
        x: *const fn () void,
    });
}
export fn entry10() void {
    _ = @sizeOf(packed struct {
        x: packed struct { x: i32 },
    });
}
export fn entry11() void {
    _ = @sizeOf(packed struct {
        x: packed union { A: i32, B: u32 },
    });
}
const S = struct {
    x: i32,
};
const U = extern union {
    A: i32,
    B: u32,
};
export fn entry12() void {
    _ = @sizeOf(packed struct {
        x: packed struct { a: []u8 },
    });
}

// error
// backend=llvm
// target=native
//
// :3:9: error: packed structs cannot contain fields of type 'anyerror'
// :3:9: note: type has no guaranteed in-memory representation
// :8:9: error: packed structs cannot contain fields of type '[2]u24'
// :8:9: note: type has no guaranteed in-memory representation
// :13:9: error: packed structs cannot contain fields of type 'anyerror!u32'
// :13:9: note: type has no guaranteed in-memory representation
// :18:9: error: packed structs cannot contain fields of type 'tmp.S'
// :18:9: note: only packed structs layout are allowed in packed types
// :56:11: note: struct declared here
// :23:9: error: packed structs cannot contain fields of type 'tmp.U'
// :23:9: note: only packed unions layout are allowed in packed types
// :59:18: note: union declared here
// :28:9: error: packed structs cannot contain fields of type '?anyerror'
// :28:9: note: type has no guaranteed in-memory representation
// :38:9: error: packed structs cannot contain fields of type 'fn() void'
// :38:9: note: type has no guaranteed in-memory representation
// :38:9: note: use '*const ' to make a function pointer type
// :65:28: error: packed structs cannot contain fields of type '[]u8'
// :65:28: note: slices have no guaranteed in-memory representation
