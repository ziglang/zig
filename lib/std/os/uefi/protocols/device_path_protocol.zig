const std = @import("std");
const mem = std.mem;
const uefi = std.os.uefi;
const Allocator = mem.Allocator;
const Guid = uefi.Guid;

// All Device Path Nodes are byte-packed and may appear on any byte boundary.
// All code references to device path nodes must assume all fields are unaligned.

pub const DevicePathProtocol = extern struct {
    type: DevicePathType,
    subtype: u8,
    length: u16 align(1),

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
        if (self.type == .End and @as(EndDevicePath.Subtype, @enumFromInt(self.subtype)) == .EndEntire)
            return null;

        return @as(*DevicePathProtocol, @ptrCast(@as([*]u8, @ptrCast(self)) + self.length));
    }

    /// Calculates the total length of the device path structure in bytes, including the end of device path node.
    pub fn size(self: *DevicePathProtocol) usize {
        var node = self;

        while (node.next()) |next_node| {
            node = next_node;
        }

        return (@intFromPtr(node) + node.length) - @intFromPtr(self);
    }

    /// Creates a file device path from the existing device path and a file path.
    pub fn create_file_device_path(self: *DevicePathProtocol, allocator: Allocator, path: [:0]align(1) const u16) !*DevicePathProtocol {
        var path_size = self.size();

        // 2 * (path.len + 1) for the path and its null terminator, which are u16s
        // DevicePathProtocol for the extra node before the end
        var buf = try allocator.alloc(u8, path_size + 2 * (path.len + 1) + @sizeOf(DevicePathProtocol));

        @memcpy(buf[0..path_size], @as([*]const u8, @ptrCast(self))[0..path_size]);

        // Pointer to the copy of the end node of the current chain, which is - 4 from the buffer
        // as the end node itself is 4 bytes (type: u8 + subtype: u8 + length: u16).
        var new = @as(*MediaDevicePath.FilePathDevicePath, @ptrCast(buf.ptr + path_size - 4));

        new.type = .Media;
        new.subtype = .FilePath;
        new.length = @sizeOf(MediaDevicePath.FilePathDevicePath) + 2 * (@as(u16, @intCast(path.len)) + 1);

        // The same as new.getPath(), but not const as we're filling it in.
        var ptr = @as([*:0]align(1) u16, @ptrCast(@as([*]u8, @ptrCast(new)) + @sizeOf(MediaDevicePath.FilePathDevicePath)));

        for (path, 0..) |s, i|
            ptr[i] = s;

        ptr[path.len] = 0;

        var end = @as(*EndDevicePath.EndEntireDevicePath, @ptrCast(@as(*DevicePathProtocol, @ptrCast(new)).next().?));
        end.type = .End;
        end.subtype = .EndEntire;
        end.length = @sizeOf(EndDevicePath.EndEntireDevicePath);

        return @as(*DevicePathProtocol, @ptrCast(buf.ptr));
    }

    pub fn getDevicePath(self: *const DevicePathProtocol) ?DevicePath {
        inline for (@typeInfo(DevicePath).Union.fields) |ufield| {
            const enum_value = std.meta.stringToEnum(DevicePathType, ufield.name);

            // Got the associated union type for self.type, now
            // we need to initialize it and its subtype
            if (self.type == enum_value) {
                var subtype = self.initSubtype(ufield.type);

                if (subtype) |sb| {
                    // e.g. return .{ .Hardware = .{ .Pci = @ptrCast(...) } }
                    return @unionInit(DevicePath, ufield.name, sb);
                }
            }
        }

        return null;
    }

    pub fn initSubtype(self: *const DevicePathProtocol, comptime TUnion: type) ?TUnion {
        const type_info = @typeInfo(TUnion).Union;
        const TTag = type_info.tag_type.?;

        inline for (type_info.fields) |subtype| {
            // The tag names match the union names, so just grab that off the enum
            const tag_val: u8 = @intFromEnum(@field(TTag, subtype.name));

            if (self.subtype == tag_val) {
                // e.g. expr = .{ .Pci = @ptrCast(...) }
                return @unionInit(TUnion, subtype.name, @as(subtype.type, @ptrCast(self)));
            }
        }

        return null;
    }
};

