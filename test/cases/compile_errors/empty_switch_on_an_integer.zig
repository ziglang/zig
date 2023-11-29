export fn entry() void {
    const x: u32 = 0;
    switch (x) {}
}

// error
// backend=stage2
// target=native
//
// :3:5: error: switch must handle all possibilities
