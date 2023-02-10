comptime {
    const S = struct {
        const Foo = struct {
            y: Bar,
        };
        const Bar = struct {
            y: if (@sizeOf(Foo) == 0) u64 else void,
        };
    };

    _ = @sizeOf(S.Foo) + 1;
}

// error
// backend=stage2
// target=native
//
// :6:21: error: struct layout depends on it having runtime bits
// :4:13: note: while checking this field
