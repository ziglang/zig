export fn entry() void {
    const llamas1 = makeLlamas(5);
    const llamas2 = makeLlamas(5);
    _ = llamas1;
    _ = llamas2;
}

fn makeLlamas(count: usize) [count]u8 {}

// error
//
// :8:30: error: unable to resolve comptime value
// :8:30: note: array length must be comptime-known
// :2:31: note: generic function instantiated here
