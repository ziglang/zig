comptime {
    _ = @SpirvType(.{ .runtime_array = u32 });
}

// error
// backend=stage2
// target=x86_64-native
//
// :2:21: error: builtin @SpirvType is available when targeting SPIR-V; targeted CPU architecture is x86_64
