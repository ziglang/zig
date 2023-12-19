const uefi = @import("../../uefi.zig");

pub const TableHeader = extern struct {
    signature: u64,
    revision: u32,

    /// The size, in bytes, of the entire table including the TableHeader
    header_size: u32,
    crc32: u32,
    reserved: u32,

    pub fn validate(self: *const TableHeader, signature: u64) bool {
        if (self.reserved != 0) return false;
        if (self.signature != signature) return false;

        const byte_ptr: [*]const u8 = @ptrCast(self);

        var crc = uefi.Crc32.init();
        crc.update(byte_ptr[0..16]);
        crc.update(&.{ 0, 0, 0, 0 }); // crc32 field replaced with 0
        crc.update(byte_ptr[20..self.header_size]);
        return crc.finish() == self.crc32;
    }

    pub fn isAtLeastRevision(self: *const TableHeader, major: u16, minor: u16) bool {
        return self.revision >= (@as(u32, major) << 16) | minor;
    }
};
