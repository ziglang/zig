extern fn exit() noreturn;

test "foo" {
    comptime {
        exit();
    }
}

// test_error=comptime call of extern function
