const Small = enum(u2) {
    One,
    Two,
    Three,
    Four,
};

export fn entry() void {
    var x: u2 = Small.Two;
    _ = &x;
}

// error
//
// :9:22: error: expected type 'u2', found 'tmp.Small'
// :1:15: note: enum declared here
