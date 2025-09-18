// Test: Stack escape detection - Part 3: Slice escapes
// This file tests returning slices to stack-allocated memory

// Force runtime evaluation with this global
var runtime_value: i32 = 42;

// Direct slice return from stack array
fn returnDirectSlice() []const u8 {
    var buffer: [10]u8 = undefined;
    buffer[0] = @intCast(runtime_value);
    return buffer[0..5];
}

// Array to slice conversion
fn returnArrayToSlice() []const u8 {
    var arr = [_]u8{ 1, 2, 3, 4, @intCast(runtime_value) };
    const slice: []const u8 = &arr;
    return slice;
}

// Slice pointer extraction
fn returnSlicePtr() [*]const u8 {
    var buffer: [10]u8 = undefined;
    buffer[0] = @intCast(runtime_value);
    const slice = buffer[0..];
    return slice.ptr;
}

pub fn main() void {
    _ = returnDirectSlice();
    _ = returnArrayToSlice();
    _ = returnSlicePtr();
}

// error
// backend=auto
// target=native
//
// :11:18: error: cannot return pointer to stack-allocated memory
// :18:12: error: cannot return slice of stack-allocated memory
// :26:17: error: cannot return pointer to stack-allocated memory
