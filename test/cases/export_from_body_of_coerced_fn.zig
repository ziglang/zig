fn original() usize {
    _ = struct {
        export const val: u32 = 123;
    };
    return 0;
}

pub fn main() void {
    const coerced: fn () u64 = original;
    _ = coerced();

    const S = struct {
        extern const val: u32;
    };
    if (S.val != 123) @panic("wrong value");
}

// run
// target=x86_64-linux
