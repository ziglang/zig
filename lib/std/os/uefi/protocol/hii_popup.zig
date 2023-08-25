const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;
const hii = uefi.hii;
const cc = uefi.cc;

/// Display a popup window
pub const HiiPopup = extern struct {
    revision: u64,
    _create_popup: *const fn (*const HiiPopup, PopupStyle, PopupType, hii.Handle, u16, ?*PopupSelection) callconv(cc) Status,

    /// Displays a popup window.
    pub fn createPopup(self: *const HiiPopup, style: PopupStyle, popup_type: PopupType, handle: hii.Handle, msg: u16, user_selection: ?*PopupSelection) Status {
        return self._create_popup(self, style, popup_type, handle, msg, user_selection);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x4311edc0,
        .time_mid = 0x6054,
        .time_high_and_version = 0x46d4,
        .clock_seq_high_and_reserved = 0x9e,
        .clock_seq_low = 0x40,
        .node = [_]u8{ 0x89, 0x3e, 0xa9, 0x52, 0xfc, 0xcc },
    };

    pub const PopupStyle = enum(u32) {
        Info,
        Warning,
        Error,
    };

    pub const PopupType = enum(u32) {
        Ok,
        Cancel,
        YesNo,
        YesNoCancel,
    };

    pub const PopupSelection = enum(u32) {
        Ok,
        Cancel,
        Yes,
        No,
    };
};
