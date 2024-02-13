const MultipleChoice = union(enum(u32)) {
    A = 20,
    B = 40,
    C = 60,
    D = 1000,
    E = 60,
};
export fn entry() void {
    const x: MultipleChoice = .{ .C = {} };
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :6:5: error: enum tag value 60 already taken
// :4:5: note: other occurrence here
