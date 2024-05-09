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

// TODO: the output here has been regressed by #19414.
// Restoring useful output here will require providing a Sema to TypedValue.print.

// error
//
// :20:5: error: found compile log statement
//
// Compile Log Output:
// @as([]i32, @as([*]i32, @ptrCast(@as(tmp.UnionContainer, .{ .buf = .{ 1, 2 } }).buf[0]))[0..2])
// @as([]i32, @as([*]i32, @ptrCast(@as(tmp.StructContainer, .{ .buf = .{ 3, 4 } }).buf[0]))[0..2])
