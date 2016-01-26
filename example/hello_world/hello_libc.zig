export executable "hello";

#link("c")
extern {
    fn printf(__format: &const u8, ...) -> c_int;
}

export fn main(argc: c_int, argv: &&u8) -> c_int {
    printf(c"Hello, world!\n");
    return 0;
}
