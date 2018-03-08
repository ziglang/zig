        .global foo
        .type foo, @object
        .size foo, 4
foo:
        .weak bar
        .type bar, @object
        .size bar, 4
bar:
        .long 42

        .weak zed
        .type zed, @object
        zed = 0x1000
