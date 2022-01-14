const std = @import("std");
const mem = std.mem;
const uefi = std.os.uefi;
const Allocator = mem.Allocator;
const Guid = uefi.Guid;

pub const DevicePathProtocol = packed struct {
    type: DevicePathType,
    subtype: u8,
    length: u16,

    pub const guid align(8) = Guid{
        .time_low = 0x09576e91,
        .time_mid = 0x6d3f,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };

    /// Returns the next DevicePathProtocol node in the sequence, if any.
    pub fn next(self: *DevicePathProtocol) ?*DevicePathProtocol {
        if (self.type == .End and @intToEnum(EndDevicePath.Subtype, self.subtype) == .EndEntire)
            return null;

        return @ptrCast(*DevicePathProtocol, @ptrCast([*]u8, self) + self.length);
    }

    /// Calculates the total length of the device path structure in bytes, including the end of device path node.
    pub fn size(self: *DevicePathProtocol) usize {
        var node = self;

        while (node.next()) |next_node| {
            node = next_node;
        }

        return (@ptrToInt(node) + node.length) - @ptrToInt(self);
    }

    /// Creates a file device path from the existing device path and a file path.
    pub fn create_file_device_path(self: *DevicePathProtocol, allocator: Allocator, path: [:0]const u16) !*DevicePathProtocol {
        var path_size = self.size();

        // 2 * (path.len + 1) for the path and its null terminator, which are u16s
        // DevicePathProtocol for the extra node before the end
        var buf = try allocator.alloc(u8, path_size + 2 * (path.len + 1) + @sizeOf(DevicePathProtocol));

        mem.copy(u8, buf, @ptrCast([*]const u8, self)[0..path_size]);

        // Pointer to the copy of the end node of the current chain, which is - 4 from the buffer
        // as the end node itself is 4 bytes (type: u8 + subtype: u8 + length: u16).
        var new = @ptrCast(*MediaDevicePath.FilePathDevicePath, buf.ptr + path_size - 4);

        new.type = .Media;
        new.subtype = .FilePath;
        new.length = @sizeOf(MediaDevicePath.FilePathDevicePath) + 2 * (@intCast(u16, path.len) + 1);

        // The same as new.getPath(), but not const as we're filling it in.
        var ptr = @ptrCast([*:0]u16, @alignCast(2, @ptrCast([*]u8, new)) + @sizeOf(MediaDevicePath.FilePathDevicePath));

        for (path) |s, i|
            ptr[i] = s;

        ptr[path.len] = 0;

        var end = @ptrCast(*EndDevicePath.EndEntireDevicePath, @ptrCast(*DevicePathProtocol, new).next().?);
        end.type = .End;
        end.subtype = .EndEntire;
        end.length = @sizeOf(EndDevicePath.EndEntireDevicePath);

        return @ptrCast(*DevicePathProtocol, buf.ptr);
    }

    pub fn getDevicePath(self: *const DevicePathProtocol) ?DevicePath {
        return switch (self.type) {
            .Hardware => blk: {
                const hardware: ?HardwareDevicePath = switch (@intToEnum(HardwareDevicePath.Subtype, self.subtype)) {
                    .Pci => .{ .Pci = @ptrCast(*const HardwareDevicePath.PciDevicePath, self) },
                    .PcCard => .{ .PcCard = @ptrCast(*const HardwareDevicePath.PcCardDevicePath, self) },
                    .MemoryMapped => .{ .MemoryMapped = @ptrCast(*const HardwareDevicePath.MemoryMappedDevicePath, self) },
                    .Vendor => .{ .Vendor = @ptrCast(*const HardwareDevicePath.VendorDevicePath, self) },
                    .Controller => .{ .Controller = @ptrCast(*const HardwareDevicePath.ControllerDevicePath, self) },
                    .Bmc => .{ .Bmc = @ptrCast(*const HardwareDevicePath.BmcDevicePath, self) },
                    _ => null,
                };
                break :blk if (hardware) |h| .{ .Hardware = h } else null;
            },
            .Acpi => blk: {
                const acpi: ?AcpiDevicePath = switch (@intToEnum(AcpiDevicePath.Subtype, self.subtype)) {
                    .Acpi => .{ .Acpi = @ptrCast(*const AcpiDevicePath.BaseAcpiDevicePath, self) },
                    .ExpandedAcpi => .{ .ExpandedAcpi = @ptrCast(*const AcpiDevicePath.ExpandedAcpiDevicePath, self) },
                    .Adr => .{ .Adr = @ptrCast(*const AcpiDevicePath.AdrDevicePath, self) },
                    _ => null,
                };
                break :blk if (acpi) |a| .{ .Acpi = a } else null;
            },
            .Messaging => blk: {
                const messaging: ?MessagingDevicePath = switch (@intToEnum(MessagingDevicePath.Subtype, self.subtype)) {
                    else => null, // TODO
                };
                break :blk if (messaging) |m| .{ .Messaging = m } else null;
            },
            .Media => blk: {
                const media: ?MediaDevicePath = switch (@intToEnum(MediaDevicePath.Subtype, self.subtype)) {
                    .HardDrive => .{ .HardDrive = @ptrCast(*const MediaDevicePath.HardDriveDevicePath, self) },
                    .Cdrom => .{ .Cdrom = @ptrCast(*const MediaDevicePath.CdromDevicePath, self) },
                    .Vendor => .{ .Vendor = @ptrCast(*const MediaDevicePath.VendorDevicePath, self) },
                    .FilePath => .{ .FilePath = @ptrCast(*const MediaDevicePath.FilePathDevicePath, self) },
                    .MediaProtocol => .{ .MediaProtocol = @ptrCast(*const MediaDevicePath.MediaProtocolDevicePath, self) },
                    .PiwgFirmwareFile => .{ .PiwgFirmwareFile = @ptrCast(*const MediaDevicePath.PiwgFirmwareFileDevicePath, self) },
                    .PiwgFirmwareVolume => .{ .PiwgFirmwareVolume = @ptrCast(*const MediaDevicePath.PiwgFirmwareVolumeDevicePath, self) },
                    .RelativeOffsetRange => .{ .RelativeOffsetRange = @ptrCast(*const MediaDevicePath.RelativeOffsetRangeDevicePath, self) },
                    .RamDisk => .{ .RamDisk = @ptrCast(*const MediaDevicePath.RamDiskDevicePath, self) },
                    _ => null,
                };
                break :blk if (media) |m| .{ .Media = m } else null;
            },
            .BiosBootSpecification => blk: {
                const bbs: ?BiosBootSpecificationDevicePath = switch (@intToEnum(BiosBootSpecificationDevicePath.Subtype, self.subtype)) {
                    .BBS101 => .{ .BBS101 = @ptrCast(*const BiosBootSpecificationDevicePath.BBS101DevicePath, self) },
                    _ => null,
                };
                break :blk if (bbs) |b| .{ .BiosBootSpecification = b } else null;
            },
            .End => blk: {
                const end: ?EndDevicePath = switch (@intToEnum(EndDevicePath.Subtype, self.subtype)) {
                    .EndEntire => .{ .EndEntire = @ptrCast(*const EndDevicePath.EndEntireDevicePath, self) },
                    .EndThisInstance => .{ .EndThisInstance = @ptrCast(*const EndDevicePath.EndThisInstanceDevicePath, self) },
                    _ => null,
                };
                break :blk if (end) |e| .{ .End = e } else null;
            },
            _ => null,
        };
    }
};

