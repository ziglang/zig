export fn entry1() void {
    const x: u32 = 123;
    const ptr: [*]const u32 = @ptrCast(&x);
    _ = ptr - 1;
}

export fn entry2() void {
    const S = extern struct { x: u32, y: u32 };
    const y: u32 = 123;
    const parent_ptr: *const S = @fieldParentPtr("y", &y);
    _ = parent_ptr;
}

// error
//
// :4:13: error: pointer computation here causes undefined behavior
// :4:13: note: resulting pointer exceeds bounds of containing value which may trigger overflow
// :10:55: error: pointer computation here causes undefined behavior
// :10:55: note: resulting pointer exceeds bounds of containing value which may trigger overflow
