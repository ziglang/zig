const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;
const Time = uefi.Time;

pub const FileProtocol = extern struct {
    revision: u64,
    _open: extern fn (*const FileProtocol, **const FileProtocol, *u16, u64, u64) usize,
    _close: extern fn (*const FileProtocol) usize,
    _delete: extern fn (*const FileProtocol) usize,
    _read: extern fn (*const FileProtocol, *usize, *c_void) usize,
    _write: extern fn (*const FileProtocol, *usize, *c_void) usize,
    _get_info: extern fn (*const FileProtocol, *Guid, *usize, *c_void) usize,
    _set_info: extern fn (*const FileProtocol, *Guid, usize, *c_void) usize,
    _flush: extern fn (*const FileProtocol) usize,

    pub fn open(self: *const FileProtocol, new_handle: **const FileProtocol, file_name: *u16, open_mode: u64, attributes: u64) usize {
        return self._open(self, new_handle, file_name, open_mode, attributes);
    }

    pub fn close(self: *const FileProtocol) usize {
        return self._close(self);
    }

    pub fn delete(self: *const FileProtocol) usize {
        return self._delete(self);
    }

    pub fn read(self: *const FileProtocol, buffer_size: *usize, buffer: *c_void) usize {
        return self._read(self, buffer_size, buffer);
    }

    pub fn write(self: *const FileProtocol, buffer_size: *usize, buffer: *c_void) usize {
        return self._write(self, buffer_size, buffer);
    }

    pub fn get_info(self: *const FileProtocol, information_type: *Guid, buffer_size: *usize, buffer: *c_void) usize {
        return self._get_info(self, information_type, buffer_size, buffer);
    }

    pub fn set_info(self: *const FileProtocol, information_type: *Guid, buffer_size: usize, buffer: *c_void) usize {
        return self._set_info(self, information_type, buffer_size, buffer);
    }

    pub fn flush(self: *const FileProtocol) usize {
        return self._flush(self);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x09576e92,
        .time_mid = 0x6d3f,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };

    pub const efi_file_mode_read: u64 = 0x0000000000000001;
    pub const efi_file_mode_write: u64 = 0x0000000000000002;
    pub const efi_file_mode_create: u64 = 0x8000000000000000;

    pub const efi_file_read_only: u64 = 0x0000000000000001;
    pub const efi_file_hidden: u64 = 0x0000000000000002;
    pub const efi_file_system: u64 = 0x0000000000000004;
    pub const efi_file_reserved: u64 = 0x0000000000000008;
    pub const efi_file_directory: u64 = 0x0000000000000010;
    pub const efi_file_archive: u64 = 0x0000000000000020;
    pub const efi_file_valid_attr: u64 = 0x0000000000000037;
};

pub const FileInfo = extern struct {
    size: u64,
    file_size: u64,
    physical_size: u64,
    create_time: Time,
    last_access_time: Time,
    modification_time: Time,
    attribute: u64,
    file_name: [100:0]u16,

    pub const efi_file_read_only: u64 = 0x0000000000000001;
    pub const efi_file_hidden: u64 = 0x0000000000000002;
    pub const efi_file_system: u64 = 0x0000000000000004;
    pub const efi_file_reserved: u64 = 0x0000000000000008;
    pub const efi_file_directory: u64 = 0x0000000000000010;
    pub const efi_file_archive: u64 = 0x0000000000000020;
    pub const efi_file_valid_attr: u64 = 0x0000000000000037;
};
