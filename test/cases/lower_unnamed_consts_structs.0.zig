const Foo = struct {
    a: u8,
    b: u32,

    fn first(self: *Foo) u8 {
        return self.a;
    }

    fn second(self: *Foo) u32 {
        return self.b;
    }
};

pub fn main() void {
    var foo = Foo{ .a = 1, .b = 5 };
    assert(foo.first() == 1);
    assert(foo.second() == 5);
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
