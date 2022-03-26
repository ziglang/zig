const MultipleChoice = union(enum(u32)) {
    A = 20,
    B = 40,
    C = 60,
    D = 1000,
    E = 60,
};
export fn entry() void {
    var x = MultipleChoice { .C = {} };
    _ = x;
}

// union auto-enum value already taken
//
// tmp.zig:6:9: error: enum tag value 60 already taken
// tmp.zig:4:9: note: other occurrence here
