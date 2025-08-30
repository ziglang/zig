export fn elemPtr() void {
    var ptr: [*]u8 = undefined;
    ptr[0] = 0;
}

export fn elemVal() void {
    var ptr: [*]u8 = undefined;
    var val = ptr[0];
    _ = &ptr;
    _ = &val;
}

export fn intFromPtr() void {
    var value: u8 = 0;
    _ = @intFromPtr(&value);
}

export fn ptrFromInt() void {
    var v: u32 = 0x1234;
    var ptr: *u8 = @ptrFromInt(v);
    _ = &v;
    _ = &ptr;
}

export fn ptrPtrArithmetic() void {
    var value0: u8 = 0;
    var value1: u8 = 0;
    _ = &value0 - &value1;
}

export fn ptrIntArithmetic() void {
    var ptr0: [*]u8 = undefined;
    _ = &ptr0;
    _ = ptr0 - 10;
}

// error
// backend=stage2
// target=spirv64-vulkan
//
// :3:8: error: illegal operation on logical pointer of type '[*]u8'
// :3:8: note: cannot perform arithmetic on pointers with address space 'generic' on target spirv-vulkan
// :8:18: error: illegal operation on logical pointer of type '[*]u8'
// :8:18: note: cannot perform arithmetic on pointers with address space 'generic' on target spirv-vulkan
// :15:21: error: illegal operation on logical pointer of type '*u8'
// :15:21: note: cannot perform arithmetic on pointers with address space 'generic' on target spirv-vulkan
// :20:20: error: illegal operation on logical pointer of type '*u8'
// :20:20: note: cannot perform arithmetic on pointers with address space 'generic' on target spirv-vulkan
// :28:17: error: illegal operation on logical pointer of type '*u8'
// :28:17: note: cannot perform arithmetic on pointers with address space 'generic' on target spirv-vulkan
// :34:14: error: illegal operation on logical pointer of type '[*]u8'
// :34:14: note: cannot perform arithmetic on pointers with address space 'generic' on target spirv-vulkan
