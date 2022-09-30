fn List(comptime Head: type, comptime Tail: type) type {
    return union {
        const Self = @This();
        head: Head,
        tail: Tail,

        fn AppendReturnType(comptime item: anytype) type {
            return List(Head, List(@TypeOf(item), void));
        }
    };
}

fn makeList(item: anytype) List(@TypeOf(item), void) {
    return List(@TypeOf(item), void){ .head = item };
}

pub export fn entry() void {
    @TypeOf(makeList(42)).AppendReturnType(64);
}

// error
// backend=llvm
// target=native
//
// :18:43: error: value of type 'type' ignored
// :18:43: note: all non-void values must be used
// :18:43: note: this error can be suppressed by assigning the value to '_'
