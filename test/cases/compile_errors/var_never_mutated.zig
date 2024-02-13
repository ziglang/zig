fn entry0() void {
    var a: u32 = 1 + 2;
    _ = a;
}

fn entry1() void {
    const a: u32 = 1;
    const b: u32 = 2;
    var c = a + b;
    const d = c;
    _ = d;
}

fn entry2() void {
    var a: u32 = 123;
    foo(a);
}

fn foo(_: u32) void {}

// error
//
// :2:9: error: local variable is never mutated
// :2:9: note: consider using 'const'
// :9:9: error: local variable is never mutated
// :9:9: note: consider using 'const'
// :15:9: error: local variable is never mutated
// :15:9: note: consider using 'const'
