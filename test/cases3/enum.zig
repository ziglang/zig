fn enumType() {
    @setFnTest(this);

    const foo1 = Foo.One {13};
    const foo2 = Foo.Two { Point { .x = 1234, .y = 5678, }};
    const bar = Bar.B;

    assert(bar == Bar.B);
    assert(@memberCount(Foo) == 3);
    assert(@memberCount(Bar) == 4);
    const expected_foo_size = 16 + @sizeOf(usize);
    assert(@sizeOf(Foo) == expected_foo_size);
    assert(@sizeOf(Bar) == 1);
}

fn enumAsReturnValue () {
    @setFnTest(this);

    switch (returnAnInt(13)) {
        Foo.One => |value| assert(value == 13),
        else => @unreachable(),
    }
}

const Point = struct {
    x: u64,
    y: u64,
};
const Foo = enum {
    One: i32,
    Two: Point,
    Three: void,
};
const Bar = enum {
    A,
    B,
    C,
    D,
};

fn returnAnInt(x: i32) -> Foo {
    Foo.One { x }
}


fn constantEnumWithPayload() {
    @setFnTest(this);

    var empty = AnEnumWithPayload.Empty;
    var full = AnEnumWithPayload.Full {13};
    shouldBeEmpty(empty);
    shouldBeNotEmpty(full);
}

fn shouldBeEmpty(x: AnEnumWithPayload) {
    switch (x) {
        AnEnumWithPayload.Empty => {},
        else => @unreachable(),
    }
}

fn shouldBeNotEmpty(x: AnEnumWithPayload) {
    switch (x) {
        AnEnumWithPayload.Empty => @unreachable(),
        else => {},
    }
}

const AnEnumWithPayload = enum {
    Empty,
    Full: i32,
};



fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}



