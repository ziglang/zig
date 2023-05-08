const Namespace = struct {
    test "thingy" {}
};

fn thingy(a: usize, b: usize) usize {
    return a + b;
}

comptime {
    _ = Namespace;
}

test "thingy" {}

test thingy {
    if (thingy(1, 2) != 3) unreachable;
}
