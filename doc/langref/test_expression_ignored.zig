test "ignoring expression value" {
    foo();
}

fn foo() i32 {
    return 1234;
}

// test_error=ignored
