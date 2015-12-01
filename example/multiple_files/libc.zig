#link("c")
extern {
    pub fn puts(s: *mut u8) -> i32;
    pub fn exit(code: i32) -> unreachable;
}
