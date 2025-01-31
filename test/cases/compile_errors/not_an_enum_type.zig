export fn entry() void {
    var self: Error = undefined;
    switch ((&self).*) {
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

// error
// backend=stage2
// target=native
//
// :4:9: error: expected type '@typeInfo(tmp.Error).@"union".tag_type.?', found 'type'
// :8:15: note: enum declared here
