pub const PE = struct {
    pub const absptr = 0x00;

    pub const size_mask = 0x7;
    pub const sign_mask = 0x8;
    pub const type_mask = size_mask | sign_mask;

    pub const uleb128 = 0x01;
    pub const udata2 = 0x02;
    pub const udata4 = 0x03;
    pub const udata8 = 0x04;
    pub const sleb128 = 0x09;
    pub const sdata2 = 0x0A;
    pub const sdata4 = 0x0B;
    pub const sdata8 = 0x0C;

    pub const rel_mask = 0x70;
    pub const pcrel = 0x10;
    pub const textrel = 0x20;
    pub const datarel = 0x30;
    pub const funcrel = 0x40;
    pub const aligned = 0x50;

    pub const indirect = 0x80;

    pub const omit = 0xff;
};
