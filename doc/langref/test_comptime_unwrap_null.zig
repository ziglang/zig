comptime {
    const optional_number: ?i32 = null;
    const number = optional_number.?;
    _ = number;
}

// test_error=unable to unwrap null
