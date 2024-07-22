const S = struct {
    fizz: void,
};

export fn entry() void {
    _ = @as(S, struct { void }{{}});
}

// error
// target=native
//
// :6:31: error: no field named '0' in struct 'tmp.S'
// :1:11: note: struct declared here
