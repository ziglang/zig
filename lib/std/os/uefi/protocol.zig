// ** UEFI Specification Version 2.10, August 29, 2022

// 3.2 BootManagerPolicy

// 9. Loaded Image
pub const LoadedImage = @import("protocol/loaded_image.zig").LoadedImage;

// 10. Device Path
pub const DevicePath = @import("protocol/device_path.zig").DevicePath;
// DevicePathUtilities
pub const DevicePathToText = @import("protocol/device_path/path_to_text.zig").PathToText;
// DevicePathFromText

// 12. Console Support
pub const SimpleTextInputEx = @import("protocol/console/simple_text_input_ex.zig").SimpleTextInputEx;
pub const SimpleTextInput = @import("protocol/console/simple_text_input.zig").SimpleTextInput;
pub const SimpleTextOutput = @import("protocol/console/simple_text_output.zig").SimpleTextOutput;
pub const SimplePointer = @import("protocol/console/simple_pointer.zig").SimplePointer;
pub const AbsolutePointer = @import("protocol/console/absolute_pointer.zig").AbsolutePointer;
pub const SerialIo = @import("protocol/console/serial_io.zig").SerialIo;
pub const GraphicsOutput = @import("protocol/console/graphics_output.zig").GraphicsOutput;
pub const edid = @import("protocol/console/edid.zig");

/// 13. Media Access
pub const LoadFile = @import("protocol/media/load_file.zig").LoadFile;
pub const SimpleFileSystem = @import("protocol/media/simple_file_system.zig").SimpleFileSystem;
pub const File = @import("protocol/media/file.zig").File;
// TapeIo
pub const DiskIo = @import("protocol/media/disk_io.zig").DiskIo;
// DiskIo2
pub const BlockIo = @import("protocol/media/block_io.zig").BlockIo;
// BlockIo2
// BlockIoCrypto
// EraseBlock
// AtaPassThrough
// StorageSecurityCommand
// NvmExpressPassThrough
// SdmmcPassThrough
// RamDisk
pub const PartitionInfo = @import("protocol/media/partition_info.zig").PartitionInfo;
// NvdimmLabel
// UfsDeviceConfig

// 14. PCI
// PciRootBridgeIo
// PciIo

// 15. SCSI
// ScsiIo
// ExtendedScsiPassThrough

// 16. iSCSI
// iScsiInitiatorName

// 17. USB
// Usb2HostController
// UsbIo
// UsbFunctionIo

// 18. Debugging
// DebugSupport
// DebugPort

// 19. Compression
// Decompress

// 20. ACPI
// AcpiTable

// 21. String Services
// UnicodeCollation
// RegularExpression

// 22. EFI Byte Code Machine
// EfiByteCode

// 23. Firmware Update and Reporting
// FirmwareManagement

// 24. SNP, PXE, BIS, HTTP
pub const SimpleNetwork = @import("protocol/simple_network.zig").SimpleNetwork;
// NetworkInterfaceIdentifier
// PxeBaseCode
// PxeBaseCodeCallback
// BootIntegrityServices
// HttpBootCallback

// 25. Managed Network
// ManagedNetworkServiceBinding
pub const ManagedNetwork = @import("protocol/managed_network.zig").ManagedNetwork;

// 26. Bluetooth
// BluetoothHostController
// BluetoothIoServiceBinding
// BluetoothIo
// BluetoothConfig
// BluetoothAttribute
// BluetoothAttributeServiceBinding
// BluetoothLeConfig

// 27. VLAN, EAP, WiFi, and Supplicant
// VlanConfig
// Eap
// EapManagement
// EapManagement2
// EapConfiguration
// WirelessMacConnection
// WirelessMacConnection2
// SupplicantServiceBinding
// Supplicant

// 28. TCP, IP, IPSec, FTP, TLS
// Tcp4ServiceBinding
// Tcp4
// Tcp6ServiceBinding
// Tcp6
// Ip4ServiceBinding
// Ip4
// Ip4Config
// Ip4Config2
// pub const Ip6ServiceBinding = @import("protocol/ip6_service_binding.zig").Ip6ServiceBinding;
// pub const Ip6 = @import("protocol/ip6.zig").Ip6;
// pub const Ip6Config = @import("protocol/ip6_config.zig").Ip6Config;
// IpsecConfig
// Ipsec
// Ipsec2
// Ftp4ServiceBinding
// Ftp4
// TlsServiceBinding
// Tls
// TlsConfig

// 29. ARP, DHCP, DNS, HTTP, REST
// ArpServiceBinding
// Arp
// Dhcp4ServiceBinding
// Dhcp4
// Dhcp6ServiceBinding
// Dhcp6
// Dns4ServiceBinding
// Dns4
// Dns6ServiceBinding
// Dns6
// HttpServiceBinding
// Http
// HttpUtilities
// Rest
// RestExServiceBinding
// RestEx
// RestJsonStructure

// 30. UDP, MTFTP
// Udp4ServiceBinding
// Udp4
// pub const Udp6ServiceBinding = @import("protocol/udp6_service_binding.zig").Udp6ServiceBinding;
// pub const Udp6 = @import("protocol/udp6.zig").Udp6;
// Mtftp4ServiceBinding
// Mtftp4
// Mtftp6ServiceBinding
// Mtftp6

// 31. Redfish
// RedfishDiscover

// 32. Secure Boot
// AuthenticationInfo

// 34. HII
// HiiFont
// HiiFontEx
// HiiString
// HiiImage
// HiiImageEx
// HiiImageDecoder
// HiiFontGlyphGenerator
// pub const HiiDatabase = @import("protocol/hii_database.zig").HiiDatabase;

// 35. HII Configuration
// ConfigKeywordHandler
// HiiConfigRouting
// HiiConfigAccess
// FormBrowser2
// pub const HiiPopup = @import("protocol/hii_popup.zig").HiiPopup;

// 36. User Identification
// UserManager
// UserCredential2
// DeferredImageLoad

// 37. Secure Technologies
// HashServiceBinding
// Hash
// Hash2ServiceBinding
// Hash2
// KeyManagementService
// Pkcs7Verify
pub const Rng = @import("protocol/rng.zig").Rng;
// SmartCardReader
// SmartCardEdge
// MemoryAttribute

// 38. Confidential Computing
// ConfidentialComputingMeasurement

// 39. Miscellaneous
// Timestamp
// ResetNotification

// ** EFI Shell Specification Version 2.2, January 26, 2016

// Shell
pub const ShellParameters = @import("protocol/shell_parameters.zig").ShellParameters;
// ShellDynamicCommand

test {
    @setEvalBranchQuota(2000);
    @import("std").testing.refAllDeclsRecursive(@This());
}
