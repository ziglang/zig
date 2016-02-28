const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("Hello, world!\n");
}
