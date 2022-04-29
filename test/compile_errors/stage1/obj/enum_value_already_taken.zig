const MultipleChoice = enum(u32) {
    A = 20,
    B = 40,
    C = 60,
    D = 1000,
    E = 60,
};
export fn entry() void {
    var x = MultipleChoice.C;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:5: error: enum tag value 60 already taken
// tmp.zig:4:5: note: other occurrence here
