export executable "arrays";

#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

export fn _start() -> unreachable {
    let mut array : [i32; 5];

    let mut i = 0;
loop_start:
    if i == 5 {
        goto loop_end;
    }
    array[i] = i + 1;
    i = array[i];
    goto loop_start;

loop_end:

    i = 0;
    let mut accumulator = 0;
loop_2_start:
    if i == 5 {
        goto loop_2_end;
    }

    accumulator = accumulator + array[i];

    i = i + 1;
    goto loop_2_start;
loop_2_end:

    if accumulator == 15 {
        puts("OK");
    }

    exit(0);
}
