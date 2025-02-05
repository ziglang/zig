const builtin = @import("builtin");
const A = error{
    FileNotFound,
    NotDir,
};
const B = error{OutOfMemory};

const C = A || B;

fn foo() C!void {
    return error.NotDir;
}

test "merge error sets" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (foo()) {
        @panic("unexpected");
    } else |err| switch (err) {
        error.OutOfMemory => @panic("unexpected"),
        error.FileNotFound => @panic("unexpected"),
        error.NotDir => {},
    }
}

test "merge different error unions with same payload" {
    comptime {
        const small: error{A}!u16 = 10;
        const large: error{ A, B }!u16 = small;
        if ((large catch 0) != 10) unreachable;
    }
}
