test "test runner path pass" {}

test "test runner path fail" {
    return error.Fail;
}

test "test runner path skip" {
    return error.SkipZigTest;
}
