const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;

pub const GraphicsOutput = extern struct {
    _query_mode: *const fn (*const GraphicsOutput, u32, *usize, **Mode.Info) callconv(cc) Status,
    _set_mode: *const fn (*const GraphicsOutput, u32) callconv(cc) Status,
    _blt: *const fn (*const GraphicsOutput, ?[*]BltPixel, BltOperation, usize, usize, usize, usize, usize, usize, usize) callconv(cc) Status,
    mode: *Mode,

    /// Returns information for an available graphics mode that the graphics device and the set of active video output devices supports.
    pub fn queryMode(self: *const GraphicsOutput, mode: u32, size_of_info: *usize, info: **Mode.Info) Status {
        return self._query_mode(self, mode, size_of_info, info);
    }

    /// Set the video device into the specified mode and clears the visible portions of the output display to black.
    pub fn setMode(self: *const GraphicsOutput, mode: u32) Status {
        return self._set_mode(self, mode);
    }

    /// Blt a rectangle of pixels on the graphics screen. Blt stands for BLock Transfer.
    pub fn blt(self: *const GraphicsOutput, blt_buffer: ?[*]BltPixel, blt_operation: BltOperation, source_x: usize, source_y: usize, destination_x: usize, destination_y: usize, width: usize, height: usize, delta: usize) Status {
        return self._blt(self, blt_buffer, blt_operation, source_x, source_y, destination_x, destination_y, width, height, delta);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x9042a9de,
        .time_mid = 0x23dc,
        .time_high_and_version = 0x4a38,
        .clock_seq_high_and_reserved = 0x96,
        .clock_seq_low = 0xfb,
        .node = [_]u8{ 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a },
    };

    pub const Mode = extern struct {
        max_mode: u32,
        mode: u32,
        info: *Info,
        size_of_info: usize,
        frame_buffer_base: u64,
        frame_buffer_size: usize,

        pub const Info = extern struct {
            version: u32,
            horizontal_resolution: u32,
            vertical_resolution: u32,
            pixel_format: PixelFormat,
            pixel_information: PixelBitmask,
            pixels_per_scan_line: u32,
        };
    };

    pub const PixelFormat = enum(u32) {
        red_green_blue_reserved_8_bit_per_color,
        blue_green_red_reserved_8_bit_per_color,
        bit_mask,
        blt_only,
    };

    pub const PixelBitmask = extern struct {
        red_mask: u32,
        green_mask: u32,
        blue_mask: u32,
        reserved_mask: u32,
    };

    pub const BltPixel = extern struct {
        blue: u8,
        green: u8,
        red: u8,
        reserved: u8 = undefined,
    };

    pub const BltOperation = enum(u32) {
        blt_video_fill,
        blt_video_to_blt_buffer,
        blt_buffer_to_video,
        blt_video_to_video,
        graphics_output_blt_operation_max,
    };
};
