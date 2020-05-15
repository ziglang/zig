pub const TheStruct = extern struct {
    value: u32,
    array: [4]u32,
    p_value: *const u32,
    inner: InnerStruct,
};

pub const InnerStruct = extern struct {
    value: u32,
};

pub const TheUnion = extern union {
    U32: u32,
    Bool: bool,
};
