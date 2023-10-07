const resource = @embedFile("");

export fn entry() usize {
    return @sizeOf(@TypeOf(resource));
}

// error
// backend=stage2
// target=native
//
// :1:29: error: file path name cannot be empty
