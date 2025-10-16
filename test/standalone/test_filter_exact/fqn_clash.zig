test "test.name" {}

const @"test" = struct {
    test "name" {}
};

test "failing" {
    return error.bad;
}

comptime {
    _ = @"test";
}
