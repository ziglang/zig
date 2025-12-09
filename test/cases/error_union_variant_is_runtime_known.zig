// This tests that the variant of an error union is runtime-known when the value is runtime-known.
// This might seem obvious but previously the compiler special-cased the situation where a const
// was assigned a payload or error value, i.e. instead of another error union.

export fn foo() void {
    var runtime_payload: u8 = 0;
    _ = &runtime_payload;
    const eu: error{a}!u8 = runtime_payload;
    if (eu) |_| {} else |_| @compileError("analyzed");
}

export fn bar() void {
    var runtime_error: error{a} = error.a;
    _ = &runtime_error;
    const eu: error{a}!u8 = runtime_error;
    if (eu) |_| @compileError("analyzed") else |_| {}
}

// error
//
// :9:29: error: analyzed
// :16:17: error: analyzed