pub const DevicePath = union(DevicePathType) {
    Hardware: HardwareDevicePath,
    Acpi: AcpiDevicePath,
    Messaging: MessagingDevicePath,
    Media: MediaDevicePath,
    BiosBootSpecification: BiosBootSpecificationDevicePath,
    End: EndDevicePath,
};

pub const DevicePathType = enum(u8) {
    Hardware = 0x01,
    Acpi = 0x02,
    Messaging = 0x03,
    Media = 0x04,
    BiosBootSpecification = 0x05,
    End = 0x7f,
    _,
};

pub const HardwareDevicePath = union(Subtype) {
    Pci: *const PciDevicePath,
    PcCard: *const PcCardDevicePath,
    MemoryMapped: *const MemoryMappedDevicePath,
    Vendor: *const VendorDevicePath,
    Controller: *const ControllerDevicePath,
    Bmc: *const BmcDevicePath,

    pub const Subtype = enum(u8) {
        Pci = 1,
        PcCard = 2,
        MemoryMapped = 3,
        Vendor = 4,
        Controller = 5,
        Bmc = 6,
        _,
    };

    pub const PciDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        function: u8,
        device: u8,
    };

    pub const PcCardDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        function_number: u8,
    };

    pub const MemoryMappedDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        memory_type: u32,
        start_address: u64,
        end_address: u64,
    };

    pub const VendorDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        vendor_guid: Guid,
    };

    pub const ControllerDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        controller_number: u32,
    };

    pub const BmcDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        interface_type: u8,
        base_address: usize,
    };
};

