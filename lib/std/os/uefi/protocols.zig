pub const InputKey = @import("protocols/simple_text_input_ex_protocol.zig").InputKey;
pub const KeyData = @import("protocols/simple_text_input_ex_protocol.zig").KeyData;
pub const KeyState = @import("protocols/simple_text_input_ex_protocol.zig").KeyState;
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

pub const hii = @import("protocols/hii.zig");
pub const HIIDatabaseProtocol = @import("protocols/hii_database_protocol.zig").HIIDatabaseProtocol;
pub const HIIPopupProtocol = @import("protocols/hii_popup_protocol.zig").HIIPopupProtocol;
pub const HIIPopupStyle = @import("protocols/hii_popup_protocol.zig").HIIPopupStyle;
pub const HIIPopupType = @import("protocols/hii_popup_protocol.zig").HIIPopupType;
pub const HIIPopupSelection = @import("protocols/hii_popup_protocol.zig").HIIPopupSelection;

pub const RNGProtocol = @import("protocols/rng_protocol.zig").RNGProtocol;
