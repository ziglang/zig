const MultipleChoice = union {
    A: i32 = 20,
};
export fn entry() void {
    var x: MultipleChoice = undefined;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:24: error: explicitly valued tagged union missing integer tag type
// tmp.zig:2:14: note: tag value specified here
