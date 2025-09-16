export fn entry() void {
    const x: u32 = 0;
    switch (x) {}
}

// error
//
// :3:5: error: switch must handle all possibilities
