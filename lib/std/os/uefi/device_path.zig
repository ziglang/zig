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

    pub const Any = extern struct {
        type: Type,
        subtype: u8,
        length: u16 align(1),
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
            type: Type = .acpi,
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
                const ptr: [*:0]const u8 = @ptrCast(self);

                return std.mem.span(ptr + @sizeOf(ExpandedAcpi));
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
            type: Type = .acpi,
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
            type: Type = .acpi,
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
        scsi_extended: *const ScsiExtended,
        iscsi: *const Iscsi,
        nvme_namespace: *const NvmeNamespace,
        uri: *const Uri,
        ufs: *const Ufs,
        sd: *const Sd,
        bluetooth: *const Bluetooth,
        wifi: *const Wifi,
        emmc: *const Emmc,
        bluetooth_le: *const BluetoothLe,
        dns: *const Dns,
        nvdimm_namespace: *const NvdimmNamespace,
        rest: *const Rest,
        nvme_over_fabric: *const NvmeOverFabric,

        pub const Subtype = enum(u8) {
            atapi = 1,
            scsi = 2,
            fibre_channel = 3,
            @"1394" = 4,
            usb = 5,
            i2o = 6,
            infiniband = 9,
            vendor = 10,
            mac_address = 11,
            ipv4 = 12,
            ipv6 = 13,
            uart = 14,
            usb_class = 15,
            usb_wwid = 16,
            lun = 17,
            sata = 18,
            iscsi = 19,
            vlan = 20,
            fibre_channel_ex = 21,
            scsi_extended = 22,
            nvme = 23,
            uri = 24,
            ufs = 25,
            sd = 26,
            bluetooth = 27,
            wifi = 28,
            emmc = 29,
            bluetooth_le = 30,
            dns = 31,
            nvdimm_namespace = 32,
            rest = 33,
            nvme_over_fabric = 34,

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
            type: Type = .messaging,
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
            type: Type = .messaging,
            subtype: Subtype = .vlan,
            length: u16 align(1) = 6,

            /// VLAN Identifier
            vlan_id: u16 align(1),

            comptime {
                assert(6 == @sizeOf(Vlan));
                assert(1 == @alignOf(Vlan));

                assert(0 == @offsetOf(Vlan, "type"));
                assert(1 == @offsetOf(Vlan, "subtype"));
                assert(2 == @offsetOf(Vlan, "length"));
                assert(4 == @offsetOf(Vlan, "vlan_id"));
            }
        };

        pub const InfiniBand = extern struct {
            pub const ResourceFlags = packed struct(u32) {
                pub const ControllerType = enum(u1) {
                    ioc = 0,
                    service = 1,
                };

                ioc_or_service: ControllerType,
                extend_boot_environment: bool,
                console_protocol: bool,
                storage_protocol: bool,
                network_protocol: bool,

                // u1 + 4 * bool = 5 bits, we need a total of 32 bits
                reserved: u27,
            };

            type: Type = .messaging,
            subtype: Subtype = .infiniband,
            length: u16 align(1) = 48,

            /// Flags to help identify/manage InfiniBand device path elements.
            resource_flags: ResourceFlags align(1),

            /// 128-bit global identifier for remote fabric port.
            port_gid: [16]u8,

            /// 64-bit unique identifier to remote IOC or server process.
            service_id: u64 align(1),

            /// 64-bit persistent ID of remote IOC port.
            target_port_id: u64 align(1),

            /// 64-bit persistent ID of remote device.
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
                default = 0,
                none = 1,
                even = 2,
                odd = 3,
                mark = 4,
                space = 5,
                _,
            };

            pub const StopBits = enum(u8) {
                default = 0,
                one = 1,
                one_and_half = 2,
                two = 3,
                _,
            };

            type: Type = .messaging,
            subtype: Subtype = .uart,
            length: u16 align(1) = 19,
            reserved: u32 align(1) = 0,

            /// The baud rate for the UART device. A value of 0 means default.
            baud_rate: u64 align(1),

            /// The number of data bits for the UART device. A value of 0 means default.
            data_bits: u8,

            /// The parity setting for the UART device.
            parity: Parity,

            /// The number of stop bits for the UART device.
            stop_bits: StopBits,

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
        };

        pub const Vendor = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .vendor,
            length: u16 align(1) = 20,

            /// Vendor-assigned GUID
            vendor_guid: Guid align(1),

            /// Vendor-specific data
            pub fn data(self: *const Vendor) []const u8 {
                const ptr: [*:0]const u8 = @ptrCast(self);

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

        /// This section defines the extended device node for Serial Attached SCSI (SAS) devices. In this device
        /// path the SAS Address and LUN are now defined as arrays to remove the need to endian swap the values.
        pub const ScsiExtended = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .scsi_extended,
            length: u16 align(1) = 32,

            /// SAS Address for the SCSI Target port
            address: [8]u8,

            /// SAS Logical unit number
            logical_unit_number: [8]u8,

            /// Device and topology information
            device_topology: u16 align(1),

            /// Relative Target Port
            relative_target_port: u16 align(1),

            comptime {
                assert(32 == @sizeOf(ScsiExtended));
                assert(1 == @alignOf(ScsiExtended));

                assert(0 == @offsetOf(ScsiExtended, "type"));
                assert(1 == @offsetOf(ScsiExtended, "subtype"));
                assert(2 == @offsetOf(ScsiExtended, "length"));
                assert(4 == @offsetOf(ScsiExtended, "address"));
                assert(20 == @offsetOf(ScsiExtended, "logical_unit_number"));
                assert(28 == @offsetOf(ScsiExtended, "device_topology"));
                assert(30 == @offsetOf(ScsiExtended, "relative_target_port"));
            }
        };

        pub const Iscsi = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .iscsi,
            length: u16 align(1), // 18 + x

            /// Network protocol. 0=TCP, 1+ is reserved.
            network_protocol: u16 align(1),

            /// iSCSI login options
            login_options: u16 align(1),

            /// iSCSI LUN
            logical_unit_number: [8]u8,

            /// iSCSI target portal group tag the initiator intends to establish a session with.
            target_portal_group: u16 align(1),

            /// iSCSI node target name
            pub fn target_name(self: *const Iscsi) []const u8 {
                const ptr: [*:0]const u8 = @ptrCast(self);

                return ptr[18..self.length];
            }

            comptime {
                assert(18 == @sizeOf(Iscsi));
                assert(1 == @alignOf(Iscsi));

                assert(0 == @offsetOf(Iscsi, "type"));
                assert(1 == @offsetOf(Iscsi, "subtype"));
                assert(2 == @offsetOf(Iscsi, "length"));
                assert(4 == @offsetOf(Iscsi, "network_protocol"));
                assert(6 == @offsetOf(Iscsi, "login_options"));
                assert(8 == @offsetOf(Iscsi, "logical_unit_number"));
                assert(16 == @offsetOf(Iscsi, "target_portal_group"));
            }
        };

        pub const NvmeNamespace = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .nvme,
            length: u16 align(1) = 16,

            /// Namespace ID, 0 and 0xFFFFFFFF are invalid.
            namespace_id: u32 align(1),

            /// the IEEE EUI-64 for the namespace
            namespace_eid: [8]u8 align(1),

            comptime {
                assert(16 == @sizeOf(NvmeNamespace));
                assert(1 == @alignOf(NvmeNamespace));

                assert(0 == @offsetOf(NvmeNamespace, "type"));
                assert(1 == @offsetOf(NvmeNamespace, "subtype"));
                assert(2 == @offsetOf(NvmeNamespace, "length"));
                assert(4 == @offsetOf(NvmeNamespace, "namespace_id"));
                assert(8 == @offsetOf(NvmeNamespace, "namespace_eid"));
            }
        };

        pub const Uri = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .uri,
            length: u16 align(1), // 4 + x

            /// URI string
            pub fn uri(self: *const Uri) []const u8 {
                const ptr: [*:0]const u8 = @ptrCast(self);

                return ptr[4..self.length];
            }

            comptime {
                assert(4 == @sizeOf(Uri));
                assert(1 == @alignOf(Uri));

                assert(0 == @offsetOf(Uri, "type"));
                assert(1 == @offsetOf(Uri, "subtype"));
                assert(2 == @offsetOf(Uri, "length"));
            }
        };

        pub const Ufs = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .ufs,
            length: u16 align(1) = 6,

            /// Target id on the UFS interface
            pun: u8,

            /// Logical unit number
            lun: u8,

            comptime {
                assert(6 == @sizeOf(Ufs));
                assert(1 == @alignOf(Ufs));

                assert(0 == @offsetOf(Ufs, "type"));
                assert(1 == @offsetOf(Ufs, "subtype"));
                assert(2 == @offsetOf(Ufs, "length"));
                assert(4 == @offsetOf(Ufs, "pun"));
                assert(5 == @offsetOf(Ufs, "lun"));
            }
        };

        pub const Sd = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .sd,
            length: u16 align(1) = 5,

            /// Slot number
            slot_number: u8,

            comptime {
                assert(6 == @sizeOf(Sd));
                assert(1 == @alignOf(Sd));

                assert(0 == @offsetOf(Sd, "type"));
                assert(1 == @offsetOf(Sd, "subtype"));
                assert(2 == @offsetOf(Sd, "length"));
                assert(4 == @offsetOf(Sd, "slot_number"));
            }
        };

        pub const Bluetooth = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .bluetooth,
            length: u16 align(1) = 10,

            /// Bluetooth device address
            address: [6]u8 align(1),

            comptime {
                assert(10 == @sizeOf(Bluetooth));
                assert(1 == @alignOf(Bluetooth));

                assert(0 == @offsetOf(Bluetooth, "type"));
                assert(1 == @offsetOf(Bluetooth, "subtype"));
                assert(2 == @offsetOf(Bluetooth, "length"));
                assert(4 == @offsetOf(Bluetooth, "address"));
            }
        };

        pub const Wifi = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .wifi,
            length: u16 align(1) = 36,

            ssid: [32]u8,

            comptime {
                assert(36 == @sizeOf(Wifi));
                assert(1 == @alignOf(Wifi));

                assert(0 == @offsetOf(Wifi, "type"));
                assert(1 == @offsetOf(Wifi, "subtype"));
                assert(2 == @offsetOf(Wifi, "length"));
                assert(4 == @offsetOf(Wifi, "ssid"));
            }
        };

        pub const Emmc = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .emmc,
            length: u16 align(1) = 5,

            /// Slot number
            slot_number: u8,

            comptime {
                assert(5 == @sizeOf(Emmc));
                assert(1 == @alignOf(Emmc));

                assert(0 == @offsetOf(Emmc, "type"));
                assert(1 == @offsetOf(Emmc, "subtype"));
                assert(2 == @offsetOf(Emmc, "length"));
                assert(4 == @offsetOf(Emmc, "slot_number"));
            }
        };

        pub const BluetoothLe = extern struct {
            pub const AddressType = enum(u8) {
                public = 0,
                random = 1,
            };

            type: Type = .messaging,
            subtype: Subtype = .bluetooth_le,
            length: u16 align(1) = 11,

            /// Bluetooth device address
            address: [6]u8 align(1),

            address_type: AddressType,

            comptime {
                assert(11 == @sizeOf(BluetoothLe));
                assert(1 == @alignOf(BluetoothLe));

                assert(0 == @offsetOf(BluetoothLe, "type"));
                assert(1 == @offsetOf(BluetoothLe, "subtype"));
                assert(2 == @offsetOf(BluetoothLe, "length"));
                assert(4 == @offsetOf(BluetoothLe, "address"));
                assert(10 == @offsetOf(BluetoothLe, "address_type"));
            }
        };

        pub const Dns = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .dns,
            length: u16 align(1), // 5 + x

            /// If true, the addresses are IPv6, otherwise IPv4
            is_ipv6: bool,

            pub fn addresses(self: *const Dns) []align(1) const bits.IpAddress {
                const ptr = @as([*:0]const u8, @ptrCast(self)) + 5;
                const adrs: [*:0]align(1) const bits.IpAddress = @ptrCast(ptr);

                const entries = @divExact(self.length - 5, @sizeOf(bits.IpAddress));
                return adrs[0..entries];
            }

            comptime {
                assert(5 == @sizeOf(Dns));
                assert(1 == @alignOf(Dns));

                assert(0 == @offsetOf(Dns, "type"));
                assert(1 == @offsetOf(Dns, "subtype"));
                assert(2 == @offsetOf(Dns, "length"));
                assert(4 == @offsetOf(Dns, "is_ipv6"));
            }
        };

        pub const NvdimmNamespace = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .nvdimm_namespace,
            length: u16 align(1) = 20,

            /// Namespace unique label identifier UUID.
            namespace_uuid: [16]u8 align(1),

            comptime {
                assert(20 == @sizeOf(NvdimmNamespace));
                assert(1 == @alignOf(NvdimmNamespace));

                assert(0 == @offsetOf(NvdimmNamespace, "type"));
                assert(1 == @offsetOf(NvdimmNamespace, "subtype"));
                assert(2 == @offsetOf(NvdimmNamespace, "length"));
                assert(4 == @offsetOf(NvdimmNamespace, "namespace_uuid"));
            }
        };

        pub const Rest = extern struct {
            pub const Service = enum(u8) {
                redfish = 1,
                odata = 2,
                vendor = 0xff,
                _,
            };

            pub const AccessMode = enum(u8) {
                in_band = 1,
                out_of_band = 2,
                _,
            };

            type: Type = .messaging,
            subtype: Subtype = .rest,
            length: u16 align(1) = 6,

            /// Service type
            service: Service,

            /// Access mode
            access_mode: AccessMode,

            comptime {
                assert(6 == @sizeOf(Rest));
                assert(1 == @alignOf(Rest));

                assert(0 == @offsetOf(Rest, "type"));
                assert(1 == @offsetOf(Rest, "subtype"));
                assert(2 == @offsetOf(Rest, "length"));
                assert(4 == @offsetOf(Rest, "service"));
                assert(5 == @offsetOf(Rest, "access_mode"));
            }
        };

        pub const NvmeOverFabric = extern struct {
            type: Type = .messaging,
            subtype: Subtype = .nvme_over_fabric,
            length: u16 align(1), // 20 + x

            /// Namespace identifier type
            nidt: u8,

            /// Namespace id
            nid: [16]u8,

            /// Unique identifier of an NVMe subsystem stored as a null-terminated UTF-8 string.
            pub fn data(self: *const NvmeOverFabric) [:0]const u8 {
                const ptr: [*:0]const u8 = @ptrCast(self);

                return ptr[20..self.length :0];
            }

            comptime {
                assert(16 == @sizeOf(NvmeOverFabric));
                assert(1 == @alignOf(NvmeOverFabric));

                assert(0 == @offsetOf(NvmeOverFabric, "type"));
                assert(1 == @offsetOf(NvmeOverFabric, "subtype"));
                assert(2 == @offsetOf(NvmeOverFabric, "length"));
                assert(4 == @offsetOf(NvmeOverFabric, "namespace_uuid"));
            }
        };
    };

    pub const Media = union(Subtype) {
        hard_drive: *const HardDrive,
        cdrom: *const Cdrom,
        vendor: *const Vendor,
        file_path: *const FilePath,
        media_protocol: *const MediaProtocol,
        piwg_firmware_file: *const PiwgFirmwareFile,
        piwg_firmware_volume: *const PiwgFirmwareVolume,
        relative_offset_range: *const RelativeOffsetRange,
        ram_disk: *const RamDisk,

        pub const Subtype = enum(u8) {
            hard_drive = 1,
            cdrom = 2,
            vendor = 3,
            file_path = 4,
            media_protocol = 5,
            piwg_firmware_file = 6,
            piwg_firmware_volume = 7,
            relative_offset_range = 8,
            ram_disk = 9,
            _,
        };

        /// The Hard Drive Media Device Path is used to represent a partition on a hard drive. Each partition has at
        /// least Hard Drive Device Path node, each describing an entry in a partition table. EFI supports MBR and
        /// GPT partitioning formats. Partitions are numbered according to their entry in their respective partition
        /// table, starting with 1. Partitions are addressed in EFI starting at LBA zero. A partition number of zero
        /// can be used to represent the raw hard drive or a raw extended partition.
        ///
        /// The partition format is stored in the Device Path to allow new partition formats to be supported in the
        /// future. The Hard Drive Device Path also contains a Disk Signature and a Disk Signature Type. The disk
        /// signature is maintained by the OS and only used by EFI to partition Device Path nodes. The disk
        /// signature enables the OS to find disks even after they have been physically moved in a system.
        pub const HardDrive = extern struct {
            pub const Format = enum(u8) {
                mbr = 0x01,
                gpt = 0x02,
            };

            pub const SignatureType = enum(u8) {
                none = 0x00,
                /// "32-bit signature from address 0x1b8 of the type 0x01 MBR"
                mbr = 0x01,
                guid = 0x02,
            };

            type: Type = .media,
            subtype: Subtype = .hard_drive,
            length: u16 align(1) = 42,

            /// Describes the partition number of the physical hard drive.
            partition_number: u32 align(1),

            /// The starting LBA of the partition
            partition_start: u64 align(1),

            /// Size of the partition in logical blocks
            partition_size: u64 align(1),

            /// Signature unique to this partition
            partition_signature: [16]u8,

            /// Partition format
            partition_format: Format,

            /// Signature type
            signature_type: SignatureType,

            comptime {
                assert(42 == @sizeOf(HardDrive));
                assert(1 == @alignOf(HardDrive));

                assert(0 == @offsetOf(HardDrive, "type"));
                assert(1 == @offsetOf(HardDrive, "subtype"));
                assert(2 == @offsetOf(HardDrive, "length"));
                assert(4 == @offsetOf(HardDrive, "partition_number"));
                assert(8 == @offsetOf(HardDrive, "partition_start"));
                assert(16 == @offsetOf(HardDrive, "partition_size"));
                assert(24 == @offsetOf(HardDrive, "partition_signature"));
                assert(40 == @offsetOf(HardDrive, "partition_format"));
                assert(41 == @offsetOf(HardDrive, "signature_type"));
            }
        };

        /// The CD-ROM Media Device Path is used to define a system partition that exists on a CD-ROM. The CD-ROM is
        /// assumed to contain an ISO-9660 file system and follow the CD-ROM “El Torito” format. The Boot Entry
        /// number from the Boot Catalog is how the “El Torito” specification defines the existence of bootable
        /// entities on a CD-ROM. In EFI the bootable entity is an EFI System Partition that is pointed to by the
        /// Boot Entry.
        pub const Cdrom = extern struct {
            type: Type = .media,
            subtype: Subtype = .cdrom,
            length: u16 align(1) = 24,

            ///Boot Entry Number from the Boot Catalog. The default entry is zero.
            boot_entry: u32 align(1),

            /// Starting RBA of the partition on the medium. CDROMs use Relative logical Block Addressing.
            partition_start: u64 align(1),

            /// Size of the partition in units of Blocks, also called Sectors.
            partition_size: u64 align(1),

            comptime {
                assert(24 == @sizeOf(Cdrom));
                assert(1 == @alignOf(Cdrom));

                assert(0 == @offsetOf(Cdrom, "type"));
                assert(1 == @offsetOf(Cdrom, "subtype"));
                assert(2 == @offsetOf(Cdrom, "length"));
                assert(4 == @offsetOf(Cdrom, "boot_entry"));
                assert(8 == @offsetOf(Cdrom, "partition_start"));
                assert(16 == @offsetOf(Cdrom, "partition_size"));
            }
        };

        pub const Vendor = extern struct {
            type: Type = .media,
            subtype: Subtype = .vendor,
            length: u16 align(1), // 20 + x

            /// Vendor GUID
            guid: Guid align(1),

            /// Vendor-specific data
            pub fn data(self: *const Vendor) []const u8 {
                const ptr: [*:0]const u8 = @ptrCast(self);

                return ptr[@sizeOf(Vendor)..self.length];
            }

            comptime {
                assert(20 == @sizeOf(Vendor));
                assert(1 == @alignOf(Vendor));

                assert(0 == @offsetOf(Vendor, "type"));
                assert(1 == @offsetOf(Vendor, "subtype"));
                assert(2 == @offsetOf(Vendor, "length"));
                assert(4 == @offsetOf(Vendor, "guid"));
            }
        };

        pub const FilePath = extern struct {
            type: Type = .media,
            subtype: Subtype = .file_path,
            length: u16 align(1), // 4 + x

            ///A NULL-terminated Path string including directory and file names. The length of this string n can be
            /// determined by subtracting 4 from the Length entry. A device path may contain one or more of these
            /// nodes. Each node can optionally add a “" separator to the beginning and/or the end of the Path Name
            /// string. The complete path to a file can be found by logically concatenating all the Path Name
            /// strings in the File Path Media Device Path nodes.
            pub fn path(self: *const FilePath) [:0]align(1) const u16 {
                const ptr: [*:0]align(1) const u16 = @ptrCast(self);

                const entries = @divExact(self.length, 2);
                return ptr[2..entries];
            }

            comptime {
                assert(4 == @sizeOf(FilePath));
                assert(1 == @alignOf(FilePath));

                assert(0 == @offsetOf(FilePath, "type"));
                assert(1 == @offsetOf(FilePath, "subtype"));
                assert(2 == @offsetOf(FilePath, "length"));
            }
        };

        pub const MediaProtocol = extern struct {
            type: Type = .media,
            subtype: Subtype = .media_protocol,
            length: u16 align(1) = 20,

            /// The ID of the protocol.
            guid: Guid align(1),

            comptime {
                assert(20 == @sizeOf(MediaProtocol));
                assert(1 == @alignOf(MediaProtocol));

                assert(0 == @offsetOf(MediaProtocol, "type"));
                assert(1 == @offsetOf(MediaProtocol, "subtype"));
                assert(2 == @offsetOf(MediaProtocol, "length"));
                assert(4 == @offsetOf(MediaProtocol, "guid"));
            }
        };

        /// This type is used by systems implementing the PI architecture specifications to describe a firmware
        /// file in a firmware volume.
        pub const PiwgFirmwareFile = extern struct {
            type: Type = .media,
            subtype: Subtype = .piwg_firmware_file,
            length: u16 align(1) = 20,

            /// Firmware file name
            fv_filename: Guid align(1),

            comptime {
                assert(20 == @sizeOf(PiwgFirmwareFile));
                assert(1 == @alignOf(PiwgFirmwareFile));

                assert(0 == @offsetOf(PiwgFirmwareFile, "type"));
                assert(1 == @offsetOf(PiwgFirmwareFile, "subtype"));
                assert(2 == @offsetOf(PiwgFirmwareFile, "length"));
                assert(4 == @offsetOf(PiwgFirmwareFile, "fv_filename"));
            }
        };

        /// This type is used by systems implementing the PI architecture specifications to describe a firmware volume.
        pub const PiwgFirmwareVolume = extern struct {
            type: Type = .media,
            subtype: Subtype = .piwg_firmware_volume,
            length: u16 align(1) = 20,

            /// Firmware volume name
            fv_name: Guid align(1),

            comptime {
                assert(20 == @sizeOf(PiwgFirmwareVolume));
                assert(1 == @alignOf(PiwgFirmwareVolume));

                assert(0 == @offsetOf(PiwgFirmwareVolume, "type"));
                assert(1 == @offsetOf(PiwgFirmwareVolume, "subtype"));
                assert(2 == @offsetOf(PiwgFirmwareVolume, "length"));
                assert(4 == @offsetOf(PiwgFirmwareVolume, "fv_name"));
            }
        };

        /// This device path node specifies a range of offsets relative to the first byte available on the device.
        /// The starting offset is the first byte of the range and the ending offset is the last byte of the range
        /// (not the last byte + 1).
        pub const RelativeOffsetRange = extern struct {
            type: Type = .media,
            subtype: Subtype = .relative_offset_range,
            length: u16 align(1) = 24,
            reserved: u32 align(1),

            /// Offset of the first byte, relative to the parent device node.
            start: u64 align(1),

            /// Offset of the last byte, relative to the parent device node.
            end: u64 align(1),

            comptime {
                assert(24 == @sizeOf(RelativeOffsetRange));
                assert(1 == @alignOf(RelativeOffsetRange));

                assert(0 == @offsetOf(RelativeOffsetRange, "type"));
                assert(1 == @offsetOf(RelativeOffsetRange, "subtype"));
                assert(2 == @offsetOf(RelativeOffsetRange, "length"));
                assert(4 == @offsetOf(RelativeOffsetRange, "reserved"));
                assert(8 == @offsetOf(RelativeOffsetRange, "start"));
                assert(16 == @offsetOf(RelativeOffsetRange, "end"));
            }
        };

        pub const RamDisk = extern struct {
            type: Type = .media,
            subtype: Subtype = .ram_disk,
            length: u16 align(1) = 38,

            /// Starting memory address
            start: u64 align(1),

            /// Ending memory address
            end: u64 align(1),

            /// GUID that defines the type of the RAM Disk.
            disk_type: Guid align(1),

            /// RAM Disk instance number, if supported. The default value is zero.
            instance: u16 align(1),

            comptime {
                assert(38 == @sizeOf(RamDisk));
                assert(1 == @alignOf(RamDisk));

                assert(0 == @offsetOf(RamDisk, "type"));
                assert(1 == @offsetOf(RamDisk, "subtype"));
                assert(2 == @offsetOf(RamDisk, "length"));
                assert(4 == @offsetOf(RamDisk, "start"));
                assert(12 == @offsetOf(RamDisk, "end"));
                assert(20 == @offsetOf(RamDisk, "disk_type"));
                assert(36 == @offsetOf(RamDisk, "instance"));
            }
        };
    };

    pub const BiosBootSpecification = union(Subtype) {
        bbs101: *const BBS101,

        pub const Subtype = enum(u8) {
            bbs101 = 1,
            _,
        };

        pub const BBS101 = extern struct {
            type: Type = .bios_boot_specification,
            subtype: Subtype = .bbs101,
            length: u16 align(1), // 8 + x

            /// Device Type as defined by the BIOS Boot Specification.
            device_type: u16 align(1),

            /// Status Flags as defined by the BIOS Boot Specification
            status_flag: u16 align(1),

            pub fn description(self: *const BBS101) [*:0]const u8 {
                return @as([*:0]const u8, @ptrCast(self)) + @sizeOf(BBS101);
            }

            comptime {
                assert(8 == @sizeOf(BBS101));
                assert(1 == @alignOf(BBS101));

                assert(0 == @offsetOf(BBS101, "type"));
                assert(1 == @offsetOf(BBS101, "subtype"));
                assert(2 == @offsetOf(BBS101, "length"));
                assert(4 == @offsetOf(BBS101, "device_type"));
                assert(6 == @offsetOf(BBS101, "status_flag"));
            }
        };
    };

    pub const End = union(Subtype) {
        entire: *const EndEntire,
        this_instance: *const EndThisInstance,

        pub const Subtype = enum(u8) {
            entire = 0xff,
            this_instance = 0x01,
            _,
        };

        pub const EndEntire = extern struct {
            type: Type = .end,
            subtype: Subtype = .entire,
            length: u16 align(1) = 4,

            comptime {
                assert(4 == @sizeOf(EndEntire));
                assert(1 == @alignOf(EndEntire));

                assert(0 == @offsetOf(EndEntire, "type"));
                assert(1 == @offsetOf(EndEntire, "subtype"));
                assert(2 == @offsetOf(EndEntire, "length"));
            }
        };

        pub const EndThisInstance = extern struct {
            type: Type = .end,
            subtype: Subtype = .this_instance,
            length: u16 align(1) = 4,

            comptime {
                assert(4 == @sizeOf(EndEntire));
                assert(1 == @alignOf(EndEntire));

                assert(0 == @offsetOf(EndEntire, "type"));
                assert(1 == @offsetOf(EndEntire, "subtype"));
                assert(2 == @offsetOf(EndEntire, "length"));
            }
        };
    };
};
