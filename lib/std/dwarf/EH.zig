pub const PE = packed struct(u8) {
    type: Type,
    rel: Rel,
    /// Undocumented GCC extension
    indirect: bool = false,

    /// This is a special encoding which does not correspond to named `type`/`rel` values.
    pub const omit: PE = @bitCast(@as(u8, 0xFF));

    pub const Type = enum(u4) {
        absptr = 0x0,
        uleb128 = 0x1,
        udata2 = 0x2,
        udata4 = 0x3,
        udata8 = 0x4,
        sleb128 = 0x9,
        sdata2 = 0xA,
        sdata4 = 0xB,
        sdata8 = 0xC,
        _,
    };

    /// The specification considers this a `u4`, but the GCC `indirect` field extension conflicts
    /// with that, so we consider it a `u3` instead.
    pub const Rel = enum(u3) {
        abs = 0x0,
        pcrel = 0x1,
        textrel = 0x2,
        datarel = 0x3,
        funcrel = 0x4,
        aligned = 0x5,
        _,
    };
};
