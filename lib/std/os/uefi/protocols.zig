// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub const LoadedImageProtocol = @import("protocols/loaded_image_protocol.zig").LoadedImageProtocol;
pub const loaded_image_device_path_protocol_guid = @import("protocols/loaded_image_protocol.zig").loaded_image_device_path_protocol_guid;

pub const AcpiDevicePath = @import("protocols/device_path_protocol.zig").AcpiDevicePath;
pub const BiosBootSpecificationDevicePath = @import("protocols/device_path_protocol.zig").BiosBootSpecificationDevicePath;
pub const DevicePath = @import("protocols/device_path_protocol.zig").DevicePath;
pub const DevicePathProtocol = @import("protocols/device_path_protocol.zig").DevicePathProtocol;
pub const DevicePathType = @import("protocols/device_path_protocol.zig").DevicePathType;
pub const EndDevicePath = @import("protocols/device_path_protocol.zig").EndDevicePath;
pub const HardwareDevicePath = @import("protocols/device_path_protocol.zig").HardwareDevicePath;
pub const MediaDevicePath = @import("protocols/device_path_protocol.zig").MediaDevicePath;
pub const MessagingDevicePath = @import("protocols/device_path_protocol.zig").MessagingDevicePath;

pub const SimpleFileSystemProtocol = @import("protocols/simple_file_system_protocol.zig").SimpleFileSystemProtocol;
pub const FileProtocol = @import("protocols/file_protocol.zig").FileProtocol;
pub const FileInfo = @import("protocols/file_protocol.zig").FileInfo;

pub const InputKey = @import("protocols/simple_text_input_ex_protocol.zig").InputKey;
pub const KeyData = @import("protocols/simple_text_input_ex_protocol.zig").KeyData;
pub const KeyState = @import("protocols/simple_text_input_ex_protocol.zig").KeyState;
pub const SimpleTextInputProtocol = @import("protocols/simple_text_input_protocol.zig").SimpleTextInputProtocol;
pub const SimpleTextInputExProtocol = @import("protocols/simple_text_input_ex_protocol.zig").SimpleTextInputExProtocol;

pub const SimpleTextOutputMode = @import("protocols/simple_text_output_protocol.zig").SimpleTextOutputMode;
pub const SimpleTextOutputProtocol = @import("protocols/simple_text_output_protocol.zig").SimpleTextOutputProtocol;

pub const SimplePointerMode = @import("protocols/simple_pointer_protocol.zig").SimplePointerMode;
pub const SimplePointerProtocol = @import("protocols/simple_pointer_protocol.zig").SimplePointerProtocol;
pub const SimplePointerState = @import("protocols/simple_pointer_protocol.zig").SimplePointerState;

pub const AbsolutePointerMode = @import("protocols/absolute_pointer_protocol.zig").AbsolutePointerMode;
pub const AbsolutePointerProtocol = @import("protocols/absolute_pointer_protocol.zig").AbsolutePointerProtocol;
pub const AbsolutePointerState = @import("protocols/absolute_pointer_protocol.zig").AbsolutePointerState;

pub const GraphicsOutputBltPixel = @import("protocols/graphics_output_protocol.zig").GraphicsOutputBltPixel;
pub const GraphicsOutputBltOperation = @import("protocols/graphics_output_protocol.zig").GraphicsOutputBltOperation;
pub const GraphicsOutputModeInformation = @import("protocols/graphics_output_protocol.zig").GraphicsOutputModeInformation;
pub const GraphicsOutputProtocol = @import("protocols/graphics_output_protocol.zig").GraphicsOutputProtocol;
pub const GraphicsOutputProtocolMode = @import("protocols/graphics_output_protocol.zig").GraphicsOutputProtocolMode;
pub const GraphicsPixelFormat = @import("protocols/graphics_output_protocol.zig").GraphicsPixelFormat;
pub const PixelBitmask = @import("protocols/graphics_output_protocol.zig").PixelBitmask;

pub const EdidDiscoveredProtocol = @import("protocols/edid_discovered_protocol.zig").EdidDiscoveredProtocol;

pub const EdidActiveProtocol = @import("protocols/edid_active_protocol.zig").EdidActiveProtocol;

pub const EdidOverrideProtocol = @import("protocols/edid_override_protocol.zig").EdidOverrideProtocol;
pub const EdidOverrideProtocolAttributes = @import("protocols/edid_override_protocol.zig").EdidOverrideProtocolAttributes;

