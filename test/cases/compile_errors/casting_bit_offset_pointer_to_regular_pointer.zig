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

export fn entry() usize { return @sizeOf(@TypeOf(&foo)); }

// error
// backend=stage2
// target=native
//
// :8:15: error: expected type '*const u3', found '*align(0:3:1) const u3'
// :8:15: note: pointer host size '1' cannot cast into pointer host size '0'
// :8:15: note: pointer bit offset '3' cannot cast into pointer bit offset '0'
