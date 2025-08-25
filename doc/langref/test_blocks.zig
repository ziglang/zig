test "access variable after block scope" {
    {
        var x: i32 = 1;
        _ = &x;
    }
    x += 1;
}

// test_error=use of undeclared identifier 'x'
