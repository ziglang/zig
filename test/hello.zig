extern {
    fn puts(s: *mut u8) -> i32;
}

fn main(argc: i32, argv: *mut *mut u8) -> i32 {
    puts("Hello, world!\n");
    return 0;
}
