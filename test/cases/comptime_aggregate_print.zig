const UnionContainer = union {
    buf: [2]i32,
};

fn getUnionSlice() []i32 {
    var c = UnionContainer{ .buf = .{ 1, 2 } };
    return c.buf[0..2];
}

const StructContainer = struct {
    buf: [2]i32,
};

fn getStructSlice() []i32 {
    var c = StructContainer{ .buf = .{ 3, 4 } };
    return c.buf[0..2];
}

comptime {
    @compileLog(getUnionSlice());
    @compileLog(getStructSlice());
}

pub fn main() !void {}

// error
//
// :20:5: error: found compile log statement
//
// Compile Log Output:
// @as([]i32, .{ 1, 2 })
// @as([]i32, .{ 3, 4 })
