const Err = error{Foo};

fn foo() u8 {
    var x = @as(u8, @intCast(9));
    return x;
}

pub fn main() !u8 {
    if (foo() == 7) return Err.Foo;
    return 123;
}
