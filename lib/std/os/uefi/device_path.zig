const std = @import("../../std.zig");
const assert = std.debug.assert;
const uefi = std.os.uefi;
const Guid = uefi.Guid;

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
        pci: *const PciDevicePath,
        pc_card: *const PcCardDevicePath,
        memory_mapped: *const MemoryMappedDevicePath,
        vendor: *const VendorDevicePath,
        controller: *const ControllerDevicePath,
        bmc: *const BmcDevicePath,

        pub const Subtype = enum(u8) {
            pci = 1,
            pc_card = 2,
            memory_mapped = 3,
            vendor = 4,
            controller = 5,
            bmc = 6,
            _,
        };

        pub const PciDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            function: u8,
            device: u8,
        };

        comptime {
            assert(6 == @sizeOf(PciDevicePath));
            assert(1 == @alignOf(PciDevicePath));

            assert(0 == @offsetOf(PciDevicePath, "type"));
            assert(1 == @offsetOf(PciDevicePath, "subtype"));
            assert(2 == @offsetOf(PciDevicePath, "length"));
            assert(4 == @offsetOf(PciDevicePath, "function"));
            assert(5 == @offsetOf(PciDevicePath, "device"));
        }

        pub const PcCardDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            function_number: u8,
        };

        comptime {
            assert(5 == @sizeOf(PcCardDevicePath));
            assert(1 == @alignOf(PcCardDevicePath));

            assert(0 == @offsetOf(PcCardDevicePath, "type"));
            assert(1 == @offsetOf(PcCardDevicePath, "subtype"));
            assert(2 == @offsetOf(PcCardDevicePath, "length"));
            assert(4 == @offsetOf(PcCardDevicePath, "function_number"));
        }

        pub const MemoryMappedDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            memory_type: u32 align(1),
            start_address: u64 align(1),
            end_address: u64 align(1),
        };

        comptime {
            assert(24 == @sizeOf(MemoryMappedDevicePath));
            assert(1 == @alignOf(MemoryMappedDevicePath));

            assert(0 == @offsetOf(MemoryMappedDevicePath, "type"));
            assert(1 == @offsetOf(MemoryMappedDevicePath, "subtype"));
            assert(2 == @offsetOf(MemoryMappedDevicePath, "length"));
            assert(4 == @offsetOf(MemoryMappedDevicePath, "memory_type"));
            assert(8 == @offsetOf(MemoryMappedDevicePath, "start_address"));
            assert(16 == @offsetOf(MemoryMappedDevicePath, "end_address"));
        }

        pub const VendorDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            vendor_guid: Guid align(1),
        };

        comptime {
            assert(20 == @sizeOf(VendorDevicePath));
            assert(1 == @alignOf(VendorDevicePath));

            assert(0 == @offsetOf(VendorDevicePath, "type"));
            assert(1 == @offsetOf(VendorDevicePath, "subtype"));
            assert(2 == @offsetOf(VendorDevicePath, "length"));
            assert(4 == @offsetOf(VendorDevicePath, "vendor_guid"));
        }

        pub const ControllerDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            controller_number: u32 align(1),
        };

        comptime {
            assert(8 == @sizeOf(ControllerDevicePath));
            assert(1 == @alignOf(ControllerDevicePath));

            assert(0 == @offsetOf(ControllerDevicePath, "type"));
            assert(1 == @offsetOf(ControllerDevicePath, "subtype"));
            assert(2 == @offsetOf(ControllerDevicePath, "length"));
            assert(4 == @offsetOf(ControllerDevicePath, "controller_number"));
        }

        pub const BmcDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            interface_type: u8,
            base_address: u64 align(1),
        };

        comptime {
            assert(13 == @sizeOf(BmcDevicePath));
            assert(1 == @alignOf(BmcDevicePath));

            assert(0 == @offsetOf(BmcDevicePath, "type"));
            assert(1 == @offsetOf(BmcDevicePath, "subtype"));
            assert(2 == @offsetOf(BmcDevicePath, "length"));
            assert(4 == @offsetOf(BmcDevicePath, "interface_type"));
            assert(5 == @offsetOf(BmcDevicePath, "base_address"));
        }
    };

    pub const Acpi = union(Subtype) {
        acpi: *const BaseAcpiDevicePath,
        expanded_acpi: *const ExpandedAcpiDevicePath,
        adr: *const AdrDevicePath,

        pub const Subtype = enum(u8) {
            acpi = 1,
            expanded_acpi = 2,
            adr = 3,
            _,
        };

        pub const BaseAcpiDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            hid: u32 align(1),
            uid: u32 align(1),
        };

        comptime {
            assert(12 == @sizeOf(BaseAcpiDevicePath));
            assert(1 == @alignOf(BaseAcpiDevicePath));

            assert(0 == @offsetOf(BaseAcpiDevicePath, "type"));
            assert(1 == @offsetOf(BaseAcpiDevicePath, "subtype"));
            assert(2 == @offsetOf(BaseAcpiDevicePath, "length"));
            assert(4 == @offsetOf(BaseAcpiDevicePath, "hid"));
            assert(8 == @offsetOf(BaseAcpiDevicePath, "uid"));
        }

        pub const ExpandedAcpiDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            hid: u32 align(1),
            uid: u32 align(1),
            cid: u32 align(1),
            // variable length u16[*:0] strings
            // hid_str, uid_str, cid_str
        };

        comptime {
            assert(16 == @sizeOf(ExpandedAcpiDevicePath));
            assert(1 == @alignOf(ExpandedAcpiDevicePath));

            assert(0 == @offsetOf(ExpandedAcpiDevicePath, "type"));
            assert(1 == @offsetOf(ExpandedAcpiDevicePath, "subtype"));
            assert(2 == @offsetOf(ExpandedAcpiDevicePath, "length"));
            assert(4 == @offsetOf(ExpandedAcpiDevicePath, "hid"));
            assert(8 == @offsetOf(ExpandedAcpiDevicePath, "uid"));
            assert(12 == @offsetOf(ExpandedAcpiDevicePath, "cid"));
        }

        pub const AdrDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            adr: u32 align(1),

            // multiple adr entries can optionally follow
            pub fn adrs(self: *const AdrDevicePath) []align(1) const u32 {
                // self.length is a minimum of 8 with one adr which is size 4.
                const entries = (self.length - 4) / @sizeOf(u32);
                return @as([*]align(1) const u32, @ptrCast(&self.adr))[0..entries];
            }
        };

        comptime {
            assert(8 == @sizeOf(AdrDevicePath));
            assert(1 == @alignOf(AdrDevicePath));

            assert(0 == @offsetOf(AdrDevicePath, "type"));
            assert(1 == @offsetOf(AdrDevicePath, "subtype"));
            assert(2 == @offsetOf(AdrDevicePath, "length"));
            assert(4 == @offsetOf(AdrDevicePath, "adr"));
        }
    };

    pub const Messaging = union(Subtype) {
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

            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            primary_secondary: Rank,
            slave_master: Role,
            logical_unit_number: u16 align(1),
        };

        comptime {
            assert(8 == @sizeOf(AtapiDevicePath));
            assert(1 == @alignOf(AtapiDevicePath));

            assert(0 == @offsetOf(AtapiDevicePath, "type"));
            assert(1 == @offsetOf(AtapiDevicePath, "subtype"));
            assert(2 == @offsetOf(AtapiDevicePath, "length"));
            assert(4 == @offsetOf(AtapiDevicePath, "primary_secondary"));
            assert(5 == @offsetOf(AtapiDevicePath, "slave_master"));
            assert(6 == @offsetOf(AtapiDevicePath, "logical_unit_number"));
        }

        pub const ScsiDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            target_id: u16 align(1),
            logical_unit_number: u16 align(1),
        };

        comptime {
            assert(8 == @sizeOf(ScsiDevicePath));
            assert(1 == @alignOf(ScsiDevicePath));

            assert(0 == @offsetOf(ScsiDevicePath, "type"));
            assert(1 == @offsetOf(ScsiDevicePath, "subtype"));
            assert(2 == @offsetOf(ScsiDevicePath, "length"));
            assert(4 == @offsetOf(ScsiDevicePath, "target_id"));
            assert(6 == @offsetOf(ScsiDevicePath, "logical_unit_number"));
        }

        pub const FibreChannelDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            reserved: u32 align(1),
            world_wide_name: u64 align(1),
            logical_unit_number: u64 align(1),
        };

        comptime {
            assert(24 == @sizeOf(FibreChannelDevicePath));
            assert(1 == @alignOf(FibreChannelDevicePath));

            assert(0 == @offsetOf(FibreChannelDevicePath, "type"));
            assert(1 == @offsetOf(FibreChannelDevicePath, "subtype"));
            assert(2 == @offsetOf(FibreChannelDevicePath, "length"));
            assert(4 == @offsetOf(FibreChannelDevicePath, "reserved"));
            assert(8 == @offsetOf(FibreChannelDevicePath, "world_wide_name"));
            assert(16 == @offsetOf(FibreChannelDevicePath, "logical_unit_number"));
        }

        pub const FibreChannelExDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            reserved: u32 align(1),
            world_wide_name: u64 align(1),
            logical_unit_number: u64 align(1),
        };

        comptime {
            assert(24 == @sizeOf(FibreChannelExDevicePath));
            assert(1 == @alignOf(FibreChannelExDevicePath));

            assert(0 == @offsetOf(FibreChannelExDevicePath, "type"));
            assert(1 == @offsetOf(FibreChannelExDevicePath, "subtype"));
            assert(2 == @offsetOf(FibreChannelExDevicePath, "length"));
            assert(4 == @offsetOf(FibreChannelExDevicePath, "reserved"));
            assert(8 == @offsetOf(FibreChannelExDevicePath, "world_wide_name"));
            assert(16 == @offsetOf(FibreChannelExDevicePath, "logical_unit_number"));
        }

        pub const F1394DevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            reserved: u32 align(1),
            guid: u64 align(1),
        };

        comptime {
            assert(16 == @sizeOf(F1394DevicePath));
            assert(1 == @alignOf(F1394DevicePath));

            assert(0 == @offsetOf(F1394DevicePath, "type"));
            assert(1 == @offsetOf(F1394DevicePath, "subtype"));
            assert(2 == @offsetOf(F1394DevicePath, "length"));
            assert(4 == @offsetOf(F1394DevicePath, "reserved"));
            assert(8 == @offsetOf(F1394DevicePath, "guid"));
        }

        pub const UsbDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            parent_port_number: u8,
            interface_number: u8,
        };

        comptime {
            assert(6 == @sizeOf(UsbDevicePath));
            assert(1 == @alignOf(UsbDevicePath));

            assert(0 == @offsetOf(UsbDevicePath, "type"));
            assert(1 == @offsetOf(UsbDevicePath, "subtype"));
            assert(2 == @offsetOf(UsbDevicePath, "length"));
            assert(4 == @offsetOf(UsbDevicePath, "parent_port_number"));
            assert(5 == @offsetOf(UsbDevicePath, "interface_number"));
        }

        pub const SataDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            hba_port_number: u16 align(1),
            port_multiplier_port_number: u16 align(1),
            logical_unit_number: u16 align(1),
        };

        comptime {
            assert(10 == @sizeOf(SataDevicePath));
            assert(1 == @alignOf(SataDevicePath));

            assert(0 == @offsetOf(SataDevicePath, "type"));
            assert(1 == @offsetOf(SataDevicePath, "subtype"));
            assert(2 == @offsetOf(SataDevicePath, "length"));
            assert(4 == @offsetOf(SataDevicePath, "hba_port_number"));
            assert(6 == @offsetOf(SataDevicePath, "port_multiplier_port_number"));
            assert(8 == @offsetOf(SataDevicePath, "logical_unit_number"));
        }

        pub const UsbWwidDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            interface_number: u16 align(1),
            device_vendor_id: u16 align(1),
            device_product_id: u16 align(1),

            pub fn serial_number(self: *const UsbWwidDevicePath) []align(1) const u16 {
                const serial_len = (self.length - @sizeOf(UsbWwidDevicePath)) / @sizeOf(u16);
                return @as([*]align(1) const u16, @ptrCast(@as([*]const u8, @ptrCast(self)) + @sizeOf(UsbWwidDevicePath)))[0..serial_len];
            }
        };

        comptime {
            assert(10 == @sizeOf(UsbWwidDevicePath));
            assert(1 == @alignOf(UsbWwidDevicePath));

            assert(0 == @offsetOf(UsbWwidDevicePath, "type"));
            assert(1 == @offsetOf(UsbWwidDevicePath, "subtype"));
            assert(2 == @offsetOf(UsbWwidDevicePath, "length"));
            assert(4 == @offsetOf(UsbWwidDevicePath, "interface_number"));
            assert(6 == @offsetOf(UsbWwidDevicePath, "device_vendor_id"));
            assert(8 == @offsetOf(UsbWwidDevicePath, "device_product_id"));
        }

        pub const DeviceLogicalUnitDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            lun: u8,
        };

        comptime {
            assert(5 == @sizeOf(DeviceLogicalUnitDevicePath));
            assert(1 == @alignOf(DeviceLogicalUnitDevicePath));

            assert(0 == @offsetOf(DeviceLogicalUnitDevicePath, "type"));
            assert(1 == @offsetOf(DeviceLogicalUnitDevicePath, "subtype"));
            assert(2 == @offsetOf(DeviceLogicalUnitDevicePath, "length"));
            assert(4 == @offsetOf(DeviceLogicalUnitDevicePath, "lun"));
        }

        pub const UsbClassDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            vendor_id: u16 align(1),
            product_id: u16 align(1),
            device_class: u8,
            device_subclass: u8,
            device_protocol: u8,
        };

        comptime {
            assert(11 == @sizeOf(UsbClassDevicePath));
            assert(1 == @alignOf(UsbClassDevicePath));

            assert(0 == @offsetOf(UsbClassDevicePath, "type"));
            assert(1 == @offsetOf(UsbClassDevicePath, "subtype"));
            assert(2 == @offsetOf(UsbClassDevicePath, "length"));
            assert(4 == @offsetOf(UsbClassDevicePath, "vendor_id"));
            assert(6 == @offsetOf(UsbClassDevicePath, "product_id"));
            assert(8 == @offsetOf(UsbClassDevicePath, "device_class"));
            assert(9 == @offsetOf(UsbClassDevicePath, "device_subclass"));
            assert(10 == @offsetOf(UsbClassDevicePath, "device_protocol"));
        }

        pub const I2oDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            tid: u32 align(1),
        };

        comptime {
            assert(8 == @sizeOf(I2oDevicePath));
            assert(1 == @alignOf(I2oDevicePath));

            assert(0 == @offsetOf(I2oDevicePath, "type"));
            assert(1 == @offsetOf(I2oDevicePath, "subtype"));
            assert(2 == @offsetOf(I2oDevicePath, "length"));
            assert(4 == @offsetOf(I2oDevicePath, "tid"));
        }

        pub const MacAddressDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            mac_address: uefi.MacAddress,
            if_type: u8,
        };

        comptime {
            assert(37 == @sizeOf(MacAddressDevicePath));
            assert(1 == @alignOf(MacAddressDevicePath));

            assert(0 == @offsetOf(MacAddressDevicePath, "type"));
            assert(1 == @offsetOf(MacAddressDevicePath, "subtype"));
            assert(2 == @offsetOf(MacAddressDevicePath, "length"));
            assert(4 == @offsetOf(MacAddressDevicePath, "mac_address"));
            assert(36 == @offsetOf(MacAddressDevicePath, "if_type"));
        }

        pub const Ipv4DevicePath = extern struct {
            pub const IpType = enum(u8) {
                Dhcp = 0,
                Static = 1,
            };

            type: DevicePath.Type,
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
            assert(27 == @sizeOf(Ipv4DevicePath));
            assert(1 == @alignOf(Ipv4DevicePath));

            assert(0 == @offsetOf(Ipv4DevicePath, "type"));
            assert(1 == @offsetOf(Ipv4DevicePath, "subtype"));
            assert(2 == @offsetOf(Ipv4DevicePath, "length"));
            assert(4 == @offsetOf(Ipv4DevicePath, "local_ip_address"));
            assert(8 == @offsetOf(Ipv4DevicePath, "remote_ip_address"));
            assert(12 == @offsetOf(Ipv4DevicePath, "local_port"));
            assert(14 == @offsetOf(Ipv4DevicePath, "remote_port"));
            assert(16 == @offsetOf(Ipv4DevicePath, "network_protocol"));
            assert(18 == @offsetOf(Ipv4DevicePath, "static_ip_address"));
            assert(19 == @offsetOf(Ipv4DevicePath, "gateway_ip_address"));
            assert(23 == @offsetOf(Ipv4DevicePath, "subnet_mask"));
        }

        pub const Ipv6DevicePath = extern struct {
            pub const Origin = enum(u8) {
                Manual = 0,
                AssignedStateless = 1,
                AssignedStateful = 2,
            };

            type: DevicePath.Type,
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
            assert(60 == @sizeOf(Ipv6DevicePath));
            assert(1 == @alignOf(Ipv6DevicePath));

            assert(0 == @offsetOf(Ipv6DevicePath, "type"));
            assert(1 == @offsetOf(Ipv6DevicePath, "subtype"));
            assert(2 == @offsetOf(Ipv6DevicePath, "length"));
            assert(4 == @offsetOf(Ipv6DevicePath, "local_ip_address"));
            assert(20 == @offsetOf(Ipv6DevicePath, "remote_ip_address"));
            assert(36 == @offsetOf(Ipv6DevicePath, "local_port"));
            assert(38 == @offsetOf(Ipv6DevicePath, "remote_port"));
            assert(40 == @offsetOf(Ipv6DevicePath, "protocol"));
            assert(42 == @offsetOf(Ipv6DevicePath, "ip_address_origin"));
            assert(43 == @offsetOf(Ipv6DevicePath, "prefix_length"));
            assert(44 == @offsetOf(Ipv6DevicePath, "gateway_ip_address"));
        }

        pub const VlanDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            vlan_id: u16 align(1),
        };

        comptime {
            assert(6 == @sizeOf(VlanDevicePath));
            assert(1 == @alignOf(VlanDevicePath));

            assert(0 == @offsetOf(VlanDevicePath, "type"));
            assert(1 == @offsetOf(VlanDevicePath, "subtype"));
            assert(2 == @offsetOf(VlanDevicePath, "length"));
            assert(4 == @offsetOf(VlanDevicePath, "vlan_id"));
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

            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            resource_flags: ResourceFlags align(1),
            port_gid: [16]u8,
            service_id: u64 align(1),
            target_port_id: u64 align(1),
            device_id: u64 align(1),
        };

        comptime {
            assert(48 == @sizeOf(InfiniBandDevicePath));
            assert(1 == @alignOf(InfiniBandDevicePath));

            assert(0 == @offsetOf(InfiniBandDevicePath, "type"));
            assert(1 == @offsetOf(InfiniBandDevicePath, "subtype"));
            assert(2 == @offsetOf(InfiniBandDevicePath, "length"));
            assert(4 == @offsetOf(InfiniBandDevicePath, "resource_flags"));
            assert(8 == @offsetOf(InfiniBandDevicePath, "port_gid"));
            assert(24 == @offsetOf(InfiniBandDevicePath, "service_id"));
            assert(32 == @offsetOf(InfiniBandDevicePath, "target_port_id"));
            assert(40 == @offsetOf(InfiniBandDevicePath, "device_id"));
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

        pub const VendorDefinedDevicePath = extern struct {
            type: DevicePath.Type,
            subtype: Subtype,
            length: u16 align(1),
            vendor_guid: Guid align(1),
        };

        comptime {
            assert(20 == @sizeOf(VendorDefinedDevicePath));
            assert(1 == @alignOf(VendorDefinedDevicePath));

            assert(0 == @offsetOf(VendorDefinedDevicePath, "type"));
            assert(1 == @offsetOf(VendorDefinedDevicePath, "subtype"));
            assert(2 == @offsetOf(VendorDefinedDevicePath, "length"));
            assert(4 == @offsetOf(VendorDefinedDevicePath, "vendor_guid"));
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
