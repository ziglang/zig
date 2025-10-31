const SomeVeryLongName = struct {};

fn foo(a: *SomeVeryLongName) void {
    _ = a;
}

export fn entry() void {
    const a: SomeVeryLongName = .{};

    foo(a);
}

// error
//
// :10:9: error: expected type '*<T>', found '<T>'
// :10:9: note: <T> = tmp.SomeVeryLongName
// :1:26: note: struct declared here
// :3:11: note: parameter type declared here
