export executable "hello";

#link("c")
extern {
    fn printf(__format: *const u8, ...) -> i32;
}

export fn main(argc : isize, argv : *mut *mut u8, env : *mut *mut u8) -> i32 {
    printf("argc = %zu\n", argc);
    return 0;
}
