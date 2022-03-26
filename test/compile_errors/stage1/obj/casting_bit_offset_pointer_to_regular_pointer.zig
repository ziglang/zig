const BitField = packed struct {
    a: u3,
    b: u3,
    c: u2,
};

fn foo(bit_field: *const BitField) u3 {
    return bar(&bit_field.b);
}

fn bar(x: *const u3) u3 {
    return x.*;
}

export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// casting bit offset pointer to regular pointer
//
// tmp.zig:8:26: error: expected type '*const u3', found '*align(:3:1) const u3'
