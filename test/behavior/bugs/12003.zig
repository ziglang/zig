test {
    comptime {
        const tuple_with_ptrs = .{ &0, &0 };
        const field_ptr = (&tuple_with_ptrs.@"0");
        _ = field_ptr.*;
    }
}
