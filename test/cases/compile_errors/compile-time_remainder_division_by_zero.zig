comptime {
    const a: i32 = 1;
    const b: i32 = 0;
    const c = a % b;
    _ = c;
}

// error
//
// :4:19: error: division by zero here causes illegal behavior
