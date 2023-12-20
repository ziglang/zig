const std = @import("../../std.zig");
const bits = @import("bits.zig");

const Guid = bits.Guid;

const assert = std.debug.assert;

pub const DevicePath = union(Type) {
    hardware: Hardware,
    acpi: Acpi,
    messaging: Messaging,
    media: Media,
    bios_boot_specification: BiosBootSpecification,
    end: End,

    pub const Type = enum(u8) {
        hardware = 0x01,
        acpi = 0x02,
        messaging = 0x03,
        media = 0x04,
        bios_boot_specification = 0x05,
        end = 0x7f,
        _,
    };

    pub const Hardware = union(Subtype) {
        pci: *const Pci,
        pc_card: *const PcCard,
        memory_mapped: *const MemoryMapped,
        vendor: *const Vendor,
        controller: *const Controller,
        bmc: *const Bmc,

        pub const Subtype = enum(u8) {
            pci = 1,
            pc_card = 2,
            memory_mapped = 3,
            vendor = 4,
            controller = 5,
            bmc = 6,
            _,
        };

        /// The Device Path for PCI defines the path to the PCI configuration space address for a PCI device. There is
        /// one PCI Device Path entry for each device and function number that defines the path from the root PCI bus to
        /// the device. Because the PCI bus number of a device may potentially change, a flat encoding of single PCI
        /// Device Path entry cannot be used.
        pub const Pci = extern struct {
            type: Type = .hardware,
            subtype: Subtype = .pci,
            length: u16 align(1) = 6,

            /// PCI function number
            function: u8,

            /// PCI device number
            device: u8,

            comptime {
                assert(6 == @sizeOf(Pci));
                assert(1 == @alignOf(Pci));

                assert(0 == @offsetOf(Pci, "type"));
                assert(1 == @offsetOf(Pci, "subtype"));
                assert(2 == @offsetOf(Pci, "length"));
                assert(4 == @offsetOf(Pci, "function"));
                assert(5 == @offsetOf(Pci, "device"));
            }
        };

        pub const PcCard = extern struct {
            type: Type = .hardware,
            subtype: Subtype = .pc_card,
            length: u16 align(1) = 5,

            /// Function number (0 = first function)
            function_number: u8,

            comptime {
                assert(5 == @sizeOf(PcCard));
                assert(1 == @alignOf(PcCard));

                assert(0 == @offsetOf(PcCard, "type"));
                assert(1 == @offsetOf(PcCard, "subtype"));
                assert(2 == @offsetOf(PcCard, "length"));
                assert(4 == @offsetOf(PcCard, "function_number"));
            }
        };

        pub const MemoryMapped = extern struct {
            type: Type = .hardware,
            subtype: Subtype = .memory_mapped,
            length: u16 align(1) = 24,

            /// Memory type
            memory_type: bits.MemoryDescriptor.Type align(1),

            /// Starting memory address
            start_address: u64 align(1),

            /// Ending memory address
            end_address: u64 align(1),

            comptime {
                assert(24 == @sizeOf(MemoryMapped));
                assert(1 == @alignOf(MemoryMapped));

                assert(0 == @offsetOf(MemoryMapped, "type"));
                assert(1 == @offsetOf(MemoryMapped, "subtype"));
                assert(2 == @offsetOf(MemoryMapped, "length"));
                assert(4 == @offsetOf(MemoryMapped, "memory_type"));
                assert(8 == @offsetOf(MemoryMapped, "start_address"));
                assert(16 == @offsetOf(MemoryMapped, "end_address"));
            }
        };

        /// The Vendor Device Path allows the creation of vendor-defined Device Paths. A vendor must allocate a Vendor
        /// GUID for a Device Path. The Vendor GUID can then be used to define the contents on the data bytes that
        /// follow in the Vendor Device Path node.
        pub const Vendor = extern struct {
            type: Type = .hardware,
            subtype: Subtype = .vendor,
            length: u16 align(1), // 20 + x

            /// Vendor GUID that defines the data that follows.
            vendor_guid: Guid align(1),

            /// Vendor-specific data
            pub fn data(self: *const Vendor) []const u8 {
                const ptr = @as([*:0]const u8, @ptrCast(self));

                return ptr[@sizeOf(Vendor)..self.length];
            }

            comptime {
                assert(20 == @sizeOf(Vendor));
                assert(1 == @alignOf(Vendor));

                assert(0 == @offsetOf(Vendor, "type"));
                assert(1 == @offsetOf(Vendor, "subtype"));
                assert(2 == @offsetOf(Vendor, "length"));
                assert(4 == @offsetOf(Vendor, "vendor_guid"));
            }
        };

        pub const Controller = extern struct {
            type: Type = .hardware,
            subtype: Subtype = .controller,
            length: u16 align(1) = 8,

            /// Controller number
            controller_number: u32 align(1),

            comptime {
                assert(8 == @sizeOf(Controller));
                assert(1 == @alignOf(Controller));

                assert(0 == @offsetOf(Controller, "type"));
                assert(1 == @offsetOf(Controller, "subtype"));
                assert(2 == @offsetOf(Controller, "length"));
                assert(4 == @offsetOf(Controller, "controller_number"));
            }
        };

        /// The Device Path for a Baseboard Management Controller (BMC) host interface.
        pub const Bmc = extern struct {
            pub const InterfaceType = enum(u8) {
                unknown = 0,

                /// Keyboard controller style
                kcs = 1,

                /// Server management interface chip
                smic = 2,

                /// Block transfer
                bt = 3,

                _,
            };

            type: Type = .hardware,
            subtype: Subtype = .bmc,
            length: u16 align(1) = 13,

            /// The Baseboard Management Controller (BMC) host interface type
            interface_type: InterfaceType,

            /// Base address (either memory-mapped or I/O) of the BMC. If the least significant bit is a 1, the address
            /// is in I/O space; otherwise, the address is memory-mapped. Refer to the IPMI specification for details.
            base_address: u64 align(1),

            comptime {
                assert(13 == @sizeOf(Bmc));
                assert(1 == @alignOf(Bmc));

                assert(0 == @offsetOf(Bmc, "type"));
                assert(1 == @offsetOf(Bmc, "subtype"));
                assert(2 == @offsetOf(Bmc, "length"));
                assert(4 == @offsetOf(Bmc, "interface_type"));
                assert(5 == @offsetOf(Bmc, "base_address"));
            }
        };
    };

    pub const Acpi = union(Subtype) {
        base: *const BaseAcpi,
        expanded: *const ExpandedAcpi,
        adr: *const Adr,
        nvdimm: *const Nvdimm,

        pub const Subtype = enum(u8) {
            base = 1,
            expanded = 2,
            adr = 3,
            nvdimm = 4,
            _,
        };

        pub const BaseAcpi = extern struct {
            type: Type = .acpi,
            subtype: Subtype = .base,
            length: u16 align(1) = 12,

            /// Device’s PnP hardware ID stored in a numeric 32-bit compressed EISA-type ID. This value must match the
            /// corresponding _HID in the ACPI name space.
            hid: u32 align(1),

            /// Unique ID that is required by ACPI if two devices have the same _HID. This value must also match the
            /// corresponding _UID/_HID pair in the ACPI name space.
            uid: u32 align(1),

            comptime {
                assert(12 == @sizeOf(BaseAcpi));
                assert(1 == @alignOf(BaseAcpi));

                assert(0 == @offsetOf(BaseAcpi, "type"));
                assert(1 == @offsetOf(BaseAcpi, "subtype"));
                assert(2 == @offsetOf(BaseAcpi, "length"));
                assert(4 == @offsetOf(BaseAcpi, "hid"));
                assert(8 == @offsetOf(BaseAcpi, "uid"));
            }
        };

        pub const ExpandedAcpi = extern struct {
            type: DevicePath.Type = .acpi,
            subtype: Subtype = .expanded,
            length: u16 align(1),

            /// Device’s PnP hardware ID stored in a numeric 32-bit compressed EISA-type ID. This value must match the
            /// corresponding _HID in the ACPI name space.
            hid: u32 align(1),

            /// Unique ID that is required by ACPI if two devices have the same _HID. This value must also match the
            /// corresponding _UID/_HID pair in the ACPI name space.
            uid: u32 align(1),

            /// Device’s compatible PnP hardware ID stored in a numeric 32-bit compressed EISA-type ID. This value must
            /// match at least one of the compatible device IDs returned by the corresponding _CID in the ACPI name space.
            cid: u32 align(1),

            /// Device’s PnP hardware ID stored as a null-terminated ASCII string. This value must match the corresponding
            /// _HID in the ACPI namespace. If the length of this string not including the null-terminator is 0, then
            /// the _HID field is used. If the length of this null-terminated string is greater than 0, then this field
            /// supersedes the _HID field.
            pub fn hidStr(self: *const ExpandedAcpi) [:0]const u8 {
                const ptr = @as([*:0]const u8, @ptrCast(self)) + @sizeOf(ExpandedAcpi);

                return std.mem.span(ptr);
            }

            /// Unique ID that is required by ACPI if two devices have the same _HID. This value must also match the
            /// corresponding _UID/_HID pair in the ACPI name space. This value is stored as a null-terminated ASCII
            /// string. If the length of this string not including the null-terminator is 0, then the _UID field is used.
            /// If the length of this null-terminated string is greater than 0, then this field supersedes the _UID field.
            pub fn uidStr(self: *const ExpandedAcpi) [:0]const u8 {
                const hid = self.hidStr();
                const ptr = hid.ptr + hid.len + 2;

                return std.mem.span(ptr);
            }

            /// Device’s compatible PnP hardware ID stored as a null-terminated ASCII string. This value must match at
            /// least one of the compatible device IDs returned by the corresponding _CID in the ACPI namespace. If the
            /// length of this string not including the null-terminator is 0, then the _CID field is used. If the length
            /// of this null-terminated string is greater than 0, then this field supersedes the _CID field.
            pub fn cidStr(self: *const ExpandedAcpi) [:0]const u8 {
                const uid = self.uidStr();
                const ptr = uid.ptr + uid.len + 2;

                return std.mem.span(ptr);
            }

            comptime {
                assert(16 == @sizeOf(ExpandedAcpi));
                assert(1 == @alignOf(ExpandedAcpi));

                assert(0 == @offsetOf(ExpandedAcpi, "type"));
                assert(1 == @offsetOf(ExpandedAcpi, "subtype"));
                assert(2 == @offsetOf(ExpandedAcpi, "length"));
                assert(4 == @offsetOf(ExpandedAcpi, "hid"));
                assert(8 == @offsetOf(ExpandedAcpi, "uid"));
                assert(12 == @offsetOf(ExpandedAcpi, "cid"));
            }
        };

        /// The _ADR device path is used to contain video output device attributes to support the Graphics Output
        /// Protocol. The device path can contain multiple _ADR entries if multiple video output devices are displaying
        /// the same output.
        pub const Adr = extern struct {
            type: DevicePath.Type = .acpi,
            subtype: Subtype = .adr,
            length: u16 align(1), // 4 + 4*x

            /// _ADR value. For video output devices the value of this field comes from Table B-2 ACPI 3.0 specification.
            /// At least one _ADR value is required.
            pub fn adrs(self: *const Adr) []align(1) const u32 {
                const ptr = @as([*]const u32, @ptrCast(self));

                const entries = @divExact(self.length, @sizeOf(u32));
                return ptr[1..entries];
            }

            comptime {
                assert(4 == @sizeOf(Adr));
                assert(1 == @alignOf(Adr));

                assert(0 == @offsetOf(Adr, "type"));
                assert(1 == @offsetOf(Adr, "subtype"));
                assert(2 == @offsetOf(Adr, "length"));
            }
        };

        pub const Nvdimm = extern struct {
            type: DevicePath.Type = .acpi,
            subtype: Subtype = .nvdimm,
            length: u16 align(1) = 8,

            /// NFIT device handle
            handle: u32,
        };
    };

    pub const Messaging = union(Subtype) {
        atapi: *const Atapi,
        scsi: *const Scsi,
        fibre_channel: *const FibreChannel,
        fibre_channel_ex: *const FibreChannelEx,
        @"1394": *const F1394,
        usb: *const Usb,
        sata: *const Sata,
        usb_wwid: *const UsbWwid,
        lun: *const DeviceLogicalUnit,
        usb_class: *const UsbClass,
        i2o: *const I2o,
        mac_address: *const MacAddress,
        ipv4: *const Ipv4,
        ipv6: *const Ipv6,
        vlan: *const Vlan,
        infiniband: *const InfiniBand,
        uart: *const UartDevicePath,
        vendor: *const Vendor,

        pub const Subtype = enum(u8) {
            atapi = 1,
            scsi = 2,
            fibre_channel = 3,
            fibre_channel_ex = 21,
            @"1394" = 4,
            usb = 5,
            sata = 18,
            usb_wwid = 16,
            lun = 17,
            usb_class = 15,
            i2o = 6,
            mac_address = 11,
            ipv4 = 12,
            ipv6 = 13,
            vlan = 20,
            infiniband = 9,
            uart = 14,
            vendor = 10,
            _,
        };

        pub const Atapi = extern struct {
            const Role = enum(u8) {
                master = 0,
                slave = 1,
            };

            const Rank = enum(u8) {
                primary = 0,
                secondary = 1,
            };

            type: Type = .messaging,
            subtype: Subtype = .atapi,
            length: u16 align(1) = 8,

            /// Primary or secondary channel
            primary_secondary: Rank,

            /// Master or slave device
            slave_master: Role,

            /// Logical unit number
            logical_unit_number: u16 align(1),

            comptime {
                assert(8 == @sizeOf(Atapi));
                assert(1 == @alignOf(Atapi));

                assert(0 == @offsetOf(Atapi, "type"));
                assert(1 == @offsetOf(Atapi, "subtype"));
                assert(2 == @offsetOf(Atapi, "length"));
                assert(4 == @offsetOf(Atapi, "primary_secondary"));
                assert(5 == @offsetOf(Atapi, "slave_master"));
                assert(6 == @offsetOf(Atapi, "logical_unit_number"));
            }
        };

        pub const Scsi = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .scsi,
            length: u16 align(1) = 8,

            /// Target ID on the SCSI bus
            target_id: u16 align(1),

            /// Logical unit number
            logical_unit_number: u16 align(1),

            comptime {
                assert(8 == @sizeOf(Scsi));
                assert(1 == @alignOf(Scsi));

                assert(0 == @offsetOf(Scsi, "type"));
                assert(1 == @offsetOf(Scsi, "subtype"));
                assert(2 == @offsetOf(Scsi, "length"));
                assert(4 == @offsetOf(Scsi, "target_id"));
                assert(6 == @offsetOf(Scsi, "logical_unit_number"));
            }
        };

        pub const FibreChannel = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .fibre_channel,
            length: u16 align(1) = 24,
            reserved: u32 align(1) = 0,

            /// World Wide Name
            world_wide_name: u64 align(1),

            /// Logical unit number
            logical_unit_number: u64 align(1),

            comptime {
                assert(24 == @sizeOf(FibreChannel));
                assert(1 == @alignOf(FibreChannel));

                assert(0 == @offsetOf(FibreChannel, "type"));
                assert(1 == @offsetOf(FibreChannel, "subtype"));
                assert(2 == @offsetOf(FibreChannel, "length"));
                assert(4 == @offsetOf(FibreChannel, "reserved"));
                assert(8 == @offsetOf(FibreChannel, "world_wide_name"));
                assert(16 == @offsetOf(FibreChannel, "logical_unit_number"));
            }
        };

        pub const FibreChannelEx = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .fibre_channel_ex,
            length: u16 align(1) = 24,
            reserved: u32 align(1) = 0,

            /// End Device Port Name
            world_wide_name: [8]u8,

            /// Logical unit number
            logical_unit_number: [8]u8,

            comptime {
                assert(24 == @sizeOf(FibreChannelEx));
                assert(1 == @alignOf(FibreChannelEx));

                assert(0 == @offsetOf(FibreChannelEx, "type"));
                assert(1 == @offsetOf(FibreChannelEx, "subtype"));
                assert(2 == @offsetOf(FibreChannelEx, "length"));
                assert(4 == @offsetOf(FibreChannelEx, "reserved"));
                assert(8 == @offsetOf(FibreChannelEx, "world_wide_name"));
                assert(16 == @offsetOf(FibreChannelEx, "logical_unit_number"));
            }
        };

        pub const F1394 = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .@"1394",
            length: u16 align(1) = 16,
            reserved: u32 align(1) = 0,

            /// 1394 GUID
            guid: u64 align(1),

            comptime {
                assert(16 == @sizeOf(F1394));
                assert(1 == @alignOf(F1394));

                assert(0 == @offsetOf(F1394, "type"));
                assert(1 == @offsetOf(F1394, "subtype"));
                assert(2 == @offsetOf(F1394, "length"));
                assert(4 == @offsetOf(F1394, "reserved"));
                assert(8 == @offsetOf(F1394, "guid"));
            }
        };

        pub const Usb = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .usb,
            length: u16 align(1) = 6,

            /// USB parent port number
            parent_port_number: u8,

            /// USB interface number
            interface_number: u8,

            comptime {
                assert(6 == @sizeOf(Usb));
                assert(1 == @alignOf(Usb));

                assert(0 == @offsetOf(Usb, "type"));
                assert(1 == @offsetOf(Usb, "subtype"));
                assert(2 == @offsetOf(Usb, "length"));
                assert(4 == @offsetOf(Usb, "parent_port_number"));
                assert(5 == @offsetOf(Usb, "interface_number"));
            }
        };

        pub const Sata = extern struct {
            type: DevicePath.Type = .messaging,
            subtype: Subtype = .sata,
            length: u16 align(1) = 10,

            /// The HBA port number that facilitates the connection to the device or a port multiplier. The value 0xFFFF
            /// is reserved.
            hba_port_number: u16 align(1),

            /// The port multiplier port number that facilitates the connection to the device. Must be set to 0xFFFF if
            /// the device is directly connected to the HBA.
            port_multiplier_port_number: u16 align(1),

            /// The logical unit number of the device.
            logical_unit_number: u16 align(1),

            comptime {
                assert(10 == @sizeOf(Sata));
                assert(1 == @alignOf(Sata));

                assert(0 == @offsetOf(Sata, "type"));
                assert(1 == @offsetOf(Sata, "subtype"));
                assert(2 == @offsetOf(Sata, "length"));
                assert(4 == @offsetOf(Sata, "hba_port_number"));
                assert(6 == @offsetOf(Sata, "port_multiplier_port_number"));
                assert(8 == @offsetOf(Sata, "logical_unit_number"));
            }
        };

        /// This device path describes a USB device using its serial number.
        pub const UsbWwid = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .usb_wwid,
            length: u16 align(1), // 10 + 2*x

            /// USB interface number
            interface_number: u16 align(1),

            /// USB device vendor ID
            device_vendor_id: u16 align(1),

            /// USB device product ID
            device_product_id: u16 align(1),

            /// Last 64-or-fewer UTF-16 characters of the USB serial number.
            pub fn serial(self: *const UsbWwid) []align(1) const u16 {
                // includes the 5 u16s that come before the serial number
                const serial_len = @divExact(self.length, @sizeOf(u16));
                const ptr = @as([*]const u16, @ptrCast(self));

                return ptr[5..serial_len];
            }

            comptime {
                assert(10 == @sizeOf(UsbWwid));
                assert(1 == @alignOf(UsbWwid));

                assert(0 == @offsetOf(UsbWwid, "type"));
                assert(1 == @offsetOf(UsbWwid, "subtype"));
                assert(2 == @offsetOf(UsbWwid, "length"));
                assert(4 == @offsetOf(UsbWwid, "interface_number"));
                assert(6 == @offsetOf(UsbWwid, "device_vendor_id"));
                assert(8 == @offsetOf(UsbWwid, "device_product_id"));
            }
        };

        pub const DeviceLogicalUnit = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .lun,
            length: u16 align(1) = 5,

            /// Logical unit number
            lun: u8,

            comptime {
                assert(5 == @sizeOf(DeviceLogicalUnit));
                assert(1 == @alignOf(DeviceLogicalUnit));

                assert(0 == @offsetOf(DeviceLogicalUnit, "type"));
                assert(1 == @offsetOf(DeviceLogicalUnit, "subtype"));
                assert(2 == @offsetOf(DeviceLogicalUnit, "length"));
                assert(4 == @offsetOf(DeviceLogicalUnit, "lun"));
            }
        };

        pub const UsbClass = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .usb_class,
            length: u16 align(1) = 11,

            vendor_id: u16 align(1),

            product_id: u16 align(1),

            device_class: u8,

            device_subclass: u8,

            device_protocol: u8,

            comptime {
                assert(11 == @sizeOf(UsbClass));
                assert(1 == @alignOf(UsbClass));

                assert(0 == @offsetOf(UsbClass, "type"));
                assert(1 == @offsetOf(UsbClass, "subtype"));
                assert(2 == @offsetOf(UsbClass, "length"));
                assert(4 == @offsetOf(UsbClass, "vendor_id"));
                assert(6 == @offsetOf(UsbClass, "product_id"));
                assert(8 == @offsetOf(UsbClass, "device_class"));
                assert(9 == @offsetOf(UsbClass, "device_subclass"));
                assert(10 == @offsetOf(UsbClass, "device_protocol"));
            }
        };

        pub const I2o = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .i2o,
            length: u16 align(1) = 8,

            /// Target ID for the device
            tid: u32 align(1),

            comptime {
                assert(8 == @sizeOf(I2o));
                assert(1 == @alignOf(I2o));

                assert(0 == @offsetOf(I2o, "type"));
                assert(1 == @offsetOf(I2o, "subtype"));
                assert(2 == @offsetOf(I2o, "length"));
                assert(4 == @offsetOf(I2o, "tid"));
            }
        };

        pub const MacAddress = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .mac_address,
            length: u16 align(1) = 37,

            /// Network interface MAC address, padded with zeros
            mac_address: bits.MacAddress,

            /// Network interface type, see RFC 3232.
            if_type: u8,

            comptime {
                assert(37 == @sizeOf(MacAddress));
                assert(1 == @alignOf(MacAddress));

                assert(0 == @offsetOf(MacAddress, "type"));
                assert(1 == @offsetOf(MacAddress, "subtype"));
                assert(2 == @offsetOf(MacAddress, "length"));
                assert(4 == @offsetOf(MacAddress, "mac_address"));
                assert(36 == @offsetOf(MacAddress, "if_type"));
            }
        };

        pub const Ipv4 = extern struct {
            pub const IpType = enum(u8) {
                dhcp = 0,
                static = 1,
            };

            type: Type = .messaging,
            subtype: Subtype = .ipv4,
            length: u16 align(1) = 27,

            /// Local IP address
            local_ip_address: bits.Ipv4Address align(1),

            /// Remote IP address
            remote_ip_address: bits.Ipv4Address align(1),

            /// Local port number
            local_port: u16 align(1),

            /// Remote port number
            remote_port: u16 align(1),

            /// Network protocol, see RFC 3232
            network_protocol: u16 align(1),

            /// If the address was assigned statically or via DHCP
            static_ip_address: IpType,

            /// Gateway IP address
            gateway_ip_address: bits.Ipv4Address align(1),

            /// Subnet mask
            subnet_mask: bits.Ipv4Address align(1),

            comptime {
                assert(27 == @sizeOf(Ipv4));
                assert(1 == @alignOf(Ipv4));

                assert(0 == @offsetOf(Ipv4, "type"));
                assert(1 == @offsetOf(Ipv4, "subtype"));
                assert(2 == @offsetOf(Ipv4, "length"));
                assert(4 == @offsetOf(Ipv4, "local_ip_address"));
                assert(8 == @offsetOf(Ipv4, "remote_ip_address"));
                assert(12 == @offsetOf(Ipv4, "local_port"));
                assert(14 == @offsetOf(Ipv4, "remote_port"));
                assert(16 == @offsetOf(Ipv4, "network_protocol"));
                assert(18 == @offsetOf(Ipv4, "static_ip_address"));
                assert(19 == @offsetOf(Ipv4, "gateway_ip_address"));
                assert(23 == @offsetOf(Ipv4, "subnet_mask"));
            }
        };

        pub const Ipv6 = extern struct {
            pub const Origin = enum(u8) {
                manual = 0,
                assigned_stateless = 1,
                assigned_stateful = 2,
            };

            type: Type = .messaging,
            subtype: Subtype = .ipv6,
            length: u16 align(1) = 60,

            /// Local IP address
            local_ip_address: bits.Ipv6Address,

            /// Remote IP address
            remote_ip_address: bits.Ipv6Address,

            /// Local port number
            local_port: u16 align(1),

            /// Remote port number
            remote_port: u16 align(1),

            /// Network protocol, see RFC 3232
            protocol: u16 align(1),

            /// If the address was assigned manually or via autoconfiguration
            ip_address_origin: Origin,

            /// Prefix length
            prefix_length: u8,

            /// Gateway IP address
            gateway_ip_address: bits.Ipv6Address,

            comptime {
                assert(60 == @sizeOf(Ipv6));
                assert(1 == @alignOf(Ipv6));

                assert(0 == @offsetOf(Ipv6, "type"));
                assert(1 == @offsetOf(Ipv6, "subtype"));
                assert(2 == @offsetOf(Ipv6, "length"));
                assert(4 == @offsetOf(Ipv6, "local_ip_address"));
                assert(20 == @offsetOf(Ipv6, "remote_ip_address"));
                assert(36 == @offsetOf(Ipv6, "local_port"));
                assert(38 == @offsetOf(Ipv6, "remote_port"));
                assert(40 == @offsetOf(Ipv6, "protocol"));
                assert(42 == @offsetOf(Ipv6, "ip_address_origin"));
                assert(43 == @offsetOf(Ipv6, "prefix_length"));
                assert(44 == @offsetOf(Ipv6, "gateway_ip_address"));
            }
        };

        pub const Vlan = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            vlan_id: u16 align(1),
        };

        comptime {
            assert(6 == @sizeOf(Vlan));
            assert(1 == @alignOf(Vlan));

            assert(0 == @offsetOf(Vlan, "type"));
            assert(1 == @offsetOf(Vlan, "subtype"));
            assert(2 == @offsetOf(Vlan, "length"));
            assert(4 == @offsetOf(Vlan, "vlan_id"));
        }

        pub const InfiniBand = extern struct {
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

            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            resource_flags: ResourceFlags align(1),
            port_gid: [16]u8,
            service_id: u64 align(1),
            target_port_id: u64 align(1),
            device_id: u64 align(1),

            comptime {
                assert(48 == @sizeOf(InfiniBand));
                assert(1 == @alignOf(InfiniBand));

                assert(0 == @offsetOf(InfiniBand, "type"));
                assert(1 == @offsetOf(InfiniBand, "subtype"));
                assert(2 == @offsetOf(InfiniBand, "length"));
                assert(4 == @offsetOf(InfiniBand, "resource_flags"));
                assert(8 == @offsetOf(InfiniBand, "port_gid"));
                assert(24 == @offsetOf(InfiniBand, "service_id"));
                assert(32 == @offsetOf(InfiniBand, "target_port_id"));
                assert(40 == @offsetOf(InfiniBand, "device_id"));
            }
        };

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

            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            reserved: u32 align(1),
            baud_rate: u64 align(1),
            data_bits: u8,
            parity: Parity,
            stop_bits: StopBits,
        };

        comptime {
            assert(19 == @sizeOf(UartDevicePath));
            assert(1 == @alignOf(UartDevicePath));

            assert(0 == @offsetOf(UartDevicePath, "type"));
            assert(1 == @offsetOf(UartDevicePath, "subtype"));
            assert(2 == @offsetOf(UartDevicePath, "length"));
            assert(4 == @offsetOf(UartDevicePath, "reserved"));
            assert(8 == @offsetOf(UartDevicePath, "baud_rate"));
            assert(16 == @offsetOf(UartDevicePath, "data_bits"));
            assert(17 == @offsetOf(UartDevicePath, "parity"));
            assert(18 == @offsetOf(UartDevicePath, "stop_bits"));
        }

        pub const Vendor = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            vendor_guid: Guid align(1),
        };

        comptime {
            assert(20 == @sizeOf(Vendor));
            assert(1 == @alignOf(Vendor));

            assert(0 == @offsetOf(Vendor, "type"));
            assert(1 == @offsetOf(Vendor, "subtype"));
            assert(2 == @offsetOf(Vendor, "length"));
            assert(4 == @offsetOf(Vendor, "vendor_guid"));
        }
    };

    pub const Media = union(Subtype) {
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

            type: DevicePath.Type,
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
            assert(42 == @sizeOf(HardDriveDevicePath));
            assert(1 == @alignOf(HardDriveDevicePath));

            assert(0 == @offsetOf(HardDriveDevicePath, "type"));
            assert(1 == @offsetOf(HardDriveDevicePath, "subtype"));
            assert(2 == @offsetOf(HardDriveDevicePath, "length"));
            assert(4 == @offsetOf(HardDriveDevicePath, "partition_number"));
            assert(8 == @offsetOf(HardDriveDevicePath, "partition_start"));
            assert(16 == @offsetOf(HardDriveDevicePath, "partition_size"));
            assert(24 == @offsetOf(HardDriveDevicePath, "partition_signature"));
            assert(40 == @offsetOf(HardDriveDevicePath, "partition_format"));
            assert(41 == @offsetOf(HardDriveDevicePath, "signature_type"));
        }

        pub const CdromDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            boot_entry: u32 align(1),
            partition_start: u64 align(1),
            partition_size: u64 align(1),
        };

        comptime {
            assert(24 == @sizeOf(CdromDevicePath));
            assert(1 == @alignOf(CdromDevicePath));

            assert(0 == @offsetOf(CdromDevicePath, "type"));
            assert(1 == @offsetOf(CdromDevicePath, "subtype"));
            assert(2 == @offsetOf(CdromDevicePath, "length"));
            assert(4 == @offsetOf(CdromDevicePath, "boot_entry"));
            assert(8 == @offsetOf(CdromDevicePath, "partition_start"));
            assert(16 == @offsetOf(CdromDevicePath, "partition_size"));
        }

        pub const VendorDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            guid: Guid align(1),
        };

        comptime {
            assert(20 == @sizeOf(VendorDevicePath));
            assert(1 == @alignOf(VendorDevicePath));

            assert(0 == @offsetOf(VendorDevicePath, "type"));
            assert(1 == @offsetOf(VendorDevicePath, "subtype"));
            assert(2 == @offsetOf(VendorDevicePath, "length"));
            assert(4 == @offsetOf(VendorDevicePath, "guid"));
        }

        pub const FilePathDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),

            pub fn getPath(self: *const FilePathDevicePath) [*:0]align(1) const u16 {
                return @as([*:0]align(1) const u16, @ptrCast(@as([*]const u8, @ptrCast(self)) + @sizeOf(FilePathDevicePath)));
            }
        };

        comptime {
            assert(4 == @sizeOf(FilePathDevicePath));
            assert(1 == @alignOf(FilePathDevicePath));

            assert(0 == @offsetOf(FilePathDevicePath, "type"));
            assert(1 == @offsetOf(FilePathDevicePath, "subtype"));
            assert(2 == @offsetOf(FilePathDevicePath, "length"));
        }

        pub const MediaProtocolDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            guid: Guid align(1),
        };

        comptime {
            assert(20 == @sizeOf(MediaProtocolDevicePath));
            assert(1 == @alignOf(MediaProtocolDevicePath));

            assert(0 == @offsetOf(MediaProtocolDevicePath, "type"));
            assert(1 == @offsetOf(MediaProtocolDevicePath, "subtype"));
            assert(2 == @offsetOf(MediaProtocolDevicePath, "length"));
            assert(4 == @offsetOf(MediaProtocolDevicePath, "guid"));
        }

        pub const PiwgFirmwareFileDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            fv_filename: Guid align(1),
        };

        comptime {
            assert(20 == @sizeOf(PiwgFirmwareFileDevicePath));
            assert(1 == @alignOf(PiwgFirmwareFileDevicePath));

            assert(0 == @offsetOf(PiwgFirmwareFileDevicePath, "type"));
            assert(1 == @offsetOf(PiwgFirmwareFileDevicePath, "subtype"));
            assert(2 == @offsetOf(PiwgFirmwareFileDevicePath, "length"));
            assert(4 == @offsetOf(PiwgFirmwareFileDevicePath, "fv_filename"));
        }

        pub const PiwgFirmwareVolumeDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            fv_name: Guid align(1),
        };

        comptime {
            assert(20 == @sizeOf(PiwgFirmwareVolumeDevicePath));
            assert(1 == @alignOf(PiwgFirmwareVolumeDevicePath));

            assert(0 == @offsetOf(PiwgFirmwareVolumeDevicePath, "type"));
            assert(1 == @offsetOf(PiwgFirmwareVolumeDevicePath, "subtype"));
            assert(2 == @offsetOf(PiwgFirmwareVolumeDevicePath, "length"));
            assert(4 == @offsetOf(PiwgFirmwareVolumeDevicePath, "fv_name"));
        }

        pub const RelativeOffsetRangeDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            reserved: u32 align(1),
            start: u64 align(1),
            end: u64 align(1),
        };

        comptime {
            assert(24 == @sizeOf(RelativeOffsetRangeDevicePath));
            assert(1 == @alignOf(RelativeOffsetRangeDevicePath));

            assert(0 == @offsetOf(RelativeOffsetRangeDevicePath, "type"));
            assert(1 == @offsetOf(RelativeOffsetRangeDevicePath, "subtype"));
            assert(2 == @offsetOf(RelativeOffsetRangeDevicePath, "length"));
            assert(4 == @offsetOf(RelativeOffsetRangeDevicePath, "reserved"));
            assert(8 == @offsetOf(RelativeOffsetRangeDevicePath, "start"));
            assert(16 == @offsetOf(RelativeOffsetRangeDevicePath, "end"));
        }

        pub const RamDiskDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            start: u64 align(1),
            end: u64 align(1),
            disk_type: Guid align(1),
            instance: u16 align(1),
        };

        comptime {
            assert(38 == @sizeOf(RamDiskDevicePath));
            assert(1 == @alignOf(RamDiskDevicePath));

            assert(0 == @offsetOf(RamDiskDevicePath, "type"));
            assert(1 == @offsetOf(RamDiskDevicePath, "subtype"));
            assert(2 == @offsetOf(RamDiskDevicePath, "length"));
            assert(4 == @offsetOf(RamDiskDevicePath, "start"));
            assert(12 == @offsetOf(RamDiskDevicePath, "end"));
            assert(20 == @offsetOf(RamDiskDevicePath, "disk_type"));
            assert(36 == @offsetOf(RamDiskDevicePath, "instance"));
        }
    };

    pub const BiosBootSpecification = union(Subtype) {
        BBS101: *const BBS101DevicePath,

        pub const Subtype = enum(u8) {
            BBS101 = 1,
            _,
        };

        pub const BBS101DevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            device_type: u16 align(1),
            status_flag: u16 align(1),

            pub fn getDescription(self: *const BBS101DevicePath) [*:0]const u8 {
                return @as([*:0]const u8, @ptrCast(self)) + @sizeOf(BBS101DevicePath);
            }
        };

        comptime {
            assert(8 == @sizeOf(BBS101DevicePath));
            assert(1 == @alignOf(BBS101DevicePath));

            assert(0 == @offsetOf(BBS101DevicePath, "type"));
            assert(1 == @offsetOf(BBS101DevicePath, "subtype"));
            assert(2 == @offsetOf(BBS101DevicePath, "length"));
            assert(4 == @offsetOf(BBS101DevicePath, "device_type"));
            assert(6 == @offsetOf(BBS101DevicePath, "status_flag"));
        }
    };

    pub const End = union(Subtype) {
        EndEntire: *const EndEntireDevicePath,
        EndThisInstance: *const EndThisInstanceDevicePath,

        pub const Subtype = enum(u8) {
            EndEntire = 0xff,
            EndThisInstance = 0x01,
            _,
        };

        pub const EndEntireDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
        };

        comptime {
            assert(4 == @sizeOf(EndEntireDevicePath));
            assert(1 == @alignOf(EndEntireDevicePath));

            assert(0 == @offsetOf(EndEntireDevicePath, "type"));
            assert(1 == @offsetOf(EndEntireDevicePath, "subtype"));
            assert(2 == @offsetOf(EndEntireDevicePath, "length"));
        }

        pub const EndThisInstanceDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
        };

        comptime {
            assert(4 == @sizeOf(EndEntireDevicePath));
            assert(1 == @alignOf(EndEntireDevicePath));

            assert(0 == @offsetOf(EndEntireDevicePath, "type"));
            assert(1 == @offsetOf(EndEntireDevicePath, "subtype"));
            assert(2 == @offsetOf(EndEntireDevicePath, "length"));
        }
    };
};
