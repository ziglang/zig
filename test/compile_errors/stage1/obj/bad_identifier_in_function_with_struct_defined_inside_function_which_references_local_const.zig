export fn entry() void {
    const BlockKind = u32;

    const Block = struct {
        kind: BlockKind,
    };

    bogus;

    _ = Block;
}

// bad identifier in function with struct defined inside function which references local const
//
// tmp.zig:8:5: error: use of undeclared identifier 'bogus'
