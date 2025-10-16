const struct_name = struct {
    test "testname" {}

    fn func1() void {}

    test func1 {
        return error.bad;
    }
};

test struct_name {
    return error.bad;
}

comptime {
    _ = struct_name;
}

test "struct_name.testname" {}

test "unfiltered" {
    return error.bad;
}

test {
    return error.bad;
}
