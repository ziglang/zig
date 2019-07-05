pub const SocketError = error{
    /// Permission to create a socket of the specified type and/or
    /// protocol is denied.
    PermissionDenied,

    /// The implementation does not support the specified address family.
    AddressFamilyNotSupported,

    /// Unknown protocol, or protocol family not available.
    ProtocolFamilyNotAvailable,

    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// Insufficient memory is available. The socket cannot be created until sufficient
    /// resources are freed.
    SystemResources,

    /// The protocol type or the specified protocol is not supported within this domain.
    ProtocolNotSupported,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub const BindError = error{
    /// The address is protected, and the user is not the superuser.
    /// For UNIX domain sockets: Search permission is denied on  a  component
    /// of  the  path  prefix.
    AccessDenied,

    /// The given address is already in use, or in the case of Internet domain sockets,
    /// The  port number was specified as zero in the socket
    /// address structure, but, upon attempting to bind to  an  ephemeral  port,  it  was
    /// determined  that  all  port  numbers in the ephemeral port range are currently in
    /// use.
    AddressInUse,

    /// A nonexistent interface was requested or the requested address was not local.
    AddressNotAvailable,

    /// Too many symbolic links were encountered in resolving addr.
    SymLinkLoop,

    /// addr is too long.
    NameTooLong,

    /// A component in the directory prefix of the socket pathname does not exist.
    FileNotFound,

    /// Insufficient kernel memory was available.
    SystemResources,

    /// A component of the path prefix is not a directory.
    NotDir,

    /// The socket inode would reside on a read-only filesystem.
    ReadOnlyFileSystem,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub const ListenError = error{
    /// Another socket is already listening on the same port.
    /// For Internet domain sockets, the  socket referred to by socket had not previously
    /// been bound to an address and, upon attempting to bind it to an ephemeral port, it
    /// was determined that all port numbers in the ephemeral port range are currently in
    /// use.
    AddressInUse,

    /// The file descriptor socket does not refer to a socket.
    FileDescriptorNotASocket,

    /// The socket is not of a type that supports the listen() operation.
    OperationNotSupported,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub const AcceptError = error{
    ConnectionAborted,

    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// Not enough free memory.  This often means that the memory allocation  is  limited
    /// by the socket buffer limits, not by the system memory.
    SystemResources,

    /// The file descriptor socket does not refer to a socket.
    FileDescriptorNotASocket,

    /// The referenced socket is not of type SOCK_STREAM.
    OperationNotSupported,

    ProtocolFailure,

    /// Firewall rules forbid connection.
    BlockedByFirewall,

    /// Accepting would block.
    WouldBlock,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub const ConnectError = error{
    /// For UNIX domain sockets, which are identified by pathname: Write permission is denied on the socket
    /// file, or search permission is denied for one of the directories in the path prefix.
    /// or
    /// The user tried to connect to a broadcast address without having the socket broadcast flag enabled or
    /// the connection request failed because of a local firewall rule.
    PermissionDenied,

    /// Local address is already in use.
    AddressInUse,

    /// (Internet  domain  sockets)  The  socket  referred  to  by socket had not previously been bound to an
    /// address and, upon attempting to bind it to an ephemeral port, it was determined that all port numbers
    /// in the ephemeral port range are currently in use.
    AddressNotAvailable,

    /// The passed address didn't have the correct address family in its sa_family field.
    AddressFamilyNotSupported,

    /// Insufficient entries in the routing cache.
    SystemResources,

    /// A connect() on a stream socket found no one listening on the remote address.
    ConnectionRefused,

    /// Network is unreachable.
    NetworkUnreachable,

    /// Timeout while attempting connection. The server may be too busy to accept new connections. Note
    /// that for IP sockets the timeout may be very long when syncookies are enabled on the server.
    ConnectionTimedOut,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub const GetSockNameError = error{
    /// Insufficient resources were available in the system to perform the operation.
    SystemResources,

    /// The file descriptor socket does not refer to a socket.
    FileDescriptorNotASocket,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub const GetPeerNameError = error{
    /// Insufficient resources were available in the system to perform the operation.
    SystemResources,

    /// The file descriptor socket does not refer to a socket.
    FileDescriptorNotASocket,

    /// The socket is not connected.
    NotConnected,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub const ShutdownError = error{
    /// The file descriptor socket does not refer to a socket.
    FileDescriptorNotASocket,

    /// The socket is not connected.
    NotConnected,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub const SocketAttributeError = error{
    /// The file descriptor socket does not refer to a socket.
    FileDescriptorNotASocket,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};
