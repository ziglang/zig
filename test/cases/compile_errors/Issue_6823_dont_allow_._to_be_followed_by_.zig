fn foo() void {
    var sequence = "repeat".*** 10;
    _ = sequence;
}

// error
//
// :2:28: error: '.*' cannot be followed by '*'; are you missing a space?
