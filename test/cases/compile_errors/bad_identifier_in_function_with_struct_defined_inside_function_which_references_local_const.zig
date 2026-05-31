export fn entry() void {
    const BlockKind = u32;

    const Block = struct {
        kind: BlockKind,
    };

    bogus;

    _ = Block;
}

// error
//
// :8:5: error: use of undeclared identifier 'bogus'
