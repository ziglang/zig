fn foo() void {
    var sequence = "repeat".*** 10;
    _ = sequence;
}

// Issue #6823: don't allow .* to be followed by **
//
// tmp.zig:2:28: error: '.*' cannot be followed by '*'. Are you missing a space?
