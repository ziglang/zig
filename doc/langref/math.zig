extern fn print(i32) void;

export fn add(a: i32, b: i32) void {
    print(a + b);
}

// exe=succeed
// target=wasm32-freestanding
// additional_option=-fno-entry
// additional_option=--export=add
