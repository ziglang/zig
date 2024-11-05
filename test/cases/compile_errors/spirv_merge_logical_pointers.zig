export fn a() void {
    var x: *i32 = undefined;
    _ = &x;
    var y: *i32 = undefined;
    _ = &y;
    var rt_cond = false;
    _ = &rt_cond;

    var z = if (rt_cond) x else y;
    _ = &z;
}

// error
// backend=stage2
// target=spirv64-vulkan
//
// :9:13: error: value with non-mergable pointer type '*i32' depends on runtime control flow
// :9:17: note: runtime control flow here
// :9:13: note: pointers with address space 'generic' cannot be returned from a branch on target spirv-vulkan by compiler backend stage2_spirv64
