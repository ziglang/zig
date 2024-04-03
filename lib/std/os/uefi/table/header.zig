const bits = @import("../bits.zig");

pub const Header = extern struct {
    signature: u64,

    /// The revision of the EFI Specification to which this table conforms.
    ///
    /// Encoded as `(major << 16) | (minor * 10) | (patch)`.
    revision: u32,

    /// The size, in bytes, of the entire table including the TableHeader
    header_size: u32,
    crc32: u32,
    reserved: u32,

    /// Validates the table by ensuring that the signature and CRC fields are correct.
    pub fn validate(self: *const Header, signature: u64) bool {
        if (self.reserved != 0) return false;
        if (self.signature != signature) return false;

        const byte_ptr: [*]const u8 = @ptrCast(self);

        var crc = bits.Crc32.init();
        crc.update(byte_ptr[0..16]);
        crc.update(&.{ 0, 0, 0, 0 }); // crc32 field replaced with 0
        crc.update(byte_ptr[20..self.header_size]);
        return crc.final() == self.crc32;
    }

    /// Checks if the table is at least the specified revision.
    pub fn isAtLeastRevision(self: *const Header, major: u16, minor: u16) bool {
        return self.revision >= (@as(u32, major) << 16) | minor;
    }
};
