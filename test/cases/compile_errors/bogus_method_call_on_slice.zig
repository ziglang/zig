var self = "aoeu";

fn f(m: []const u8) void {
    m.copy(u8, self[0..], m);
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&f));
}

pub export fn entry1() void {
    .{}.bar();
}

const S = struct { foo: i32 };
pub export fn entry2() void {
    const x = S{ .foo = 1 };
    x.bar();
}

// error
//
// :4:6: error: no field or member function named 'copy' in '[]const u8'
// :12:8: error: no field or member function named 'bar' in '@TypeOf(.{})'
// :18:6: error: no field or member function named 'bar' in 'bogus_method_call_on_slice.S'
// :15:11: note: struct declared here
