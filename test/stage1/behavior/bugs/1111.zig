const Foo = extern enum {
    Bar = -1,
};

test "issue 1111 fixed" {
    const v = Foo.Bar;

    switch (v) {
        Foo.Bar => return,
    }
}
