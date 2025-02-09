const testing = @import("std").testing;

const high_bit = 1 << @typeInfo(usize).int.bits - 1;

pub const Status = enum(usize) {
    /// The operation completed successfully.
    success = 0,

    /// The image failed to load.
    load_error = high_bit | 1,

    /// A parameter was incorrect.
    invalid_parameter = high_bit | 2,

    /// The operation is not supported.
    unsupported = high_bit | 3,

    /// The buffer was not the proper size for the request.
    bad_buffer_size = high_bit | 4,

    /// The buffer is not large enough to hold the requested data. The required buffer size is returned in the appropriate parameter when this error occurs.
    buffer_too_small = high_bit | 5,

    /// There is no data pending upon return.
    not_ready = high_bit | 6,

    /// The physical device reported an error while attempting the operation.
    device_error = high_bit | 7,

    /// The device cannot be written to.
    write_protected = high_bit | 8,

    /// A resource has run out.
    out_of_resources = high_bit | 9,

    /// An inconstancy was detected on the file system causing the operating to fail.
    volume_corrupted = high_bit | 10,

    /// There is no more space on the file system.
    volume_full = high_bit | 11,

    /// The device does not contain any medium to perform the operation.
    no_media = high_bit | 12,

    /// The medium in the device has changed since the last access.
    media_changed = high_bit | 13,

    /// The item was not found.
    not_found = high_bit | 14,

    /// Access was denied.
    access_denied = high_bit | 15,

    /// The server was not found or did not respond to the request.
    no_response = high_bit | 16,

    /// A mapping to a device does not exist.
    no_mapping = high_bit | 17,

    /// The timeout time expired.
    timeout = high_bit | 18,

    /// The protocol has not been started.
    not_started = high_bit | 19,

    /// The protocol has already been started.
    already_started = high_bit | 20,

    /// The operation was aborted.
    aborted = high_bit | 21,

    /// An ICMP error occurred during the network operation.
    icmp_error = high_bit | 22,

    /// A TFTP error occurred during the network operation.
    tftp_error = high_bit | 23,

    /// A protocol error occurred during the network operation.
    protocol_error = high_bit | 24,

    /// The function encountered an internal version that was incompatible with a version requested by the caller.
    incompatible_version = high_bit | 25,

    /// The function was not performed due to a security violation.
    security_violation = high_bit | 26,

    /// A CRC error was detected.
    crc_error = high_bit | 27,

    /// Beginning or end of media was reached
    end_of_media = high_bit | 28,

    /// The end of the file was reached.
    end_of_file = high_bit | 31,

    /// The language specified was invalid.
    invalid_language = high_bit | 32,

    /// The security status of the data is unknown or compromised and the data must be updated or replaced to restore a valid security status.
    compromised_data = high_bit | 33,

    /// There is an address conflict address allocation
    ip_address_conflict = high_bit | 34,

    /// A HTTP error occurred during the network operation.
    http_error = high_bit | 35,

    network_unreachable = high_bit | 100,

    host_unreachable = high_bit | 101,

    protocol_unreachable = high_bit | 102,

    port_unreachable = high_bit | 103,

    connection_fin = high_bit | 104,

    connection_reset = high_bit | 105,

    connection_refused = high_bit | 106,

    /// The string contained one or more characters that the device could not render and were skipped.
    warn_unknown_glyph = 1,

    /// The handle was closed, but the file was not deleted.
    warn_delete_failure = 2,

    /// The handle was closed, but the data to the file was not flushed properly.
    warn_write_failure = 3,

    /// The resulting buffer was too small, and the data was truncated to the buffer size.
    warn_buffer_too_small = 4,

    /// The data has not been updated within the timeframe set by localpolicy for this type of data.
    warn_stale_data = 5,

    /// The resulting buffer contains UEFI-compliant file system.
    warn_file_system = 6,

    /// The operation will be processed across a system reset.
    warn_reset_required = 7,

    _,

    pub const Error = error{
        LoadError,
        InvalidParameter,
        Unsupported,
        BadBufferSize,
        BufferTooSmall,
        NotReady,
        DeviceError,
        WriteProtected,
        OutOfResources,
        VolumeCorrupted,
        VolumeFull,
        NoMedia,
        MediaChanged,
        NotFound,
        AccessDenied,
        NoResponse,
        NoMapping,
        Timeout,
        NotStarted,
        AlreadyStarted,
        Aborted,
        IcmpError,
        TftpError,
        ProtocolError,
        IncompatibleVersion,
        SecurityViolation,
        CrcError,
        EndOfMedia,
        EndOfFile,
        InvalidLanguage,
        CompromisedData,
        IpAddressConflict,
        HttpError,
        NetworkUnreachable,
        HostUnreachable,
        ProtocolUnreachable,
        PortUnreachable,
        ConnectionFin,
        ConnectionReset,
        ConnectionRefused,
    };

    pub fn err(self: Status) Error!void {
        switch (self) {
            .load_error => return error.LoadError,
            .invalid_parameter => return error.InvalidParameter,
            .unsupported => return error.Unsupported,
            .bad_buffer_size => return error.BadBufferSize,
            .buffer_too_small => return error.BufferTooSmall,
            .not_ready => return error.NotReady,
            .device_error => return error.DeviceError,
            .write_protected => return error.WriteProtected,
            .out_of_resources => return error.OutOfResources,
            .volume_corrupted => return error.VolumeCorrupted,
            .volume_full => return error.VolumeFull,
            .no_media => return error.NoMedia,
            .media_changed => return error.MediaChanged,
            .not_found => return error.NotFound,
            .access_denied => return error.AccessDenied,
            .no_response => return error.NoResponse,
            .no_mapping => return error.NoMapping,
            .timeout => return error.Timeout,
            .not_started => return error.NotStarted,
            .already_started => return error.AlreadyStarted,
            .aborted => return error.Aborted,
            .icmp_error => return error.IcmpError,
            .tftp_error => return error.TftpError,
            .protocol_error => return error.ProtocolError,
            .incompatible_version => return error.IncompatibleVersion,
            .security_violation => return error.SecurityViolation,
            .crc_error => return error.CrcError,
            .end_of_media => return error.EndOfMedia,
            .end_of_file => return error.EndOfFile,
            .invalid_language => return error.InvalidLanguage,
            .compromised_data => return error.CompromisedData,
            .ip_address_conflict => return error.IpAddressConflict,
            .http_error => return error.HttpError,
            .network_unreachable => return error.NetworkUnreachable,
            .host_unreachable => return error.HostUnreachable,
            .protocol_unreachable => return error.ProtocolUnreachable,
            .port_unreachable => return error.PortUnreachable,
            .connection_fin => return error.ConnectionFin,
            .connection_reset => return error.ConnectionReset,
            .connection_refused => return error.ConnectionRefused,
            // success, warn_*, _
            else => {},
        }
    }
};

test "status" {
    var st: Status = .device_error;
    try testing.expectError(error.DeviceError, st.err());

    st = .success;
    try st.err();

    st = .warn_unknown_glyph;
    try st.err();
}
