const S = struct {
    b: u32,
    c: i32,
    a: struct {
        pub fn str(_: @This(), extra: []u32) []i32 {
            return @bitCast(extra);
        }
    },
};

pub export fn entry() void {
    var s: S = undefined;
    _ = s.a.str(undefined);
}

const S2 = struct {
    a: [*c]anyopaque,
};

pub export fn entry2() void {
    var s: S2 = undefined;
    _ = &s;
}

// error
// backend=llvm
// target=native
//
// :17:12: error: C pointers cannot point to opaque types
// :6:20: error: cannot @bitCast to '[]i32'
// :6:20: note: use @ptrCast to cast from '[]u32'
