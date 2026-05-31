comptime {
    const a = -128;
    const b: i8 = -1;
    _ = a / b;
}

// error
//
// :4:11: error: overflow of integer type 'i8' with value '128'
