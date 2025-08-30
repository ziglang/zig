const SomeVeryLongName = struct {};

fn foo(a: *SomeVeryLongName) void {
    _ = a;
}

export fn entry() void {
    const a: SomeVeryLongName = .{};

    foo(a);
}

// error
// backend=stage2
// target=native
//
// :12:9: error: expected type '*<T>' but found '<T>'
// :12:9: note: <T> = SomeVeryLongName
// :3:35: note: struct declared here
// :5:11: note: parameter type declared here
