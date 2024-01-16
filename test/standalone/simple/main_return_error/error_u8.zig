const Err = error{Foo};

pub fn main() !u8 {
    return Err.Foo;
}
