pub fn main() void {
    _ = @import(
        "bogus-does-not-exist.zon",
    );
}

// error
// backend=stage2
// target=native
// output_mode=Exe
//
// :3:9: error: unable to open 'bogus-does-not-exist.zon': FileNotFound
