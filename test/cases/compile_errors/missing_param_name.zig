fn f(i32) void {}
export fn entry() usize {
    return @sizeOf(@TypeOf(f));
}

// error
//
// :1:6: error: missing parameter name
