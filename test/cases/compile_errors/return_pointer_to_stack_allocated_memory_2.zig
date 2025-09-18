// Test: Stack escape detection - Part 2: Struct field pointer escapes
// This file tests returning pointers to fields of stack-allocated structs

// Force runtime evaluation with this global
var runtime_value: i32 = 42;

fn returnStructFieldPtr() *i32 {
    const S = struct { x: i32, y: i32 };
    var s = S{ .x = runtime_value, .y = 2 };
    return &s.x;
}

fn returnStructFieldPtr2() *i32 {
    const S = struct { x: i32, y: i32 };
    var s = S{ .x = 1, .y = runtime_value };
    return &s.y;
}

fn returnAnonymousStructField() *u32 {
    var s = struct {
        a: i32,
        b: u32,
        c: u8,
    }{
        .a = runtime_value,
        .b = 100,
        .c = 0,
    };
    return &s.b;
}

// Struct field by index (these use struct_field_ptr_index_0, etc. in AIR)
fn returnStructFieldIndex0() *i32 {
    var s = struct { a: i32, b: i32 }{ .a = runtime_value, .b = 0 };
    return &s.a;
}

fn returnStructFieldIndex1() *i32 {
    var s = struct { a: i32, b: i32 }{ .a = 0, .b = runtime_value };
    return &s.b;
}

pub fn main() void {
    _ = returnStructFieldPtr();
    _ = returnStructFieldPtr2();
    _ = returnAnonymousStructField();
    _ = returnStructFieldIndex0();
    _ = returnStructFieldIndex1();
}

// error
// backend=auto
// target=native
//
// :10:12: error: cannot return pointer to stack-allocated memory
// :16:12: error: cannot return pointer to stack-allocated memory
// :29:12: error: cannot return pointer to stack-allocated memory
// :35:12: error: cannot return pointer to stack-allocated memory
// :40:12: error: cannot return pointer to stack-allocated memory
