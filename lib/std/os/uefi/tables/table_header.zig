pub const TableHeader = extern struct {
    signature: u64,
    revision: u32,

    /// The size, in bytes, of the entire table including the TableHeader
    header_size: u32,
    crc32: u32,
    reserved: u32,
};
