const x = @import("builtin").bogus;
export fn entry() usize {
    return @sizeOf(@TypeOf(x));
}

// error
//
// :1:29: error: root source file struct 'builtin' has no member named 'bogus'
// note: struct declared here
