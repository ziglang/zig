const resource = @embedFile("");

export fn entry() usize {
    return @sizeOf(@TypeOf(resource));
}

// error
//
// :1:29: error: file path name cannot be empty