pub const AcpiDevicePath = union(Subtype) {
    Acpi: *const BaseAcpiDevicePath,
    ExpandedAcpi: *const ExpandedAcpiDevicePath,
    Adr: *const AdrDevicePath,

    pub const Subtype = enum(u8) {
        Acpi = 1,
        ExpandedAcpi = 2,
        Adr = 3,
        _,
    };

    pub const BaseAcpiDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        hid: u32,
        uid: u32,
    };

    pub const ExpandedAcpiDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        hid: u32,
        uid: u32,
        cid: u32,
        // variable length u16[*:0] strings
        // hid_str, uid_str, cid_str
    };

    pub const AdrDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        adr: u32,
        // multiple adr entries can optionally follow
        pub fn adrs(self: *const AdrDevicePath) []const u32 {
            // self.length is a minimum of 8 with one adr which is size 4.
            var entries = (self.length - 4) / @sizeOf(u32);
            return @ptrCast([*]const u32, &self.adr)[0..entries];
        }
    };
};

pub const MessagingDevicePath = union(Subtype) {
    Atapi: *const AtapiDevicePath,
    Scsi: *const ScsiDevicePath,
    FibreChannel: *const FibreChannelDevicePath,
    FibreChannelEx: FibreChannelExDevicePath,
    @"1394": *const F1394DevicePath,
    Usb: *const UsbDevicePath,
    Sata: *const SataDevicePath,
    UsbWwid: *const UsbWwidDevicePath,
    Lun: *const DeviceLogicalUnitDevicePath,
    UsbClass: *const UsbClassDevicePath,
    I2o: *const I2oDevicePath,
    MacAddress: *const MacAddressDevicePath,
    Ipv4: *const Ipv4DevicePath,
    Ipv6: *const Ipv6DevicePath,
    Vlan: *const VlanDevicePath,
    InfiniBand: *const InfiniBandDevicePath,
    Uart: *const UartDevicePath,
    Vendor: *const VendorDefinedDevicePath,

    pub const Subtype = enum(u8) {
        Atapi = 1,
        Scsi = 2,
        FibreChannel = 3,
        FibreChannelEx = 21,
        @"1394" = 4,
        Usb = 5,
        Sata = 18,
        UsbWwid = 16,
        Lun = 17,
        UsbClass = 15,
        I2o = 6,
        MacAddress = 11,
        Ipv4 = 12,
        Ipv6 = 13,
        Vlan = 20,
        InfiniBand = 9,
        Uart = 14,
        Vendor = 10,
        _,
    };

    pub const AtapiDevicePath = packed struct {
        const Role = enum(u8) {
            Master = 0,
            Slave = 1,
        };

        const Rank = enum(u8) {
            Primary = 0,
            Secondary = 1,
        };

        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        primary_secondary: Rank,
        slave_master: Role,
        logical_unit_number: u16,
    };

    pub const ScsiDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        target_id: u16,
        logical_unit_number: u16,
    };

    pub const FibreChannelDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        reserved: u32,
        world_wide_name: u64,
        logical_unit_number: u64,
    };

    pub const FibreChannelExDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        reserved: u32,
        world_wide_name: [8]u8,
        logical_unit_number: [8]u8,
    };

    pub const F1394DevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        reserved: u32,
        guid: u64,
    };

    pub const UsbDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        parent_port_number: u8,
        interface_number: u8,
    };

    pub const SataDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        hba_port_number: u16,
        port_multiplier_port_number: u16,
        logical_unit_number: u16,
    };

    pub const UsbWwidDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        interface_number: u16,
        device_vendor_id: u16,
        device_product_id: u16,

        pub fn serial_number(self: *const UsbWwidDevicePath) []const u16 {
            var serial_len = (self.length - @sizeOf(UsbWwidDevicePath)) / @sizeOf(u16);
            return @ptrCast([*]u16, @ptrCast([*]u8, self) + @sizeOf(UsbWwidDevicePath))[0..serial_len];
        }
    };

    pub const DeviceLogicalUnitDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        lun: u8,
    };

    pub const UsbClassDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        vendor_id: u16,
        product_id: u16,
        device_class: u8,
        device_subclass: u8,
        device_protocol: u8,
    };

    pub const I2oDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        tid: u32,
    };

    pub const MacAddressDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        mac_address: uefi.MacAddress,
        if_type: u8,
    };

    pub const Ipv4DevicePath = packed struct {
        pub const IpType = enum(u8) {
            Dhcp = 0,
            Static = 1,
        };

        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        local_ip_address: uefi.Ipv4Address,
        remote_ip_address: uefi.Ipv4Address,
        local_port: u16,
        remote_port: u16,
        network_protocol: u16,
        static_ip_address: IpType,
        gateway_ip_address: u32,
        subnet_mask: u32,
    };

    pub const Ipv6DevicePath = packed struct {
        pub const Origin = enum(u8) {
            Manual = 0,
            AssignedStateless = 1,
            AssignedStateful = 2,
        };

        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        local_ip_address: uefi.Ipv6Address,
        remote_ip_address: uefi.Ipv6Address,
        local_port: u16,
        remote_port: u16,
        protocol: u16,
        ip_address_origin: Origin,
        prefix_length: u8,
        gateway_ip_address: uefi.Ipv6Address,
    };

    pub const VlanDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        vlan_id: u16,
    };

    pub const InfiniBandDevicePath = packed struct {
        pub const ResourceFlags = packed struct {
            pub const ControllerType = enum(u1) {
                Ioc = 0,
                Service = 1,
            };

            ioc_or_service: ControllerType,
            extend_boot_environment: bool,
            console_protocol: bool,
            storage_protocol: bool,
            network_protocol: bool,

            // u1 + 4 * bool = 5 bits, we need a total of 32 bits
            reserved: u27,
        };

        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        resource_flags: ResourceFlags,
        port_gid: [16]u8,
        service_id: u64,
        target_port_id: u64,
        device_id: u64,
    };

    pub const UartDevicePath = packed struct {
        pub const Parity = enum(u8) {
            Default = 0,
            None = 1,
            Even = 2,
            Odd = 3,
            Mark = 4,
            Space = 5,
            _,
        };

        pub const StopBits = enum(u8) {
            Default = 0,
            One = 1,
            OneAndAHalf = 2,
            Two = 3,
            _,
        };

        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        reserved: u16,
        baud_rate: u32,
        data_bits: u8,
        parity: Parity,
        stop_bits: StopBits,
    };

    pub const VendorDefinedDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        vendor_guid: Guid,
    };
};

