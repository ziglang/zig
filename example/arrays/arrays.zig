export executable "arrays";

#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

export fn _start() -> unreachable {
    let mut array : [i32; 10];

    array[4] = array[1] + 5;


    exit(0); 
}