pub const SimpleNetworkProtocol = @import("protocols/simple_network_protocol.zig").SimpleNetworkProtocol;
pub const MacAddress = @import("protocols/simple_network_protocol.zig").MacAddress;
pub const SimpleNetworkMode = @import("protocols/simple_network_protocol.zig").SimpleNetworkMode;
pub const SimpleNetworkReceiveFilter = @import("protocols/simple_network_protocol.zig").SimpleNetworkReceiveFilter;
pub const SimpleNetworkState = @import("protocols/simple_network_protocol.zig").SimpleNetworkState;
pub const NetworkStatistics = @import("protocols/simple_network_protocol.zig").NetworkStatistics;
pub const SimpleNetworkInterruptStatus = @import("protocols/simple_network_protocol.zig").SimpleNetworkInterruptStatus;

pub const ManagedNetworkServiceBindingProtocol = @import("protocols/managed_network_service_binding_protocol.zig").ManagedNetworkServiceBindingProtocol;
pub const ManagedNetworkProtocol = @import("protocols/managed_network_protocol.zig").ManagedNetworkProtocol;
pub const ManagedNetworkConfigData = @import("protocols/managed_network_protocol.zig").ManagedNetworkConfigData;
pub const ManagedNetworkCompletionToken = @import("protocols/managed_network_protocol.zig").ManagedNetworkCompletionToken;
pub const ManagedNetworkReceiveData = @import("protocols/managed_network_protocol.zig").ManagedNetworkReceiveData;
pub const ManagedNetworkTransmitData = @import("protocols/managed_network_protocol.zig").ManagedNetworkTransmitData;
pub const ManagedNetworkFragmentData = @import("protocols/managed_network_protocol.zig").ManagedNetworkFragmentData;

pub const Ip6ServiceBindingProtocol = @import("protocols/ip6_service_binding_protocol.zig").Ip6ServiceBindingProtocol;
pub const Ip6Protocol = @import("protocols/ip6_protocol.zig").Ip6Protocol;
pub const Ip6ModeData = @import("protocols/ip6_protocol.zig").Ip6ModeData;
pub const Ip6ConfigData = @import("protocols/ip6_protocol.zig").Ip6ConfigData;
pub const Ip6Address = @import("protocols/ip6_protocol.zig").Ip6Address;
pub const Ip6AddressInfo = @import("protocols/ip6_protocol.zig").Ip6AddressInfo;
pub const Ip6RouteTable = @import("protocols/ip6_protocol.zig").Ip6RouteTable;
pub const Ip6NeighborState = @import("protocols/ip6_protocol.zig").Ip6NeighborState;
pub const Ip6NeighborCache = @import("protocols/ip6_protocol.zig").Ip6NeighborCache;
pub const Ip6IcmpType = @import("protocols/ip6_protocol.zig").Ip6IcmpType;
pub const Ip6CompletionToken = @import("protocols/ip6_protocol.zig").Ip6CompletionToken;

pub const Ip6ConfigProtocol = @import("protocols/ip6_config_protocol.zig").Ip6ConfigProtocol;
pub const Ip6ConfigDataType = @import("protocols/ip6_config_protocol.zig").Ip6ConfigDataType;

pub const Udp6ServiceBindingProtocol = @import("protocols/udp6_service_binding_protocol.zig").Udp6ServiceBindingProtocol;
pub const Udp6Protocol = @import("protocols/udp6_protocol.zig").Udp6Protocol;
pub const Udp6ConfigData = @import("protocols/udp6_protocol.zig").Udp6ConfigData;
pub const Udp6CompletionToken = @import("protocols/udp6_protocol.zig").Udp6CompletionToken;
pub const Udp6ReceiveData = @import("protocols/udp6_protocol.zig").Udp6ReceiveData;
pub const Udp6TransmitData = @import("protocols/udp6_protocol.zig").Udp6TransmitData;
pub const Udp6SessionData = @import("protocols/udp6_protocol.zig").Udp6SessionData;
pub const Udp6FragmentData = @import("protocols/udp6_protocol.zig").Udp6FragmentData;

pub const hii = @import("protocols/hii.zig");
pub const HIIDatabaseProtocol = @import("protocols/hii_database_protocol.zig").HIIDatabaseProtocol;
pub const HIIPopupProtocol = @import("protocols/hii_popup_protocol.zig").HIIPopupProtocol;
pub const HIIPopupStyle = @import("protocols/hii_popup_protocol.zig").HIIPopupStyle;
pub const HIIPopupType = @import("protocols/hii_popup_protocol.zig").HIIPopupType;
pub const HIIPopupSelection = @import("protocols/hii_popup_protocol.zig").HIIPopupSelection;

pub const RNGProtocol = @import("protocols/rng_protocol.zig").RNGProtocol;

pub const ShellParametersProtocol = @import("protocols/shell_parameters_protocol.zig").ShellParametersProtocol;
