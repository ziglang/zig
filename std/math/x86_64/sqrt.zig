pub fn sqrt32(x: f32) -> f32 {
    return asm (
        \\sqrtss %%xmm0, %%xmm0
        : [ret] "={xmm0}" (-> f32)
        : [x] "{xmm0}" (x)
    );
}

pub fn sqrt64(x: f64) -> f64 {
    return asm (
        \\sqrtsd %%xmm0, %%xmm0
        : [ret] "={xmm0}" (-> f64)
        : [x] "{xmm0}" (x)
    );
}
