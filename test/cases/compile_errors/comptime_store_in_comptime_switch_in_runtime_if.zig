fn foo() bool {
    return false;
}

pub export fn entry() void {
    const Widget = union(enum) { a: u0 };

    comptime var a = 1;
    const info = @typeInfo(Widget).Union;
    inline for (info.fields) |field| {
        if (foo()) {
            switch (field.type) {
                u0 => a = 2,
                else => unreachable,
            }
        }
    }
}

// error
// backend=stage2
// target=native
//
// :13:25: error: store to comptime variable depends on runtime condition
// :11:16: note: runtime condition here
