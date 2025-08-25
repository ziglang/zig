fn foo() void {
    var sequence = "repeat".*** 10;
    _ = sequence;
}

// error
// backend=stage2
// target=native
//
// :2:28: error: '.*' cannot be followed by '*'; are you missing a space?
