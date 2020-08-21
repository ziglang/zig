// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const high_bit = 1 << @typeInfo(usize).Int.bits - 1;

pub const Status = extern enum(usize) {
    /// The operation completed successfully.
    Success = 0,

    /// The image failed to load.
    LoadError = high_bit | 1,

    /// A parameter was incorrect.
    InvalidParameter = high_bit | 2,

    /// The operation is not supported.
    Unsupported = high_bit | 3,

    /// The buffer was not the proper size for the request.
    BadBufferSize = high_bit | 4,

    /// The buffer is not large enough to hold the requested data. The required buffer size is returned in the appropriate parameter when this error occurs.
    BufferTooSmall = high_bit | 5,

    /// There is no data pending upon return.
    NotReady = high_bit | 6,

    /// The physical device reported an error while attempting the operation.
    DeviceError = high_bit | 7,

    /// The device cannot be written to.
    WriteProtected = high_bit | 8,

    /// A resource has run out.
    OutOfResources = high_bit | 9,

    /// An inconstancy was detected on the file system causing the operating to fail.
    VolumeCorrupted = high_bit | 10,

    /// There is no more space on the file system.
    VolumeFull = high_bit | 11,

    /// The device does not contain any medium to perform the operation.
    NoMedia = high_bit | 12,

    /// The medium in the device has changed since the last access.
    MediaChanged = high_bit | 13,

    /// The item was not found.
    NotFound = high_bit | 14,

    /// Access was denied.
    AccessDenied = high_bit | 15,

    /// The server was not found or did not respond to the request.
    NoResponse = high_bit | 16,

    /// A mapping to a device does not exist.
    NoMapping = high_bit | 17,

    /// The timeout time expired.
    Timeout = high_bit | 18,

    /// The protocol has not been started.
    NotStarted = high_bit | 19,

    /// The protocol has already been started.
    AlreadyStarted = high_bit | 20,

    /// The operation was aborted.
    Aborted = high_bit | 21,

    /// An ICMP error occurred during the network operation.
    IcmpError = high_bit | 22,

    /// A TFTP error occurred during the network operation.
    TftpError = high_bit | 23,

    /// A protocol error occurred during the network operation.
    ProtocolError = high_bit | 24,

    /// The function encountered an internal version that was incompatible with a version requested by the caller.
    IncompatibleVersion = high_bit | 25,

    /// The function was not performed due to a security violation.
    SecurityViolation = high_bit | 26,

    /// A CRC error was detected.
    CrcError = high_bit | 27,

    /// Beginning or end of media was reached
    EndOfMedia = high_bit | 28,

    /// The end of the file was reached.
    EndOfFile = high_bit | 31,

    /// The language specified was invalid.
    InvalidLanguage = high_bit | 32,

    /// The security status of the data is unknown or compromised and the data must be updated or replaced to restore a valid security status.
    CompromisedData = high_bit | 33,

    /// There is an address conflict address allocation
    IpAddressConflict = high_bit | 34,

    /// A HTTP error occurred during the network operation.
    HttpError = high_bit | 35,

    NetworkUnreachable = high_bit | 100,

    HostUnreachable = high_bit | 101,

    ProtocolUnreachable = high_bit | 102,

    PortUnreachable = high_bit | 103,

    ConnectionFin = high_bit | 104,

    ConnectionReset = high_bit | 105,

    ConnectionRefused = high_bit | 106,

    /// The string contained one or more characters that the device could not render and were skipped.
    WarnUnknownGlyph = 1,

    /// The handle was closed, but the file was not deleted.
    WarnDeleteFailure = 2,

    /// The handle was closed, but the data to the file was not flushed properly.
    WarnWriteFailure = 3,

    /// The resulting buffer was too small, and the data was truncated to the buffer size.
    WarnBufferTooSmall = 4,

    /// The data has not been updated within the timeframe set by localpolicy for this type of data.
    WarnStaleData = 5,

    /// The resulting buffer contains UEFI-compliant file system.
    WarnFileSystem = 6,

    /// The operation will be processed across a system reset.
    WarnResetRequired = 7,

    _,
};
