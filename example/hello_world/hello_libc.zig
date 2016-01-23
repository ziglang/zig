export executable "hello";

#link("c")
extern {
    fn printf(__format: &const u8, ...) i32;
}

export fn main(argc: i32, argv: &&u8) i32 => {
    printf(c"Hello, world!\n");
    return 0;
}
