const S = struct {
    fizz: void,
};

export fn entry() void {
    _ = @as(S, struct { void }{{}});
}

// error
//
// :6:31: error: expected type 'tmp.S', found 'struct { comptime void = {} }'
// :1:11: note: struct declared here
