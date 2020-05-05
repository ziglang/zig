const Err = error{Foo};

fn foo() u8 {
    var x = @intCast(u8, 9);
    return x;
}

pub fn main() !u8 {
    if (foo() == 7) return Err.Foo;
    return 123;
}
