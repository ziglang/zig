/// UEFI Specification, Version 2.8, 4.2
pub const TableHeader = extern struct {
    signature: u64,
    revision: u32,
    header_size: u32,
    crc32: u32,
    reserved: u32,
};
