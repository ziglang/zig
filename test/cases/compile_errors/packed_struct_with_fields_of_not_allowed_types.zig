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
        x: enum(u1) { A, B },
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
export fn entry13() void {
    _ = @sizeOf(packed struct {
        x: *type,
    });
}
export fn entry14() void {
    const E = enum { implicit, backing, type };
    _ = @sizeOf(packed struct {
        x: E,
    });
}

// error
// backend=llvm
// target=native
//
// :3:12: error: packed structs cannot contain fields of type 'anyerror'
// :3:12: note: type has no guaranteed in-memory representation
// :8:12: error: packed structs cannot contain fields of type '[2]u24'
// :8:12: note: type has no guaranteed in-memory representation
// :13:20: error: packed structs cannot contain fields of type 'anyerror!u32'
// :13:20: note: type has no guaranteed in-memory representation
// :18:12: error: packed structs cannot contain fields of type 'tmp.S'
// :18:12: note: only packed structs layout are allowed in packed types
// :56:11: note: struct declared here
// :23:12: error: packed structs cannot contain fields of type 'tmp.U'
// :23:12: note: only packed unions layout are allowed in packed types
// :59:18: note: union declared here
// :28:12: error: packed structs cannot contain fields of type '?anyerror'
// :28:12: note: type has no guaranteed in-memory representation
// :38:12: error: packed structs cannot contain fields of type 'fn () void'
// :38:12: note: type has no guaranteed in-memory representation
// :38:12: note: use '*const ' to make a function pointer type
// :65:31: error: packed structs cannot contain fields of type '[]u8'
// :65:31: note: slices have no guaranteed in-memory representation
// :70:12: error: packed structs cannot contain fields of type '*type'
// :70:12: note: comptime-only pointer has no guaranteed in-memory representation
// :70:12: note: types are not available at runtime
// :76:12: error: packed structs cannot contain fields of type 'tmp.entry14.E'
// :74:15: note: enum declared here
