const uefi = @import("std").os.uefi;
const Status = uefi.Status;
const Handle = uefi.bits.Handle;
const Guid = uefi.bits.Guid;
const cc = uefi.bits.cc;

pub const Shell = extern struct {
    execute: *const fn (parent_img_hndl: Handle, cmdline: ?[*:0]const u16, env: ?[*:null]const ?[*:0]const u16, status: *Status) callconv(cc) Status,
    getEnv: *const fn (name: ?[*:0]const u16) callconv(cc) ?[*:0]const u16,
    setEnv: *const fn (name: [*:0]const u16, value: [*:0]const u16, voltlie: bool) callconv(cc) Status,
    getAlias: *const fn (alias: [*:0]const u16, voltlie: *bool) callconv(cc) ?[*:0]const u16,
    setAlias: *const fn (cmd: [*:0]const u16, alias: [*:0]const u16, replace: bool, voltlie: bool) callconv(cc) Status,
    getHelpText: *const fn (cmd: [*:0]const u16, sections: ?[*:0]const u16, helpText: *[*:0]u16) callconv(cc) Status,
    getDevicePathFromMap: *const fn (mapping: [*:0]const u16) callconv(cc) ?*uefi.protocol.DevicePath,
    getMapFromDevicePath: *const fn (devicePath: **const uefi.protocol.DevicePath) callconv(cc) ?[*:0]const u16,
    getDevicePathFromFilePath: *const fn (path: [*:0]const u16) callconv(cc) *uefi.protocol.DevicePath,
    getFilePathFromDevicePath: *const fn (devicePath: *uefi.protocol.DevicePath) callconv(cc) [*:0]const u16,
    setMap: *const fn (devicePath: *uefi.protocol.DevicePath, mapping: [*:0]const u16) callconv(cc) Status,
    getCurDir: *const fn (fsmap: ?[*:0]const u16) callconv(cc) ?[*:0]const u16,
    setCurDir: *const fn (fs: ?[*:0]const u16, dir: [*:0]const u16) callconv(cc) Status,
    openFileList: *const fn (path: [*:0]const u16, openMode: u64, fileList: **FileInfo) callconv(cc) Status,
    freeFileList: *const fn (fileList: **FileInfo) callconv(cc) Status,
    removeDupInFileList: *const fn (fileList: **FileInfo) callconv(cc) Status,
    batchIsActive: *const fn () callconv(cc) bool,
    isRootShell: *const fn () callconv(cc) bool,
    enablePageBreak: *const fn () callconv(cc) void,
    disablePageBreak: *const fn () callconv(cc) void,
    getPageBreak: *const fn () callconv(cc) bool,
    getDeviceName: *const fn (handle: Handle, flags: u32, lang: [*:0]const u8, bestDeviceName: *?[*:0]u16) callconv(cc) Status,
    getFileInfo: *const fn (handle: FileHandle) callconv(cc) ?*uefi.bits.FileInfo,
    setFileInfo: *const fn (handle: FileHandle, info: *const uefi.bits.FileInfo) callconv(cc) Status,
    openFileByName: *const fn (filename: [*:0]const u16, handle: *FileHandle, mode: u64) callconv(cc) Status,
    closeFile: *const fn (handle: FileHandle) callconv(cc) Status,
    createFile: *const fn (filename: [*:0]const u16, attribs: u64, handle: *FileHandle) callconv(cc) Status,
    readFile: *const fn (handle: FileHandle, size: *usize, buff: [*]u8) callconv(cc) Status,
    writeFile: *const fn (handle: FileHandle, size: *usize, buff: [*]const u8) callconv(cc) Status,
    deleteFile: *const fn (handle: FileHandle) callconv(cc) Status,
    deleteFileByName: *const fn (filename: [*:0]const u16) callconv(cc) Status,
    getFilePosition: *const fn (handle: FileHandle, pos: *u64) callconv(cc) Status,
    setFilePosition: *const fn (handle: FileHandle, pos: u64) callconv(cc) Status,
    flushFile: *const fn (handle: FileHandle) callconv(cc) Status,
    findFiles: *const fn (pattern: [*:0]const u16, fileList: *?*FileInfo) callconv(cc) Status,
    findFilesInDir: *const fn (handle: FileHandle, fileList: *?*FileInfo) callconv(cc) Status,
    getFileSize: *const fn (handle: FileHandle, size: *u64) callconv(cc) Status,
    openRoot: *const fn (devicePath: *uefi.protocol.DevicePath, handle: *FileHandle) callconv(cc) Status,
    openRootByHandle: *const fn (deviceHandle: *Handle, fileHandle: *FileHandle) callconv(cc) Status,
    executionBreak: uefi.bits.Event,
    majorVersion: u32,
    minorVersion: u32,

    pub const FileHandle = *opaque {};

    pub const FileInfo = struct {
        link: uefi.ListEntry,
        status: Status,
        fullname: [*:0]const u16,
        filename: [*:0]const u16,
        handle: FileHandle,
        info: *uefi.bits.FileInfo,
    };

    pub const guid align(8) = Guid{
        .time_low = 0x6302d008,
        .time_mid = 0x7f9b,
        .time_high_and_version = 0x4f30,
        .clock_seq_high_and_reserved = 0x87,
        .clock_seq_low = 0xac,
        .node = [_]u8{ 0x60, 0xc9, 0xfe, 0xf5, 0xda, 0x4e },
    };
};
