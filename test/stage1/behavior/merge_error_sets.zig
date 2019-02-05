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
    if (foo()) {
        @panic("unexpected");
    } else |err| switch (err) {
        error.OutOfMemory => @panic("unexpected"),
        error.FileNotFound => @panic("unexpected"),
        error.NotDir => {},
    }
}
