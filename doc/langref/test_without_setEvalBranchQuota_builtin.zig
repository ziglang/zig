test "foo" {
    comptime {
        var i = 0;
        while (i < 1001) : (i += 1) {}
    }
}

// test_error=evaluation exceeded 1000 backwards branches
