const A = struct { u32 };
const E = extern struct { u32 };
const P = packed struct { u32 };

const a: A = .{0};
const e: E = .{0};
const p: P = .{0};

comptime {
    _ = a ++ e;
}

comptime {
    _ = a ++ p;
}

comptime {
    _ = e ++ p;
}

// error
// backend=stage2
// target=native
//
// :10:11: error: cannot concatenate tuples with different layouts
// :10:9: note: first operand has layout 'Auto'
// :10:14: note: second operand has layout 'Extern'
// :14:11: error: cannot concatenate tuples with different layouts
// :14:9: note: first operand has layout 'Auto'
// :14:14: note: second operand has layout 'Packed'
// :18:11: error: cannot concatenate tuples with different layouts
// :18:9: note: first operand has layout 'Extern'
// :18:14: note: second operand has layout 'Packed'
