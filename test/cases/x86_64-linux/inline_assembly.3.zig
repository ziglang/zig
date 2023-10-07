pub fn main() void {}
comptime {
    asm (""
        :
        : [bruh] "{rax}" (4),
        : "memory"
    );
}

// error
//
// :3:5: error: global assembly cannot have inputs, outputs, or clobbers
