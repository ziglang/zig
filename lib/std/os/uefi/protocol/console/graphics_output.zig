const std = @import("../../../../std.zig");
const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;

/// Provides a basic abstraction to set video modes and copy pixels to and from the graphics controller’s frame
/// buffer. The linear address of the hardware frame buffer is also exposed so software can write directly to the
/// video hardware.
pub const GraphicsOutput = extern struct {
    _query_mode: *const fn (*const GraphicsOutput, mode: u32, *usize, info: **const Mode.Info) callconv(cc) Status,
    _set_mode: *const fn (*const GraphicsOutput, mode: u32) callconv(cc) Status,
    _blt: *const fn (*const GraphicsOutput, buffer: ?[*]BltPixel, op: BltOperation, sx: usize, sy: usize, dx: usize, dy: usize, w: usize, h: usize, delta: usize) callconv(cc) Status,
    mode: *const Mode,

    pub const Mode = extern struct {
        /// The number of valid modes supported by `setMode()` and `queryMode()`.
        ///
        /// This will be one higher than the highest mode number supported.
        max_mode: u32,

        /// Current mode of the graphics device.
        mode: u32,

        /// Pointer to this mode's mode information structure.
        info: *const Info,

        /// Size of the info structure in bytes. This size may be increased in future revisions.
        size_of_info: usize,

        /// Base address of graphics linear frame buffer. This field is only valid if the pixel mode is not `.blt_only`.
        frame_buffer_base: bits.PhysicalAddress,

        /// The size in bytes of the graphics linear frame buffer. This is defined as
        /// `pixels_per_scan_line` * vertical_resolution * pixelElementSize()`.
        frame_buffer_size: usize,

        pub const Info = extern struct {
            /// The version of this data structure. A value of zero represents the this structure. Future version of
            /// this specification may extend this data structure in a backwards compatible way and increase the
            /// value of Version.
            version: u32 = 0,

            /// The size of video screen in pixels in the X dimension.
            horizontal_resolution: u32,

            /// The size of video screen in pixels in the Y dimension.
            vertical_resolution: u32,

            /// The physical format of the pixel.
            pixel_format: PixelFormat,

            /// When format is `.bitmask`, this field defines the mask of each color channel.
            pixel_bitmask: PixelBitmask,

            /// The number of pixel elements per video memory line. This value must be used instead of
            /// `horizontal_resolution` to calculate the offset to the next line.
            pixels_per_scan_line: u32,

            /// The size of a pixel element in bytes.
            pub fn pixelElementSize(self: *const Info) usize {
                switch (self.pixel_format) {
                    .rgb_8bit => return 4,
                    .bgr_8bit => return 4,
                    .bitmask => return @divExact(self.pixel_bitmask.bitSizeOf(), 8),
                    .blt_only => return 0,
                }
            }
        };

        /// Writes a single pixel into the linear framebuffer.
        pub fn setPixel(
            self: *const Mode,
            /// The X coordinate of the pixel.
            x: usize,
            /// The Y coordinate of the pixel.
            y: usize,
            /// The red channel of the pixel.
            red: u8,
            /// The green channel of the pixel.
            green: u8,
            /// The blue channel of the pixel.
            blue: u8,
        ) !void {
            const addr = self.frame_buffer_base + (y * self.info.pixels_per_scan_line + x) * self.info.pixelElementSize();

            const pixel: *[4]u8 = @ptrFromInt(addr);

            switch (self.info.pixel_format) {
                .rgb_8bit => {
                    pixel[0] = red;
                    pixel[1] = green;
                    pixel[2] = blue;
                },
                .bgr_8bit => {
                    pixel[0] = blue;
                    pixel[1] = green;
                    pixel[2] = red;
                },
                .bitmask => {
                    const pixel_u32: *align(1) u32 = @ptrCast(pixel);

                    const red_value = self.info.pixel_bitmask.toValue(.red, red);
                    const green_value = self.info.pixel_bitmask.toValue(.green, green);
                    const blue_value = self.info.pixel_bitmask.toValue(.blue, blue);

                    pixel_u32.* = red_value | green_value | blue_value;
                },
                .blt_only => unreachable,
            }
        }
    };

    pub const PixelFormat = enum(u32) {
        /// A pixel is 32 bits, byte zero represents red, byte one represents green, byte two represents blue, and
        /// byte three is reserved. The values range from the minimum intensity of 0 to maximum intensity of 255.
        rgb_8bit,

        /// A pixel is 32 bits, byte zero represents blue, byte one represents green, byte two represents red, and
        /// byte three is reserved. The values range from the minimum intensity of 0 to maximum intensity of 255.
        bgr_8bit,

        /// The pixel format is defined by the `PixelBitmask` structure.
        bitmask,

        /// This mode does not support a physical framebuffer.
        blt_only,
    };

    pub const PixelBitmask = extern struct {
        red: u32,
        green: u32,
        blue: u32,
        reserved: u32,

        pub const PixelField = enum {
            red,
            green,
            blue,
            reserved,
        };

        /// Finds the size in bits of a single pixel.
        pub fn bitSizeOf(self: *const PixelBitmask) u5 {
            const highest_red_bit = 32 - @clz(self.red);
            const highest_green_bit = 32 - @clz(self.green);
            const highest_blue_bit = 32 - @clz(self.blue);
            const highest_reserved_bit = 32 - @clz(self.reserved);

            return @intCast(@max(@max(highest_red_bit, highest_green_bit), @max(highest_blue_bit, highest_reserved_bit)));
        }

        /// Finds the size in bits of a pixel field.
        pub inline fn bitSizeOfField(self: *const PixelBitmask, comptime field: PixelField) u5 {
            switch (field) {
                .red => return @intCast(@popCount(self.red)),
                .green => return @intCast(@popCount(self.green)),
                .blue => return @intCast(@popCount(self.blue)),
                .reserved => return @intCast(@popCount(self.reserved)),
            }
        }

        /// Finds the offset from zero (ie. a shift) in bits of a pixel field.
        pub inline fn bitOffsetOfField(self: *const PixelBitmask, comptime field: PixelField) u5 {
            switch (field) {
                .red => return @intCast(@ctz(self.red)),
                .green => return @intCast(@ctz(self.green)),
                .blue => return @intCast(@ctz(self.blue)),
                .reserved => return @intCast(@ctz(self.reserved)),
            }
        }

        /// Returns the bit mask of a pixel field.
        pub inline fn bitMaskOfField(self: *const PixelBitmask, comptime field: PixelField) u32 {
            switch (field) {
                .red => return self.red,
                .green => return self.green,
                .blue => return self.blue,
                .reserved => return self.reserved,
            }
        }

        /// Pulls the value of a pixel field out of a pixel.
        pub fn getValue(self: *const PixelBitmask, comptime field: PixelField, pixel_ptr: [*]const u8) u32 {
            const pixel: *align(1) const u32 = @ptrCast(pixel_ptr);

            return (pixel.* & self.bitMaskOfField(field)) >> self.bitOffsetOfField(field);
        }

        /// Returns the value of a pixel field shifted and saturated to the correct position for the pixel.
        pub fn toValue(self: *const PixelBitmask, comptime field: PixelField, value: u8) u32 {
            const max_field_value: u32 = @as(u32, 1) << self.bitSizeOfField(field);

            const value_saturated: u32 = @min(value, max_field_value);
            const value_shifted = value_saturated << self.bitOffsetOfField(field);
            return value_shifted & self.bitMaskOfField(field);
        }
    };

    /// Returns information for an available graphics mode that the graphics device and the set of active video
    /// output devices supports.
    pub fn queryMode(self: *const GraphicsOutput, mode: u32) !*const Mode.Info {
        var size: usize = undefined;
        var info: *const Mode.Info = undefined;
        try self._query_mode(self, mode, &size, &info).err();

        if (size < @sizeOf(Mode.Info)) return error.Unsupported;
        return info;
    }

    /// Set the video device into the specified mode and clears the visible portions of the output display to black.
    pub fn setMode(self: *const GraphicsOutput, mode: u32) !void {
        try self._set_mode(self, mode).err();
    }

    pub const BltPixel = extern struct {
        blue: u8,
        green: u8,
        red: u8,
        reserved: u8 = 0,
    };

    pub const BltOperation = enum(u32) {
        /// Write data from the `blt_buffer` pixel (0, 0) directly to every pixel of the video display rectangle
        /// (`destination_x`, `destination_y`) (`destination_x + width`, `destination_y + height`). Only one pixel
        /// will be used from the `blt_buffer`. `delta` is NOT used.
        video_fill,

        /// Read data from the video display rectangle (`source_x`, `source_y`) (`source_x + width`, `source_y + height`)
        /// and place it in the `blt_buffer` rectangle (`destination_x`, `destination_y`) (`destination_x + width`,
        /// `destination_y + height`). If `destination_x` or `destination_y` is not zero then `delta` must be set to
        /// the length in bytes of a row in the `blt_buffer`.
        video_to_blt_buffer,

        /// Write data from the `blt_buffer` rectangle (`source_x`, `source_x`) (`source_x + width`, `source_y + height`)
        /// directly to the video display rectangle (`destination_x`, `destination_y`) (`destination_x + width`,
        /// `destination_y + height`). If `source_x` or `source_x` is not zero then `delta` must be set to the length
        /// in bytes of a row in the `blt_buffer`.
        blt_buffer_to_video,

        /// Copy from the video display rectangle (`source_x`, `source_y`) (`source_x + width`, `source_y + height`)
        /// to the video display rectangle (`destination_x`, `destination_y`) (`destination_x + width`,
        /// `destination_y + height`. The `blt_buffer` and `delta` are not used in this mode. There is no limitation
        /// on the overlapping of the source and destination rectangles
        video_to_video,
    };

    /// Blt a rectangle of pixels on the graphics screen. Blt stands for BLock Transfer.
    pub fn blt(
        self: *const GraphicsOutput,
        /// The data to transfer to the graphics screen. Must be at least `width * height`.
        blt_buffer: ?[*]BltPixel,
        /// The operation to perform.
        blt_operation: BltOperation,
        /// The X coordinate of the source for the `blt_operation`. The origin of the screen is 0, 0 and that is the
        /// upper left-hand corner of the screen
        source_x: usize,
        /// The Y coordinate of the source for the `blt_operation`. The origin of the screen is 0, 0 and that is the
        /// upper left-hand corner of the screen.
        source_y: usize,
        /// The X coordinate of the destination for the `blt_operation`. The origin of the screen is 0, 0 and that is
        /// the upper left-hand corner of the screen.
        destination_x: usize,
        /// The Y coordinate of the destination for the `blt_operation`. The origin of the screen is 0, 0 and that is
        /// the upper left-hand corner of the screen.
        destination_y: usize,
        /// The width of a rectangle in the blt rectangle in pixels.
        width: usize,
        /// The height of a rectangle in the blt rectangle in pixels.
        height: usize,
        /// Not used for `.video_fill` or the `.video_to_video` operation. If a `delta` of zero is used, the entire
        /// `blt_buffer` is being operated on. If a subrectangle of the `blt_buffer` is being used then `delta`
        /// represents the number of bytes in a row of the `blt_buffer`.
        delta: usize,
    ) !void {
        try self._blt(self, blt_buffer, blt_operation, source_x, source_y, destination_x, destination_y, width, height, delta).err();
    }

    pub const guid align(8) = Guid{
        .time_low = 0x9042a9de,
        .time_mid = 0x23dc,
        .time_high_and_version = 0x4a38,
        .clock_seq_high_and_reserved = 0x96,
        .clock_seq_low = 0xfb,
        .node = [_]u8{ 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a },
    };
};
