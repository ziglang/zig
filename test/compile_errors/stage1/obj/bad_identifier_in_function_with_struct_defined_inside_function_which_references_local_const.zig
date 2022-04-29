export fn entry() void {
    const BlockKind = u32;

    const Block = struct {
        kind: BlockKind,
    };

    bogus;

    _ = Block;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:8:5: error: use of undeclared identifier 'bogus'
