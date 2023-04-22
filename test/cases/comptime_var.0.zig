pub fn main() void {
    var a: u32 = 0;
    comptime var b: u32 = 0;
    if (a == 0) b = 3;
}

// error
// output_mode=Exe
// target=x86_64-macos,x86_64-linux
// link_libc=true
//
// :4:19: error: store to comptime variable depends on runtime condition
// :4:11: note: runtime condition here
