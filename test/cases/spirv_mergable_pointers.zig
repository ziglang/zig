export fn a() void {
    var x: *addrspace(.global) i32 = undefined;
    _ = &x;
    var y: *addrspace(.global) i32 = undefined;
    _ = &y;
    var rt_cond = false;
    _ = &rt_cond;

    var z = if (rt_cond) x else y;
    _ = &z;
}

// compile
// output_mode=Obj
// backend=stage2
// target=spirv64-vulkan
