const std = @import("../../../../std.zig");
const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;

pub const PartitionInfo = extern struct {
    pub const Type = enum(u32) {
        other = 0,
        mbr = 1,
        gpt = 2,
        _,
    };

    revision: u32 align(1),

    /// The type of partition info
    type: Type align(1),

    /// If true, this partition is an EFI system partition
    system: bool,

    reserved: [7]u8,

    info: extern union {
        mbr: MbrEntry,
        gpt: GptEntry,
    },

    pub const guid align(8) = Guid{
        .time_low = 0x8cf2f62c,
        .time_mid = 0xbc9b,
        .time_high_and_version = 0x4821,
        .clock_seq_high_and_reserved = 0x80,
        .clock_seq_low = 0x8d,
        .node = [_]u8{ 0xec, 0x9e, 0xc4, 0x21, 0xa1, 0xa0 },
    };

    pub const MbrEntry = extern struct {
        pub const Record = extern struct {
            pub const OsType = enum(u8) {
                efi_system_partition = 0xef,
                gpt_protective_mbr = 0xee,
                _,
            };

            /// 0x80 indicates this is the legacy boot partition. Shall not be used by UEFI firmware.
            boot_indicator: u8,

            /// Start of partiion in CHS address format. Shall not be used by UEFI firmware.
            starting_chs: [3]u8,

            /// Type of partition,
            os_type: OsType,

            /// End of partition in CHS address format. Shall not be used by UEFI firmware.
            ending_chs: [3]u8,

            /// Starting LBA of the partition on the disk. This is used by UEFI to find the start of the partition.
            starting_lba: u32,

            /// Size of the partiion in LBA units. This is used by UEFI to find the size of the partition.
            size_in_lba: u32,
        };

        /// Shall not be used by UEFI firmware.
        boot_code: [424]u8,

        /// Used to identify the disk, never written by UEFI firmware.
        unique_disk_signature: u32,

        /// Shall not be used by UEFI firmware.
        unknown: [2]u8,

        /// The 4 partition records.
        partition_record: [4]Record,

        /// The MBR signature
        signature: [2]u8 = [_]u8{ 0x55, 0xaa },
    };

    pub const GptEntry = extern struct {
        pub const Attributes = packed struct {
            /// If this bit is set, the partition is required for the platform to function.
            required: bool,

            /// If this bit is set, then firmware must not produce an EFI_BLOCK_IO_PROTOCOL device for this partition.
            no_block: bool,

            /// This bit is set aside by this specification to let systems with traditional PC-AT BIOS firmware
            /// implementations inform certain limited, special-purpose software running on these systems that a GPT
            /// partition may be bootable.
            legacy_bios_bootable: bool,

            /// Must be zero
            reserved: u45,

            /// Reserved for GUID specific use.
            guid_specific: u16,
        };

        /// Unique ID that defines the purpose and type of this Partition. A value of zero defines that this
        /// partition entry is not being used.
        partition_type: Guid,

        /// GUID that is unique for every partition entry. Every partition ever created will have a unique GUID. This
        /// GUID must be assigned when the GPT Partition Entry is created.
        unique_partition_guid: Guid,

        /// Starting LBA of the partition defined by this entry.
        starting_lba: u64,

        /// Ending LBA of the partition defined by this entry.
        ending_lba: u64,

        /// Attribute bits, all bits reserved by UEFI
        attributes: Attributes,

        /// Null-terminated string containing a human-readable name of the partition.
        partition_name: [36]u16,

        /// The human readable name of the partition.
        pub fn getName(self: *const GptEntry) []const u16 {
            return std.mem.sliceTo(&self.partition_name, 0);
        }
    };
};
