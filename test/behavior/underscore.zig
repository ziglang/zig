test "ignore lval with underscore" {
    _ = false;
}

test "ignore lval with underscore (while loop)" {
    while (optionalReturnError()) |_| {
        while (optionalReturnError()) |_| {
            break;
        } else |_| {}
        break;
    } else |_| {}
}

fn optionalReturnError() !?u32 {
    return error.optionalReturnError;
}
