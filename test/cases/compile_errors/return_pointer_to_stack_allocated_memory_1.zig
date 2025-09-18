// Test: Stack escape detection - Part 1: Basic pointer escapes
// This file tests basic cases of returning pointers to stack-allocated memory

// Force runtime evaluation with this global
var runtime_value: i32 = 42;

fn returnLocalPtr() *i32 {
    var x: i32 = runtime_value;
    return &x;
}

fn returnLocalPtrConst() *const i32 {
    var x: i32 = runtime_value;
    return &x;
}

fn returnPtrFromBlock() *i32 {
    var x: i32 = runtime_value;
    {
        return &x;
    }
}

fn returnPtrFromOptional() ?*i32 {
    var x: i32 = runtime_value;
    return &x;
}

fn returnPtrFromErrorUnion() !*i32 {
    var x: i32 = runtime_value;
    return &x;
}

pub fn main() void {
    _ = returnLocalPtr();
    _ = returnLocalPtrConst();
    _ = returnPtrFromBlock();
    _ = returnPtrFromOptional();
    _ = returnPtrFromErrorUnion() catch {};
}

// error
// backend=auto
// target=native
//
// :9:12: error: cannot return pointer to stack-allocated memory
// :14:12: error: cannot return pointer to stack-allocated memory
// :20:16: error: cannot return pointer to stack-allocated memory
// :26:12: error: cannot return pointer to stack-allocated memory
// :31:12: error: cannot return pointer to stack-allocated memory
