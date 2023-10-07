const resource = @embedFile("bogus.txt");

export fn entry() usize {
    return @sizeOf(@TypeOf(resource));
}

// error
// backend=stage2
// target=native
//
// :1:29: error: unable to open 'bogus.txt': FileNotFound
