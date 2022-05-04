fn foo() void {
    var sequence = "repeat".*** 10;
    _ = sequence;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:28: error: '.*' cannot be followed by '*'. Are you missing a space?