comptime {
    std.debug.assert(4 == @sizeOf(DevicePathProtocol));
    std.debug.assert(1 == @alignOf(DevicePathProtocol));

    std.debug.assert(0 == @offsetOf(DevicePathProtocol, "type"));
    std.debug.assert(1 == @offsetOf(DevicePathProtocol, "subtype"));
    std.debug.assert(2 == @offsetOf(DevicePathProtocol, "length"));
}

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

    pub const PciDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        function: u8,
        device: u8,
    };

    comptime {
        std.debug.assert(6 == @sizeOf(PciDevicePath));
        std.debug.assert(1 == @alignOf(PciDevicePath));

        std.debug.assert(0 == @offsetOf(PciDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(PciDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(PciDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(PciDevicePath, "function"));
        std.debug.assert(5 == @offsetOf(PciDevicePath, "device"));
    }

    pub const PcCardDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        function_number: u8,
    };

    comptime {
        std.debug.assert(5 == @sizeOf(PcCardDevicePath));
        std.debug.assert(1 == @alignOf(PcCardDevicePath));

        std.debug.assert(0 == @offsetOf(PcCardDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(PcCardDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(PcCardDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(PcCardDevicePath, "function_number"));
    }

    pub const MemoryMappedDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        memory_type: u32 align(1),
        start_address: u64 align(1),
        end_address: u64 align(1),
    };

    comptime {
        std.debug.assert(24 == @sizeOf(MemoryMappedDevicePath));
        std.debug.assert(1 == @alignOf(MemoryMappedDevicePath));

        std.debug.assert(0 == @offsetOf(MemoryMappedDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(MemoryMappedDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(MemoryMappedDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(MemoryMappedDevicePath, "memory_type"));
        std.debug.assert(8 == @offsetOf(MemoryMappedDevicePath, "start_address"));
        std.debug.assert(16 == @offsetOf(MemoryMappedDevicePath, "end_address"));
    }

    pub const VendorDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        vendor_guid: Guid align(1),
    };

    comptime {
        std.debug.assert(20 == @sizeOf(VendorDevicePath));
        std.debug.assert(1 == @alignOf(VendorDevicePath));

        std.debug.assert(0 == @offsetOf(VendorDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(VendorDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(VendorDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(VendorDevicePath, "vendor_guid"));
    }

    pub const ControllerDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        controller_number: u32 align(1),
    };

    comptime {
        std.debug.assert(8 == @sizeOf(ControllerDevicePath));
        std.debug.assert(1 == @alignOf(ControllerDevicePath));

        std.debug.assert(0 == @offsetOf(ControllerDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(ControllerDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(ControllerDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(ControllerDevicePath, "controller_number"));
    }

    pub const BmcDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        interface_type: u8,
        base_address: u64 align(1),
    };

    comptime {
        std.debug.assert(13 == @sizeOf(BmcDevicePath));
        std.debug.assert(1 == @alignOf(BmcDevicePath));

        std.debug.assert(0 == @offsetOf(BmcDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(BmcDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(BmcDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(BmcDevicePath, "interface_type"));
        std.debug.assert(5 == @offsetOf(BmcDevicePath, "base_address"));
    }
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

    pub const BaseAcpiDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        hid: u32 align(1),
        uid: u32 align(1),
    };

    comptime {
        std.debug.assert(12 == @sizeOf(BaseAcpiDevicePath));
        std.debug.assert(1 == @alignOf(BaseAcpiDevicePath));

        std.debug.assert(0 == @offsetOf(BaseAcpiDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(BaseAcpiDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(BaseAcpiDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(BaseAcpiDevicePath, "hid"));
        std.debug.assert(8 == @offsetOf(BaseAcpiDevicePath, "uid"));
    }

    pub const ExpandedAcpiDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        hid: u32 align(1),
        uid: u32 align(1),
        cid: u32 align(1),
        // variable length u16[*:0] strings
        // hid_str, uid_str, cid_str
    };

    comptime {
        std.debug.assert(16 == @sizeOf(ExpandedAcpiDevicePath));
        std.debug.assert(1 == @alignOf(ExpandedAcpiDevicePath));

        std.debug.assert(0 == @offsetOf(ExpandedAcpiDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(ExpandedAcpiDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(ExpandedAcpiDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(ExpandedAcpiDevicePath, "hid"));
        std.debug.assert(8 == @offsetOf(ExpandedAcpiDevicePath, "uid"));
        std.debug.assert(12 == @offsetOf(ExpandedAcpiDevicePath, "cid"));
    }

    pub const AdrDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        adr: u32 align(1),

        // multiple adr entries can optionally follow
        pub fn adrs(self: *const AdrDevicePath) []align(1) const u32 {
            // self.length is a minimum of 8 with one adr which is size 4.
            var entries = (self.length - 4) / @sizeOf(u32);
            return @as([*]align(1) const u32, @ptrCast(&self.adr))[0..entries];
        }
    };

    comptime {
        std.debug.assert(8 == @sizeOf(AdrDevicePath));
        std.debug.assert(1 == @alignOf(AdrDevicePath));

        std.debug.assert(0 == @offsetOf(AdrDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(AdrDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(AdrDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(AdrDevicePath, "adr"));
    }
};

pub const MessagingDevicePath = union(Subtype) {
    Atapi: *const AtapiDevicePath,
    Scsi: *const ScsiDevicePath,
    FibreChannel: *const FibreChannelDevicePath,
    FibreChannelEx: *const FibreChannelExDevicePath,
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

    pub const AtapiDevicePath = extern struct {
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
        length: u16 align(1),
        primary_secondary: Rank,
        slave_master: Role,
        logical_unit_number: u16 align(1),
    };

    comptime {
        std.debug.assert(8 == @sizeOf(AtapiDevicePath));
        std.debug.assert(1 == @alignOf(AtapiDevicePath));

        std.debug.assert(0 == @offsetOf(AtapiDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(AtapiDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(AtapiDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(AtapiDevicePath, "primary_secondary"));
        std.debug.assert(5 == @offsetOf(AtapiDevicePath, "slave_master"));
        std.debug.assert(6 == @offsetOf(AtapiDevicePath, "logical_unit_number"));
    }

    pub const ScsiDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        target_id: u16 align(1),
        logical_unit_number: u16 align(1),
    };

    comptime {
        std.debug.assert(8 == @sizeOf(ScsiDevicePath));
        std.debug.assert(1 == @alignOf(ScsiDevicePath));

        std.debug.assert(0 == @offsetOf(ScsiDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(ScsiDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(ScsiDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(ScsiDevicePath, "target_id"));
        std.debug.assert(6 == @offsetOf(ScsiDevicePath, "logical_unit_number"));
    }

    pub const FibreChannelDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        reserved: u32 align(1),
        world_wide_name: u64 align(1),
        logical_unit_number: u64 align(1),
    };

    comptime {
        std.debug.assert(24 == @sizeOf(FibreChannelDevicePath));
        std.debug.assert(1 == @alignOf(FibreChannelDevicePath));

        std.debug.assert(0 == @offsetOf(FibreChannelDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(FibreChannelDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(FibreChannelDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(FibreChannelDevicePath, "reserved"));
        std.debug.assert(8 == @offsetOf(FibreChannelDevicePath, "world_wide_name"));
        std.debug.assert(16 == @offsetOf(FibreChannelDevicePath, "logical_unit_number"));
    }

    pub const FibreChannelExDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        reserved: u32 align(1),
        world_wide_name: u64 align(1),
        logical_unit_number: u64 align(1),
    };

    comptime {
        std.debug.assert(24 == @sizeOf(FibreChannelExDevicePath));
        std.debug.assert(1 == @alignOf(FibreChannelExDevicePath));

        std.debug.assert(0 == @offsetOf(FibreChannelExDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(FibreChannelExDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(FibreChannelExDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(FibreChannelExDevicePath, "reserved"));
        std.debug.assert(8 == @offsetOf(FibreChannelExDevicePath, "world_wide_name"));
        std.debug.assert(16 == @offsetOf(FibreChannelExDevicePath, "logical_unit_number"));
    }

    pub const F1394DevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        reserved: u32 align(1),
        guid: u64 align(1),
    };

    comptime {
        std.debug.assert(16 == @sizeOf(F1394DevicePath));
        std.debug.assert(1 == @alignOf(F1394DevicePath));

        std.debug.assert(0 == @offsetOf(F1394DevicePath, "type"));
        std.debug.assert(1 == @offsetOf(F1394DevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(F1394DevicePath, "length"));
        std.debug.assert(4 == @offsetOf(F1394DevicePath, "reserved"));
        std.debug.assert(8 == @offsetOf(F1394DevicePath, "guid"));
    }

    pub const UsbDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        parent_port_number: u8,
        interface_number: u8,
    };

    comptime {
        std.debug.assert(6 == @sizeOf(UsbDevicePath));
        std.debug.assert(1 == @alignOf(UsbDevicePath));

        std.debug.assert(0 == @offsetOf(UsbDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(UsbDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(UsbDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(UsbDevicePath, "parent_port_number"));
        std.debug.assert(5 == @offsetOf(UsbDevicePath, "interface_number"));
    }

    pub const SataDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        hba_port_number: u16 align(1),
        port_multiplier_port_number: u16 align(1),
        logical_unit_number: u16 align(1),
    };

    comptime {
        std.debug.assert(10 == @sizeOf(SataDevicePath));
        std.debug.assert(1 == @alignOf(SataDevicePath));

        std.debug.assert(0 == @offsetOf(SataDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(SataDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(SataDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(SataDevicePath, "hba_port_number"));
        std.debug.assert(6 == @offsetOf(SataDevicePath, "port_multiplier_port_number"));
        std.debug.assert(8 == @offsetOf(SataDevicePath, "logical_unit_number"));
    }

    pub const UsbWwidDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        interface_number: u16 align(1),
        device_vendor_id: u16 align(1),
        device_product_id: u16 align(1),

        pub fn serial_number(self: *const UsbWwidDevicePath) []align(1) const u16 {
            var serial_len = (self.length - @sizeOf(UsbWwidDevicePath)) / @sizeOf(u16);
            return @as([*]align(1) const u16, @ptrCast(@as([*]const u8, @ptrCast(self)) + @sizeOf(UsbWwidDevicePath)))[0..serial_len];
        }
    };

    comptime {
        std.debug.assert(10 == @sizeOf(UsbWwidDevicePath));
        std.debug.assert(1 == @alignOf(UsbWwidDevicePath));

        std.debug.assert(0 == @offsetOf(UsbWwidDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(UsbWwidDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(UsbWwidDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(UsbWwidDevicePath, "interface_number"));
        std.debug.assert(6 == @offsetOf(UsbWwidDevicePath, "device_vendor_id"));
        std.debug.assert(8 == @offsetOf(UsbWwidDevicePath, "device_product_id"));
    }

    pub const DeviceLogicalUnitDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        lun: u8,
    };

    comptime {
        std.debug.assert(5 == @sizeOf(DeviceLogicalUnitDevicePath));
        std.debug.assert(1 == @alignOf(DeviceLogicalUnitDevicePath));

        std.debug.assert(0 == @offsetOf(DeviceLogicalUnitDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(DeviceLogicalUnitDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(DeviceLogicalUnitDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(DeviceLogicalUnitDevicePath, "lun"));
    }

    pub const UsbClassDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        vendor_id: u16 align(1),
        product_id: u16 align(1),
        device_class: u8,
        device_subclass: u8,
        device_protocol: u8,
    };

    comptime {
        std.debug.assert(11 == @sizeOf(UsbClassDevicePath));
        std.debug.assert(1 == @alignOf(UsbClassDevicePath));

        std.debug.assert(0 == @offsetOf(UsbClassDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(UsbClassDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(UsbClassDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(UsbClassDevicePath, "vendor_id"));
        std.debug.assert(6 == @offsetOf(UsbClassDevicePath, "product_id"));
        std.debug.assert(8 == @offsetOf(UsbClassDevicePath, "device_class"));
        std.debug.assert(9 == @offsetOf(UsbClassDevicePath, "device_subclass"));
        std.debug.assert(10 == @offsetOf(UsbClassDevicePath, "device_protocol"));
    }

    pub const I2oDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        tid: u32 align(1),
    };

    comptime {
        std.debug.assert(8 == @sizeOf(I2oDevicePath));
        std.debug.assert(1 == @alignOf(I2oDevicePath));

        std.debug.assert(0 == @offsetOf(I2oDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(I2oDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(I2oDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(I2oDevicePath, "tid"));
    }

    pub const MacAddressDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        mac_address: uefi.MacAddress,
        if_type: u8,
    };

    comptime {
        std.debug.assert(37 == @sizeOf(MacAddressDevicePath));
        std.debug.assert(1 == @alignOf(MacAddressDevicePath));

        std.debug.assert(0 == @offsetOf(MacAddressDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(MacAddressDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(MacAddressDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(MacAddressDevicePath, "mac_address"));
        std.debug.assert(36 == @offsetOf(MacAddressDevicePath, "if_type"));
    }

    pub const Ipv4DevicePath = extern struct {
        pub const IpType = enum(u8) {
            Dhcp = 0,
            Static = 1,
        };

        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        local_ip_address: uefi.Ipv4Address align(1),
        remote_ip_address: uefi.Ipv4Address align(1),
        local_port: u16 align(1),
        remote_port: u16 align(1),
        network_protocol: u16 align(1),
        static_ip_address: IpType,
        gateway_ip_address: u32 align(1),
        subnet_mask: u32 align(1),
    };

    comptime {
        std.debug.assert(27 == @sizeOf(Ipv4DevicePath));
        std.debug.assert(1 == @alignOf(Ipv4DevicePath));

        std.debug.assert(0 == @offsetOf(Ipv4DevicePath, "type"));
        std.debug.assert(1 == @offsetOf(Ipv4DevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(Ipv4DevicePath, "length"));
        std.debug.assert(4 == @offsetOf(Ipv4DevicePath, "local_ip_address"));
        std.debug.assert(8 == @offsetOf(Ipv4DevicePath, "remote_ip_address"));
        std.debug.assert(12 == @offsetOf(Ipv4DevicePath, "local_port"));
        std.debug.assert(14 == @offsetOf(Ipv4DevicePath, "remote_port"));
        std.debug.assert(16 == @offsetOf(Ipv4DevicePath, "network_protocol"));
        std.debug.assert(18 == @offsetOf(Ipv4DevicePath, "static_ip_address"));
        std.debug.assert(19 == @offsetOf(Ipv4DevicePath, "gateway_ip_address"));
        std.debug.assert(23 == @offsetOf(Ipv4DevicePath, "subnet_mask"));
    }

    pub const Ipv6DevicePath = extern struct {
        pub const Origin = enum(u8) {
            Manual = 0,
            AssignedStateless = 1,
            AssignedStateful = 2,
        };

        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        local_ip_address: uefi.Ipv6Address,
        remote_ip_address: uefi.Ipv6Address,
        local_port: u16 align(1),
        remote_port: u16 align(1),
        protocol: u16 align(1),
        ip_address_origin: Origin,
        prefix_length: u8,
        gateway_ip_address: uefi.Ipv6Address,
    };

    comptime {
        std.debug.assert(60 == @sizeOf(Ipv6DevicePath));
        std.debug.assert(1 == @alignOf(Ipv6DevicePath));

        std.debug.assert(0 == @offsetOf(Ipv6DevicePath, "type"));
        std.debug.assert(1 == @offsetOf(Ipv6DevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(Ipv6DevicePath, "length"));
        std.debug.assert(4 == @offsetOf(Ipv6DevicePath, "local_ip_address"));
        std.debug.assert(20 == @offsetOf(Ipv6DevicePath, "remote_ip_address"));
        std.debug.assert(36 == @offsetOf(Ipv6DevicePath, "local_port"));
        std.debug.assert(38 == @offsetOf(Ipv6DevicePath, "remote_port"));
        std.debug.assert(40 == @offsetOf(Ipv6DevicePath, "protocol"));
        std.debug.assert(42 == @offsetOf(Ipv6DevicePath, "ip_address_origin"));
        std.debug.assert(43 == @offsetOf(Ipv6DevicePath, "prefix_length"));
        std.debug.assert(44 == @offsetOf(Ipv6DevicePath, "gateway_ip_address"));
    }

    pub const VlanDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        vlan_id: u16 align(1),
    };

    comptime {
        std.debug.assert(6 == @sizeOf(VlanDevicePath));
        std.debug.assert(1 == @alignOf(VlanDevicePath));

        std.debug.assert(0 == @offsetOf(VlanDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(VlanDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(VlanDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(VlanDevicePath, "vlan_id"));
    }

    pub const InfiniBandDevicePath = extern struct {
        pub const ResourceFlags = packed struct(u32) {
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
        length: u16 align(1),
        resource_flags: ResourceFlags align(1),
        port_gid: [16]u8,
        service_id: u64 align(1),
        target_port_id: u64 align(1),
        device_id: u64 align(1),
    };

    comptime {
        std.debug.assert(48 == @sizeOf(InfiniBandDevicePath));
        std.debug.assert(1 == @alignOf(InfiniBandDevicePath));

        std.debug.assert(0 == @offsetOf(InfiniBandDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(InfiniBandDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(InfiniBandDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(InfiniBandDevicePath, "resource_flags"));
        std.debug.assert(8 == @offsetOf(InfiniBandDevicePath, "port_gid"));
        std.debug.assert(24 == @offsetOf(InfiniBandDevicePath, "service_id"));
        std.debug.assert(32 == @offsetOf(InfiniBandDevicePath, "target_port_id"));
        std.debug.assert(40 == @offsetOf(InfiniBandDevicePath, "device_id"));
    }

    pub const UartDevicePath = extern struct {
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
        length: u16 align(1),
        reserved: u32 align(1),
        baud_rate: u64 align(1),
        data_bits: u8,
        parity: Parity,
        stop_bits: StopBits,
    };

    comptime {
        std.debug.assert(19 == @sizeOf(UartDevicePath));
        std.debug.assert(1 == @alignOf(UartDevicePath));

        std.debug.assert(0 == @offsetOf(UartDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(UartDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(UartDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(UartDevicePath, "reserved"));
        std.debug.assert(8 == @offsetOf(UartDevicePath, "baud_rate"));
        std.debug.assert(16 == @offsetOf(UartDevicePath, "data_bits"));
        std.debug.assert(17 == @offsetOf(UartDevicePath, "parity"));
        std.debug.assert(18 == @offsetOf(UartDevicePath, "stop_bits"));
    }

    pub const VendorDefinedDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        vendor_guid: Guid align(1),
    };

    comptime {
        std.debug.assert(20 == @sizeOf(VendorDefinedDevicePath));
        std.debug.assert(1 == @alignOf(VendorDefinedDevicePath));

        std.debug.assert(0 == @offsetOf(VendorDefinedDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(VendorDefinedDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(VendorDefinedDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(VendorDefinedDevicePath, "vendor_guid"));
    }
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

    pub const HardDriveDevicePath = extern struct {
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
        length: u16 align(1),
        partition_number: u32 align(1),
        partition_start: u64 align(1),
        partition_size: u64 align(1),
        partition_signature: [16]u8,
        partition_format: Format,
        signature_type: SignatureType,
    };

    comptime {
        std.debug.assert(42 == @sizeOf(HardDriveDevicePath));
        std.debug.assert(1 == @alignOf(HardDriveDevicePath));

        std.debug.assert(0 == @offsetOf(HardDriveDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(HardDriveDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(HardDriveDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(HardDriveDevicePath, "partition_number"));
        std.debug.assert(8 == @offsetOf(HardDriveDevicePath, "partition_start"));
        std.debug.assert(16 == @offsetOf(HardDriveDevicePath, "partition_size"));
        std.debug.assert(24 == @offsetOf(HardDriveDevicePath, "partition_signature"));
        std.debug.assert(40 == @offsetOf(HardDriveDevicePath, "partition_format"));
        std.debug.assert(41 == @offsetOf(HardDriveDevicePath, "signature_type"));
    }

    pub const CdromDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        boot_entry: u32 align(1),
        partition_start: u64 align(1),
        partition_size: u64 align(1),
    };

    comptime {
        std.debug.assert(24 == @sizeOf(CdromDevicePath));
        std.debug.assert(1 == @alignOf(CdromDevicePath));

        std.debug.assert(0 == @offsetOf(CdromDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(CdromDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(CdromDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(CdromDevicePath, "boot_entry"));
        std.debug.assert(8 == @offsetOf(CdromDevicePath, "partition_start"));
        std.debug.assert(16 == @offsetOf(CdromDevicePath, "partition_size"));
    }

    pub const VendorDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        guid: Guid align(1),
    };

    comptime {
        std.debug.assert(20 == @sizeOf(VendorDevicePath));
        std.debug.assert(1 == @alignOf(VendorDevicePath));

        std.debug.assert(0 == @offsetOf(VendorDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(VendorDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(VendorDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(VendorDevicePath, "guid"));
    }

    pub const FilePathDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),

        pub fn getPath(self: *const FilePathDevicePath) [*:0]align(1) const u16 {
            return @as([*:0]align(1) const u16, @ptrCast(@as([*]const u8, @ptrCast(self)) + @sizeOf(FilePathDevicePath)));
        }
    };

    comptime {
        std.debug.assert(4 == @sizeOf(FilePathDevicePath));
        std.debug.assert(1 == @alignOf(FilePathDevicePath));

        std.debug.assert(0 == @offsetOf(FilePathDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(FilePathDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(FilePathDevicePath, "length"));
    }

    pub const MediaProtocolDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        guid: Guid align(1),
    };

    comptime {
        std.debug.assert(20 == @sizeOf(MediaProtocolDevicePath));
        std.debug.assert(1 == @alignOf(MediaProtocolDevicePath));

        std.debug.assert(0 == @offsetOf(MediaProtocolDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(MediaProtocolDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(MediaProtocolDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(MediaProtocolDevicePath, "guid"));
    }

    pub const PiwgFirmwareFileDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        fv_filename: Guid align(1),
    };

    comptime {
        std.debug.assert(20 == @sizeOf(PiwgFirmwareFileDevicePath));
        std.debug.assert(1 == @alignOf(PiwgFirmwareFileDevicePath));

        std.debug.assert(0 == @offsetOf(PiwgFirmwareFileDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(PiwgFirmwareFileDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(PiwgFirmwareFileDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(PiwgFirmwareFileDevicePath, "fv_filename"));
    }

    pub const PiwgFirmwareVolumeDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        fv_name: Guid align(1),
    };

    comptime {
        std.debug.assert(20 == @sizeOf(PiwgFirmwareVolumeDevicePath));
        std.debug.assert(1 == @alignOf(PiwgFirmwareVolumeDevicePath));

        std.debug.assert(0 == @offsetOf(PiwgFirmwareVolumeDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(PiwgFirmwareVolumeDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(PiwgFirmwareVolumeDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(PiwgFirmwareVolumeDevicePath, "fv_name"));
    }

    pub const RelativeOffsetRangeDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        reserved: u32 align(1),
        start: u64 align(1),
        end: u64 align(1),
    };

    comptime {
        std.debug.assert(24 == @sizeOf(RelativeOffsetRangeDevicePath));
        std.debug.assert(1 == @alignOf(RelativeOffsetRangeDevicePath));

        std.debug.assert(0 == @offsetOf(RelativeOffsetRangeDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(RelativeOffsetRangeDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(RelativeOffsetRangeDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(RelativeOffsetRangeDevicePath, "reserved"));
        std.debug.assert(8 == @offsetOf(RelativeOffsetRangeDevicePath, "start"));
        std.debug.assert(16 == @offsetOf(RelativeOffsetRangeDevicePath, "end"));
    }

    pub const RamDiskDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        start: u64 align(1),
        end: u64 align(1),
        disk_type: Guid align(1),
        instance: u16 align(1),
    };

    comptime {
        std.debug.assert(38 == @sizeOf(RamDiskDevicePath));
        std.debug.assert(1 == @alignOf(RamDiskDevicePath));

        std.debug.assert(0 == @offsetOf(RamDiskDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(RamDiskDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(RamDiskDevicePath, "length"));
        std.debug.assert(4 == @offsetOf(RamDiskDevicePath, "start"));
        std.debug.assert(12 == @offsetOf(RamDiskDevicePath, "end"));
        std.debug.assert(20 == @offsetOf(RamDiskDevicePath, "disk_type"));
        std.debug.assert(36 == @offsetOf(RamDiskDevicePath, "instance"));
    }
};

pub const BiosBootSpecificationDevicePath = union(Subtype) {
    BBS101: *const BBS101DevicePath,

    pub const Subtype = enum(u8) {
        BBS101 = 1,
        _,
    };

    pub const BBS101DevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
        device_type: u16 align(1),
        status_flag: u16 align(1),

        pub fn getDescription(self: *const BBS101DevicePath) [*:0]const u8 {
            return @as([*:0]const u8, @ptrCast(self)) + @sizeOf(BBS101DevicePath);
        }
    };

    comptime {
        std.debug.assert(8 == @sizeOf(BBS101DevicePath));
        std.debug.assert(1 == @alignOf(BBS101DevicePath));

        std.debug.assert(0 == @offsetOf(BBS101DevicePath, "type"));
        std.debug.assert(1 == @offsetOf(BBS101DevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(BBS101DevicePath, "length"));
        std.debug.assert(4 == @offsetOf(BBS101DevicePath, "device_type"));
        std.debug.assert(6 == @offsetOf(BBS101DevicePath, "status_flag"));
    }
};

pub const EndDevicePath = union(Subtype) {
    EndEntire: *const EndEntireDevicePath,
    EndThisInstance: *const EndThisInstanceDevicePath,

    pub const Subtype = enum(u8) {
        EndEntire = 0xff,
        EndThisInstance = 0x01,
        _,
    };

    pub const EndEntireDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
    };

    comptime {
        std.debug.assert(4 == @sizeOf(EndEntireDevicePath));
        std.debug.assert(1 == @alignOf(EndEntireDevicePath));

        std.debug.assert(0 == @offsetOf(EndEntireDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(EndEntireDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(EndEntireDevicePath, "length"));
    }

    pub const EndThisInstanceDevicePath = extern struct {
        type: DevicePathType,
        subtype: Subtype,
        length: u16 align(1),
    };

    comptime {
        std.debug.assert(4 == @sizeOf(EndEntireDevicePath));
        std.debug.assert(1 == @alignOf(EndEntireDevicePath));

        std.debug.assert(0 == @offsetOf(EndEntireDevicePath, "type"));
        std.debug.assert(1 == @offsetOf(EndEntireDevicePath, "subtype"));
        std.debug.assert(2 == @offsetOf(EndEntireDevicePath, "length"));
    }
};
