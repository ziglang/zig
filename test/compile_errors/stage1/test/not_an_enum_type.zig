export fn entry() void {
    var self: Error = undefined;
    switch (self) {
        InvalidToken => |x| return x.token,
        ExpectedVarDeclOrFn => |x| return x.token,
    }
}
const Error = union(enum) {
    A: InvalidToken,
    B: ExpectedVarDeclOrFn,
};
const InvalidToken = struct {};
const ExpectedVarDeclOrFn = struct {};

// not an enum type
//
// tmp.zig:4:9: error: expected type '@typeInfo(Error).Union.tag_type.?', found 'type'