pub const MediaDevicePath = union(Subtype) {
    HardDrive: *const HardDriveDevicePath,
    Cdrom: *const CdromDevicePath,
    Vendor: *const VendorDevicePath,
    FilePath: *const FilePathDevicePath,
    MediaProtocol: *const MediaProtocolDevicePath,
    PiwgFirmwareFile: *const PiwgFirmwareFileDevicePath,
    PiwgFirmwareVolume: *const PiwgFirmwareVolumeDevicePath,
    RelativeOffsetRange: *const RelativeOffsetRangeDevicePath,
    RamDisk: *const RamDiskDevicePath,

    pub const Subtype = enum(u8) {
        HardDrive = 1,
        Cdrom = 2,
        Vendor = 3,
        FilePath = 4,
        MediaProtocol = 5,
        PiwgFirmwareFile = 6,
        PiwgFirmwareVolume = 7,
        RelativeOffsetRange = 8,
        RamDisk = 9,
        _,
    };

    pub const HardDriveDevicePath = packed struct {
        pub const Format = enum(u8) {
            LegacyMbr = 0x01,
            GuidPartitionTable = 0x02,
        };

        pub const SignatureType = enum(u8) {
            NoSignature = 0x00,
            /// "32-bit signature from address 0x1b8 of the type 0x01 MBR"
            MbrSignature = 0x01,
            GuidSignature = 0x02,
        };

        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        partition_number: u32,
        partition_start: u64,
        partition_size: u64,
        partition_signature: [16]u8,
        partition_format: Format,
        signature_type: SignatureType,
    };

    pub const CdromDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        boot_entry: u32,
        partition_start: u64,
        partition_size: u64,
    };

    pub const VendorDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        guid: Guid,
        // vendor-defined variable data
    };

    pub const FilePathDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,

        pub fn getPath(self: *const FilePathDevicePath) [*:0]const u16 {
            return @ptrCast([*:0]const u16, @alignCast(2, @ptrCast([*]const u8, self)) + @sizeOf(FilePathDevicePath));
        }
    };

    pub const MediaProtocolDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        guid: Guid,
    };

    pub const PiwgFirmwareFileDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        fv_filename: Guid,
    };

    pub const PiwgFirmwareVolumeDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        fv_name: Guid,
    };

    pub const RelativeOffsetRangeDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        reserved: u32,
        start: u64,
        end: u64,
    };

    pub const RamDiskDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        start: u64,
        end: u64,
        disk_type: Guid,
        instance: u16,
    };
};

pub const BiosBootSpecificationDevicePath = union(Subtype) {
    BBS101: *const BBS101DevicePath,

    pub const Subtype = enum(u8) {
        BBS101 = 1,
        _,
    };

    pub const BBS101DevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
        device_type: u16,
        status_flag: u16,

        pub fn getDescription(self: *const BBS101DevicePath) [*:0]const u8 {
            return @ptrCast([*:0]const u8, self) + @sizeOf(BBS101DevicePath);
        }
    };
};

pub const EndDevicePath = union(Subtype) {
    EndEntire: *const EndEntireDevicePath,
    EndThisInstance: *const EndThisInstanceDevicePath,

    pub const Subtype = enum(u8) {
        EndEntire = 0xff,
        EndThisInstance = 0x01,
        _,
    };

    pub const EndEntireDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
    };

    pub const EndThisInstanceDevicePath = packed struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16,
    };
};
