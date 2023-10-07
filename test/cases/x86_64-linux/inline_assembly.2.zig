pub fn main() void {
    var bruh: u32 = 1;
    asm (""
        :
        : [bruh] "{rax}" (4),
        : "memory"
    );
}

// error
//
// :3:5: error: assembly expression with no output must be marked volatile
