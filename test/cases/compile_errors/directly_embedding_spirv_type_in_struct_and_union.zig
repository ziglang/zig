const Sampler = @SpirvType(.sampler);
const RuntimeArray = @SpirvType(.{ .runtime_array = u32 });
const Foo = struct {
    s: Sampler,
};
const Bar = union {
    One: i32,
    Two: Sampler,
};
const Baz = struct {
    a: RuntimeArray,
};
const Qux = extern struct {
    a: RuntimeArray,
    b: u32,
};
export fn a() void {
    var foo: Foo = undefined;
    _ = &foo;
}
export fn b() void {
    var bar: Bar = undefined;
    _ = &bar;
}
export fn c() void {
    var baz: Baz = undefined;
    _ = &baz;
}
export fn d() void {
    var qux: Qux = undefined;
    _ = &qux;
}

// error
// backend=stage2
// target=spirv64-vulkan
//
// :4:8: error: SPIR-V type 'tmp.Sampler__SpirvType_87' have unknown size and therefore cannot be directly embedded in structs
// :8:10: error: SPIR-V type 'tmp.Sampler__SpirvType_87' have unknown size and therefore cannot be directly embedded in unions
// :10:13: error: non-extern struct cannot contain fields of type 'tmp.RuntimeArray__SpirvType_8'
// :11:5: note: while checking this field
// :13:20: error: struct field of type 'tmp.RuntimeArray__SpirvType_8' must be the last field
// :14:5: note: while checking this field
