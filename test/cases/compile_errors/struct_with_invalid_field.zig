const std = @import(
    "std",
);
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const HeaderWeight = enum { H1, H2, H3, H4, H5, H6 };

const MdText = ArrayList(u8);

const MdNode = union(enum) {
    Header: struct {
        text: MdText,
        weight: HeaderValue,
    },
};

export fn entry() void {
    const a = MdNode.Header{
        .text = MdText.init(std.testing.allocator),
        .weight = HeaderWeight.H1,
    };
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :14:17: error: use of undeclared identifier 'HeaderValue'
