const msg = "Hello, World!\n";

fn length() usize {
    return msg.len;
}

pub fn main() void {
    asm volatile ("ta 0x6d"
        :
        : [number] "{g1}" (4),
          [arg1] "{o0}" (1),
          [arg2] "{o1}" (@ptrToInt(msg)),
          [arg3] "{o2}" (length()),
        : "o0", "o1", "o2", "o3", "o4", "o5", "o6", "o7", "memory"
    );
}

// run
// target=sparc64-linux
//
// Hello, World!
//
