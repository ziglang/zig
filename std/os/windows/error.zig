/// The operation completed successfully.
pub const SUCCESS = 0;

/// Incorrect function.
pub const INVALID_FUNCTION = 1;

/// The system cannot find the file specified.
pub const FILE_NOT_FOUND = 2;

/// The system cannot find the path specified.
pub const PATH_NOT_FOUND = 3;

/// The system cannot open the file.
pub const TOO_MANY_OPEN_FILES = 4;

/// Access is denied.
pub const ACCESS_DENIED = 5;

/// The handle is invalid.
pub const INVALID_HANDLE = 6;

/// The storage control blocks were destroyed.
pub const ARENA_TRASHED = 7;

/// Not enough storage is available to process this command.
pub const NOT_ENOUGH_MEMORY = 8;

/// The storage control block address is invalid.
pub const INVALID_BLOCK = 9;

/// The environment is incorrect.
pub const BAD_ENVIRONMENT = 10;

/// An attempt was made to load a program with an incorrect format.
pub const BAD_FORMAT = 11;

/// The access code is invalid.
pub const INVALID_ACCESS = 12;

/// The data is invalid.
pub const INVALID_DATA = 13;

/// Not enough storage is available to complete this operation.
pub const OUTOFMEMORY = 14;

/// The system cannot find the drive specified.
pub const INVALID_DRIVE = 15;

/// The directory cannot be removed.
pub const CURRENT_DIRECTORY = 16;

/// The system cannot move the file to a different disk drive.
pub const NOT_SAME_DEVICE = 17;

/// There are no more files.
pub const NO_MORE_FILES = 18;

/// The media is write protected.
pub const WRITE_PROTECT = 19;

/// The system cannot find the device specified.
pub const BAD_UNIT = 20;

/// The device is not ready.
pub const NOT_READY = 21;

/// The device does not recognize the command.
pub const BAD_COMMAND = 22;

/// Data error (cyclic redundancy check).
pub const CRC = 23;

/// The program issued a command but the command length is incorrect.
pub const BAD_LENGTH = 24;

/// The drive cannot locate a specific area or track on the disk.
pub const SEEK = 25;

/// The specified disk or diskette cannot be accessed.
pub const NOT_DOS_DISK = 26;

/// The drive cannot find the sector requested.
pub const SECTOR_NOT_FOUND = 27;

/// The printer is out of paper.
pub const OUT_OF_PAPER = 28;

/// The system cannot write to the specified device.
pub const WRITE_FAULT = 29;

/// The system cannot read from the specified device.
pub const READ_FAULT = 30;

/// A device attached to the system is not functioning.
pub const GEN_FAILURE = 31;

/// The process cannot access the file because it is being used by another process.
pub const SHARING_VIOLATION = 32;

/// The process cannot access the file because another process has locked a portion of the file.
pub const LOCK_VIOLATION = 33;

/// The wrong diskette is in the drive. Insert %2 (Volume Serial Number: %3) into drive %1.
pub const WRONG_DISK = 34;

/// Too many files opened for sharing.
pub const SHARING_BUFFER_EXCEEDED = 36;

/// Reached the end of the file.
pub const HANDLE_EOF = 38;

/// The disk is full.
pub const HANDLE_DISK_FULL = 39;

/// The request is not supported.
pub const NOT_SUPPORTED = 50;

/// Windows cannot find the network path. Verify that the network path is correct and the destination computer is not busy or turned off. If Windows still cannot find the network path, contact your network administrator.
pub const REM_NOT_LIST = 51;

/// You were not connected because a duplicate name exists on the network. If joining a domain, go to System in Control Panel to change the computer name and try again. If joining a workgroup, choose another workgroup name.
pub const DUP_NAME = 52;

/// The network path was not found.
pub const BAD_NETPATH = 53;

/// The network is busy.
pub const NETWORK_BUSY = 54;

/// The specified network resource or device is no longer available.
pub const DEV_NOT_EXIST = 55;

/// The network BIOS command limit has been reached.
pub const TOO_MANY_CMDS = 56;

/// A network adapter hardware error occurred.
pub const ADAP_HDW_ERR = 57;

/// The specified server cannot perform the requested operation.
pub const BAD_NET_RESP = 58;

/// An unexpected network error occurred.
pub const UNEXP_NET_ERR = 59;

/// The remote adapter is not compatible.
pub const BAD_REM_ADAP = 60;

/// The printer queue is full.
pub const PRINTQ_FULL = 61;

/// Space to store the file waiting to be printed is not available on the server.
pub const NO_SPOOL_SPACE = 62;

/// Your file waiting to be printed was deleted.
pub const PRINT_CANCELLED = 63;

/// The specified network name is no longer available.
pub const NETNAME_DELETED = 64;

/// Network access is denied.
pub const NETWORK_ACCESS_DENIED = 65;

/// The network resource type is not correct.
pub const BAD_DEV_TYPE = 66;

/// The network name cannot be found.
pub const BAD_NET_NAME = 67;

/// The name limit for the local computer network adapter card was exceeded.
pub const TOO_MANY_NAMES = 68;

/// The network BIOS session limit was exceeded.
pub const TOO_MANY_SESS = 69;

/// The remote server has been paused or is in the process of being started.
pub const SHARING_PAUSED = 70;

/// No more connections can be made to this remote computer at this time because there are already as many connections as the computer can accept.
pub const REQ_NOT_ACCEP = 71;

/// The specified printer or disk device has been paused.
pub const REDIR_PAUSED = 72;

/// The file exists.
pub const FILE_EXISTS = 80;

/// The directory or file cannot be created.
pub const CANNOT_MAKE = 82;

/// Fail on INT 24.
pub const FAIL_I24 = 83;

/// Storage to process this request is not available.
pub const OUT_OF_STRUCTURES = 84;

/// The local device name is already in use.
pub const ALREADY_ASSIGNED = 85;

/// The specified network password is not correct.
pub const INVALID_PASSWORD = 86;

/// The parameter is incorrect.
pub const INVALID_PARAMETER = 87;

/// A write fault occurred on the network.
pub const NET_WRITE_FAULT = 88;

/// The system cannot start another process at this time.
pub const NO_PROC_SLOTS = 89;

/// Cannot create another system semaphore.
pub const TOO_MANY_SEMAPHORES = 100;

/// The exclusive semaphore is owned by another process.
pub const EXCL_SEM_ALREADY_OWNED = 101;

/// The semaphore is set and cannot be closed.
pub const SEM_IS_SET = 102;

/// The semaphore cannot be set again.
pub const TOO_MANY_SEM_REQUESTS = 103;

/// Cannot request exclusive semaphores at interrupt time.
pub const INVALID_AT_INTERRUPT_TIME = 104;

/// The previous ownership of this semaphore has ended.
pub const SEM_OWNER_DIED = 105;

/// Insert the diskette for drive %1.
pub const SEM_USER_LIMIT = 106;

/// The program stopped because an alternate diskette was not inserted.
pub const DISK_CHANGE = 107;

/// The disk is in use or locked by another process.
pub const DRIVE_LOCKED = 108;

/// The pipe has been ended.
pub const BROKEN_PIPE = 109;

/// The system cannot open the device or file specified.
pub const OPEN_FAILED = 110;

/// The file name is too long.
pub const BUFFER_OVERFLOW = 111;

/// There is not enough space on the disk.
pub const DISK_FULL = 112;

/// No more internal file identifiers available.
pub const NO_MORE_SEARCH_HANDLES = 113;

/// The target internal file identifier is incorrect.
pub const INVALID_TARGET_HANDLE = 114;

/// The IOCTL call made by the application program is not correct.
pub const INVALID_CATEGORY = 117;

/// The verify-on-write switch parameter value is not correct.
pub const INVALID_VERIFY_SWITCH = 118;

/// The system does not support the command requested.
pub const BAD_DRIVER_LEVEL = 119;

/// This function is not supported on this system.
pub const CALL_NOT_IMPLEMENTED = 120;

/// The semaphore timeout period has expired.
pub const SEM_TIMEOUT = 121;

/// The data area passed to a system call is too small.
pub const INSUFFICIENT_BUFFER = 122;

/// The filename, directory name, or volume label syntax is incorrect.
pub const INVALID_NAME = 123;

/// The system call level is not correct.
pub const INVALID_LEVEL = 124;

/// The disk has no volume label.
pub const NO_VOLUME_LABEL = 125;

/// The specified module could not be found.
pub const MOD_NOT_FOUND = 126;

/// The specified procedure could not be found.
pub const PROC_NOT_FOUND = 127;

/// There are no child processes to wait for.
pub const WAIT_NO_CHILDREN = 128;

/// The %1 application cannot be run in Win32 mode.
pub const CHILD_NOT_COMPLETE = 129;

/// Attempt to use a file handle to an open disk partition for an operation other than raw disk I/O.
pub const DIRECT_ACCESS_HANDLE = 130;

/// An attempt was made to move the file pointer before the beginning of the file.
pub const NEGATIVE_SEEK = 131;

/// The file pointer cannot be set on the specified device or file.
pub const SEEK_ON_DEVICE = 132;

/// A JOIN or SUBST command cannot be used for a drive that contains previously joined drives.
pub const IS_JOIN_TARGET = 133;

/// An attempt was made to use a JOIN or SUBST command on a drive that has already been joined.
pub const IS_JOINED = 134;

/// An attempt was made to use a JOIN or SUBST command on a drive that has already been substituted.
pub const IS_SUBSTED = 135;

/// The system tried to delete the JOIN of a drive that is not joined.
pub const NOT_JOINED = 136;

/// The system tried to delete the substitution of a drive that is not substituted.
pub const NOT_SUBSTED = 137;

/// The system tried to join a drive to a directory on a joined drive.
pub const JOIN_TO_JOIN = 138;

/// The system tried to substitute a drive to a directory on a substituted drive.
pub const SUBST_TO_SUBST = 139;

/// The system tried to join a drive to a directory on a substituted drive.
pub const JOIN_TO_SUBST = 140;

/// The system tried to SUBST a drive to a directory on a joined drive.
pub const SUBST_TO_JOIN = 141;

/// The system cannot perform a JOIN or SUBST at this time.
pub const BUSY_DRIVE = 142;

/// The system cannot join or substitute a drive to or for a directory on the same drive.
pub const SAME_DRIVE = 143;

/// The directory is not a subdirectory of the root directory.
pub const DIR_NOT_ROOT = 144;

/// The directory is not empty.
pub const DIR_NOT_EMPTY = 145;

/// The path specified is being used in a substitute.
pub const IS_SUBST_PATH = 146;

/// Not enough resources are available to process this command.
pub const IS_JOIN_PATH = 147;

/// The path specified cannot be used at this time.
pub const PATH_BUSY = 148;

/// An attempt was made to join or substitute a drive for which a directory on the drive is the target of a previous substitute.
pub const IS_SUBST_TARGET = 149;

/// System trace information was not specified in your CONFIG.SYS file, or tracing is disallowed.
pub const SYSTEM_TRACE = 150;

/// The number of specified semaphore events for DosMuxSemWait is not correct.
pub const INVALID_EVENT_COUNT = 151;

/// DosMuxSemWait did not execute; too many semaphores are already set.
pub const TOO_MANY_MUXWAITERS = 152;

/// The DosMuxSemWait list is not correct.
pub const INVALID_LIST_FORMAT = 153;

/// The volume label you entered exceeds the label character limit of the target file system.
pub const LABEL_TOO_LONG = 154;

/// Cannot create another thread.
pub const TOO_MANY_TCBS = 155;

/// The recipient process has refused the signal.
pub const SIGNAL_REFUSED = 156;

/// The segment is already discarded and cannot be locked.
pub const DISCARDED = 157;

/// The segment is already unlocked.
pub const NOT_LOCKED = 158;

/// The address for the thread ID is not correct.
pub const BAD_THREADID_ADDR = 159;

/// One or more arguments are not correct.
pub const BAD_ARGUMENTS = 160;

/// The specified path is invalid.
pub const BAD_PATHNAME = 161;

/// A signal is already pending.
pub const SIGNAL_PENDING = 162;

/// No more threads can be created in the system.
pub const MAX_THRDS_REACHED = 164;

/// Unable to lock a region of a file.
pub const LOCK_FAILED = 167;

/// The requested resource is in use.
pub const BUSY = 170;

/// Device's command support detection is in progress.
pub const DEVICE_SUPPORT_IN_PROGRESS = 171;

/// A lock request was not outstanding for the supplied cancel region.
pub const CANCEL_VIOLATION = 173;

/// The file system does not support atomic changes to the lock type.
pub const ATOMIC_LOCKS_NOT_SUPPORTED = 174;

/// The system detected a segment number that was not correct.
pub const INVALID_SEGMENT_NUMBER = 180;

/// The operating system cannot run %1.
pub const INVALID_ORDINAL = 182;

/// Cannot create a file when that file already exists.
pub const ALREADY_EXISTS = 183;

/// The flag passed is not correct.
pub const INVALID_FLAG_NUMBER = 186;

/// The specified system semaphore name was not found.
pub const SEM_NOT_FOUND = 187;

/// The operating system cannot run %1.
pub const INVALID_STARTING_CODESEG = 188;

/// The operating system cannot run %1.
pub const INVALID_STACKSEG = 189;

/// The operating system cannot run %1.
pub const INVALID_MODULETYPE = 190;

/// Cannot run %1 in Win32 mode.
pub const INVALID_EXE_SIGNATURE = 191;

/// The operating system cannot run %1.
pub const EXE_MARKED_INVALID = 192;

/// %1 is not a valid Win32 application.
pub const BAD_EXE_FORMAT = 193;

/// The operating system cannot run %1.
pub const ITERATED_DATA_EXCEEDS_64k = 194;

/// The operating system cannot run %1.
pub const INVALID_MINALLOCSIZE = 195;

/// The operating system cannot run this application program.
pub const DYNLINK_FROM_INVALID_RING = 196;

/// The operating system is not presently configured to run this application.
pub const IOPL_NOT_ENABLED = 197;

/// The operating system cannot run %1.
pub const INVALID_SEGDPL = 198;

/// The operating system cannot run this application program.
pub const AUTODATASEG_EXCEEDS_64k = 199;

/// The code segment cannot be greater than or equal to 64K.
pub const RING2SEG_MUST_BE_MOVABLE = 200;

/// The operating system cannot run %1.
pub const RELOC_CHAIN_XEEDS_SEGLIM = 201;

/// The operating system cannot run %1.
pub const INFLOOP_IN_RELOC_CHAIN = 202;

/// The system could not find the environment option that was entered.
pub const ENVVAR_NOT_FOUND = 203;

/// No process in the command subtree has a signal handler.
pub const NO_SIGNAL_SENT = 205;

/// The filename or extension is too long.
pub const FILENAME_EXCED_RANGE = 206;

/// The ring 2 stack is in use.
pub const RING2_STACK_IN_USE = 207;

/// The global filename characters, * or ?, are entered incorrectly or too many global filename characters are specified.
pub const META_EXPANSION_TOO_LONG = 208;

/// The signal being posted is not correct.
pub const INVALID_SIGNAL_NUMBER = 209;

/// The signal handler cannot be set.
pub const THREAD_1_INACTIVE = 210;

/// The segment is locked and cannot be reallocated.
pub const LOCKED = 212;

/// Too many dynamic-link modules are attached to this program or dynamic-link module.
pub const TOO_MANY_MODULES = 214;

/// Cannot nest calls to LoadModule.
pub const NESTING_NOT_ALLOWED = 215;

/// This version of %1 is not compatible with the version of Windows you're running. Check your computer's system information and then contact the software publisher.
pub const EXE_MACHINE_TYPE_MISMATCH = 216;

/// The image file %1 is signed, unable to modify.
pub const EXE_CANNOT_MODIFY_SIGNED_BINARY = 217;

/// The image file %1 is strong signed, unable to modify.
pub const EXE_CANNOT_MODIFY_STRONG_SIGNED_BINARY = 218;

/// This file is checked out or locked for editing by another user.
pub const FILE_CHECKED_OUT = 220;

/// The file must be checked out before saving changes.
pub const CHECKOUT_REQUIRED = 221;

/// The file type being saved or retrieved has been blocked.
pub const BAD_FILE_TYPE = 222;

/// The file size exceeds the limit allowed and cannot be saved.
pub const FILE_TOO_LARGE = 223;

/// Access Denied. Before opening files in this location, you must first add the web site to your trusted sites list, browse to the web site, and select the option to login automatically.
pub const FORMS_AUTH_REQUIRED = 224;

/// Operation did not complete successfully because the file contains a virus or potentially unwanted software.
pub const VIRUS_INFECTED = 225;

/// This file contains a virus or potentially unwanted software and cannot be opened. Due to the nature of this virus or potentially unwanted software, the file has been removed from this location.
pub const VIRUS_DELETED = 226;

/// The pipe is local.
pub const PIPE_LOCAL = 229;

/// The pipe state is invalid.
pub const BAD_PIPE = 230;

/// All pipe instances are busy.
pub const PIPE_BUSY = 231;

/// The pipe is being closed.
pub const NO_DATA = 232;

/// No process is on the other end of the pipe.
pub const PIPE_NOT_CONNECTED = 233;

/// More data is available.
pub const MORE_DATA = 234;

/// The session was canceled.
pub const VC_DISCONNECTED = 240;

/// The specified extended attribute name was invalid.
pub const INVALID_EA_NAME = 254;

/// The extended attributes are inconsistent.
pub const EA_LIST_INCONSISTENT = 255;

/// The wait operation timed out.
pub const IMEOUT = 258;

/// No more data is available.
pub const NO_MORE_ITEMS = 259;

/// The copy functions cannot be used.
pub const CANNOT_COPY = 266;

/// The directory name is invalid.
pub const DIRECTORY = 267;

/// The extended attributes did not fit in the buffer.
pub const EAS_DIDNT_FIT = 275;

/// The extended attribute file on the mounted file system is corrupt.
pub const EA_FILE_CORRUPT = 276;

/// The extended attribute table file is full.
pub const EA_TABLE_FULL = 277;

/// The specified extended attribute handle is invalid.
pub const INVALID_EA_HANDLE = 278;

/// The mounted file system does not support extended attributes.
pub const EAS_NOT_SUPPORTED = 282;

/// Attempt to release mutex not owned by caller.
pub const NOT_OWNER = 288;

/// Too many posts were made to a semaphore.
pub const TOO_MANY_POSTS = 298;

/// Only part of a ReadProcessMemory or WriteProcessMemory request was completed.
pub const PARTIAL_COPY = 299;

/// The oplock request is denied.
pub const OPLOCK_NOT_GRANTED = 300;

/// An invalid oplock acknowledgment was received by the system.
pub const INVALID_OPLOCK_PROTOCOL = 301;

/// The volume is too fragmented to complete this operation.
pub const DISK_TOO_FRAGMENTED = 302;

/// The file cannot be opened because it is in the process of being deleted.
pub const DELETE_PENDING = 303;

/// Short name settings may not be changed on this volume due to the global registry setting.
pub const INCOMPATIBLE_WITH_GLOBAL_SHORT_NAME_REGISTRY_SETTING = 304;

/// Short names are not enabled on this volume.
pub const SHORT_NAMES_NOT_ENABLED_ON_VOLUME = 305;

/// The security stream for the given volume is in an inconsistent state. Please run CHKDSK on the volume.
pub const SECURITY_STREAM_IS_INCONSISTENT = 306;

/// A requested file lock operation cannot be processed due to an invalid byte range.
pub const INVALID_LOCK_RANGE = 307;

/// The subsystem needed to support the image type is not present.
pub const IMAGE_SUBSYSTEM_NOT_PRESENT = 308;

/// The specified file already has a notification GUID associated with it.
pub const NOTIFICATION_GUID_ALREADY_DEFINED = 309;

/// An invalid exception handler routine has been detected.
pub const INVALID_EXCEPTION_HANDLER = 310;

/// Duplicate privileges were specified for the token.
pub const DUPLICATE_PRIVILEGES = 311;

/// No ranges for the specified operation were able to be processed.
pub const NO_RANGES_PROCESSED = 312;

/// Operation is not allowed on a file system internal file.
pub const NOT_ALLOWED_ON_SYSTEM_FILE = 313;

/// The physical resources of this disk have been exhausted.
pub const DISK_RESOURCES_EXHAUSTED = 314;

/// The token representing the data is invalid.
pub const INVALID_TOKEN = 315;

/// The device does not support the command feature.
pub const DEVICE_FEATURE_NOT_SUPPORTED = 316;

/// The system cannot find message text for message number 0x%1 in the message file for %2.
pub const MR_MID_NOT_FOUND = 317;

/// The scope specified was not found.
pub const SCOPE_NOT_FOUND = 318;

/// The Central Access Policy specified is not defined on the target machine.
pub const UNDEFINED_SCOPE = 319;

/// The Central Access Policy obtained from Active Directory is invalid.
pub const INVALID_CAP = 320;

/// The device is unreachable.
pub const DEVICE_UNREACHABLE = 321;

/// The target device has insufficient resources to complete the operation.
pub const DEVICE_NO_RESOURCES = 322;

/// A data integrity checksum error occurred. Data in the file stream is corrupt.
pub const DATA_CHECKSUM_ERROR = 323;

/// An attempt was made to modify both a KERNEL and normal Extended Attribute (EA) in the same operation.
pub const INTERMIXED_KERNEL_EA_OPERATION = 324;

/// Device does not support file-level TRIM.
pub const FILE_LEVEL_TRIM_NOT_SUPPORTED = 326;

/// The command specified a data offset that does not align to the device's granularity/alignment.
pub const OFFSET_ALIGNMENT_VIOLATION = 327;

/// The command specified an invalid field in its parameter list.
pub const INVALID_FIELD_IN_PARAMETER_LIST = 328;

/// An operation is currently in progress with the device.
pub const OPERATION_IN_PROGRESS = 329;

/// An attempt was made to send down the command via an invalid path to the target device.
pub const BAD_DEVICE_PATH = 330;

/// The command specified a number of descriptors that exceeded the maximum supported by the device.
pub const TOO_MANY_DESCRIPTORS = 331;

/// Scrub is disabled on the specified file.
pub const SCRUB_DATA_DISABLED = 332;

/// The storage device does not provide redundancy.
pub const NOT_REDUNDANT_STORAGE = 333;

/// An operation is not supported on a resident file.
pub const RESIDENT_FILE_NOT_SUPPORTED = 334;

/// An operation is not supported on a compressed file.
pub const COMPRESSED_FILE_NOT_SUPPORTED = 335;

/// An operation is not supported on a directory.
pub const DIRECTORY_NOT_SUPPORTED = 336;

/// The specified copy of the requested data could not be read.
pub const NOT_READ_FROM_COPY = 337;

/// No action was taken as a system reboot is required.
pub const FAIL_NOACTION_REBOOT = 350;

/// The shutdown operation failed.
pub const FAIL_SHUTDOWN = 351;

/// The restart operation failed.
pub const FAIL_RESTART = 352;

/// The maximum number of sessions has been reached.
pub const MAX_SESSIONS_REACHED = 353;

/// The thread is already in background processing mode.
pub const THREAD_MODE_ALREADY_BACKGROUND = 400;

/// The thread is not in background processing mode.
pub const THREAD_MODE_NOT_BACKGROUND = 401;

/// The process is already in background processing mode.
pub const PROCESS_MODE_ALREADY_BACKGROUND = 402;

/// The process is not in background processing mode.
pub const PROCESS_MODE_NOT_BACKGROUND = 403;

/// Attempt to access invalid address.
pub const INVALID_ADDRESS = 487;

/// User profile cannot be loaded.
pub const USER_PROFILE_LOAD = 500;

/// Arithmetic result exceeded 32 bits.
pub const ARITHMETIC_OVERFLOW = 534;

/// There is a process on other end of the pipe.
pub const PIPE_CONNECTED = 535;

/// Waiting for a process to open the other end of the pipe.
pub const PIPE_LISTENING = 536;

/// Application verifier has found an error in the current process.
pub const VERIFIER_STOP = 537;

/// An error occurred in the ABIOS subsystem.
pub const ABIOS_ERROR = 538;

/// A warning occurred in the WX86 subsystem.
pub const WX86_WARNING = 539;

/// An error occurred in the WX86 subsystem.
pub const WX86_ERROR = 540;

/// An attempt was made to cancel or set a timer that has an associated APC and the subject thread is not the thread that originally set the timer with an associated APC routine.
pub const TIMER_NOT_CANCELED = 541;

/// Unwind exception code.
pub const UNWIND = 542;

/// An invalid or unaligned stack was encountered during an unwind operation.
pub const BAD_STACK = 543;

/// An invalid unwind target was encountered during an unwind operation.
pub const INVALID_UNWIND_TARGET = 544;

/// Invalid Object Attributes specified to NtCreatePort or invalid Port Attributes specified to NtConnectPort
pub const INVALID_PORT_ATTRIBUTES = 545;

/// Length of message passed to NtRequestPort or NtRequestWaitReplyPort was longer than the maximum message allowed by the port.
pub const PORT_MESSAGE_TOO_LONG = 546;

/// An attempt was made to lower a quota limit below the current usage.
pub const INVALID_QUOTA_LOWER = 547;

/// An attempt was made to attach to a device that was already attached to another device.
pub const DEVICE_ALREADY_ATTACHED = 548;

/// An attempt was made to execute an instruction at an unaligned address and the host system does not support unaligned instruction references.
pub const INSTRUCTION_MISALIGNMENT = 549;

/// Profiling not started.
pub const PROFILING_NOT_STARTED = 550;

/// Profiling not stopped.
pub const PROFILING_NOT_STOPPED = 551;

/// The passed ACL did not contain the minimum required information.
pub const COULD_NOT_INTERPRET = 552;

/// The number of active profiling objects is at the maximum and no more may be started.
pub const PROFILING_AT_LIMIT = 553;

/// Used to indicate that an operation cannot continue without blocking for I/O.
pub const CANT_WAIT = 554;

/// Indicates that a thread attempted to terminate itself by default (called NtTerminateThread with NULL) and it was the last thread in the current process.
pub const CANT_TERMINATE_SELF = 555;

/// If an MM error is returned which is not defined in the standard FsRtl filter, it is converted to one of the following errors which is guaranteed to be in the filter. In this case information is lost, however, the filter correctly handles the exception.
pub const UNEXPECTED_MM_CREATE_ERR = 556;

/// If an MM error is returned which is not defined in the standard FsRtl filter, it is converted to one of the following errors which is guaranteed to be in the filter. In this case information is lost, however, the filter correctly handles the exception.
pub const UNEXPECTED_MM_MAP_ERROR = 557;

/// If an MM error is returned which is not defined in the standard FsRtl filter, it is converted to one of the following errors which is guaranteed to be in the filter. In this case information is lost, however, the filter correctly handles the exception.
pub const UNEXPECTED_MM_EXTEND_ERR = 558;

/// A malformed function table was encountered during an unwind operation.
pub const BAD_FUNCTION_TABLE = 559;

/// Indicates that an attempt was made to assign protection to a file system file or directory and one of the SIDs in the security descriptor could not be translated into a GUID that could be stored by the file system. This causes the protection attempt to fail, which may cause a file creation attempt to fail.
pub const NO_GUID_TRANSLATION = 560;

/// Indicates that an attempt was made to grow an LDT by setting its size, or that the size was not an even number of selectors.
pub const INVALID_LDT_SIZE = 561;

/// Indicates that the starting value for the LDT information was not an integral multiple of the selector size.
pub const INVALID_LDT_OFFSET = 563;

/// Indicates that the user supplied an invalid descriptor when trying to set up Ldt descriptors.
pub const INVALID_LDT_DESCRIPTOR = 564;

/// Indicates a process has too many threads to perform the requested action. For example, assignment of a primary token may only be performed when a process has zero or one threads.
pub const TOO_MANY_THREADS = 565;

/// An attempt was made to operate on a thread within a specific process, but the thread specified is not in the process specified.
pub const THREAD_NOT_IN_PROCESS = 566;

/// Page file quota was exceeded.
pub const PAGEFILE_QUOTA_EXCEEDED = 567;

/// The Netlogon service cannot start because another Netlogon service running in the domain conflicts with the specified role.
pub const LOGON_SERVER_CONFLICT = 568;

/// The SAM database on a Windows Server is significantly out of synchronization with the copy on the Domain Controller. A complete synchronization is required.
pub const SYNCHRONIZATION_REQUIRED = 569;

/// The NtCreateFile API failed. This error should never be returned to an application, it is a place holder for the Windows Lan Manager Redirector to use in its internal error mapping routines.
pub const NET_OPEN_FAILED = 570;

/// {Privilege Failed} The I/O permissions for the process could not be changed.
pub const IO_PRIVILEGE_FAILED = 571;

/// {Application Exit by CTRL+C} The application terminated as a result of a CTRL+C.
pub const CONTROL_C_EXIT = 572;

/// {Missing System File} The required system file %hs is bad or missing.
pub const MISSING_SYSTEMFILE = 573;

/// {Application Error} The exception %s (0x%08lx) occurred in the application at location 0x%08lx.
pub const UNHANDLED_EXCEPTION = 574;

/// {Application Error} The application was unable to start correctly (0x%lx). Click OK to close the application.
pub const APP_INIT_FAILURE = 575;

/// {Unable to Create Paging File} The creation of the paging file %hs failed (%lx). The requested size was %ld.
pub const PAGEFILE_CREATE_FAILED = 576;

/// Windows cannot verify the digital signature for this file. A recent hardware or software change might have installed a file that is signed incorrectly or damaged, or that might be malicious software from an unknown source.
pub const INVALID_IMAGE_HASH = 577;

/// {No Paging File Specified} No paging file was specified in the system configuration.
pub const NO_PAGEFILE = 578;

/// {EXCEPTION} A real-mode application issued a floating-point instruction and floating-point hardware is not present.
pub const ILLEGAL_FLOAT_CONTEXT = 579;

/// An event pair synchronization operation was performed using the thread specific client/server event pair object, but no event pair object was associated with the thread.
pub const NO_EVENT_PAIR = 580;

/// A Windows Server has an incorrect configuration.
pub const DOMAIN_CTRLR_CONFIG_ERROR = 581;

/// An illegal character was encountered. For a multi-byte character set this includes a lead byte without a succeeding trail byte. For the Unicode character set this includes the characters 0xFFFF and 0xFFFE.
pub const ILLEGAL_CHARACTER = 582;

/// The Unicode character is not defined in the Unicode character set installed on the system.
pub const UNDEFINED_CHARACTER = 583;

/// The paging file cannot be created on a floppy diskette.
pub const FLOPPY_VOLUME = 584;

/// The system BIOS failed to connect a system interrupt to the device or bus for which the device is connected.
pub const BIOS_FAILED_TO_CONNECT_INTERRUPT = 585;

/// This operation is only allowed for the Primary Domain Controller of the domain.
pub const BACKUP_CONTROLLER = 586;

/// An attempt was made to acquire a mutant such that its maximum count would have been exceeded.
pub const MUTANT_LIMIT_EXCEEDED = 587;

/// A volume has been accessed for which a file system driver is required that has not yet been loaded.
pub const FS_DRIVER_REQUIRED = 588;

/// {Registry File Failure} The registry cannot load the hive (file): %hs or its log or alternate. It is corrupt, absent, or not writable.
pub const CANNOT_LOAD_REGISTRY_FILE = 589;

/// {Unexpected Failure in DebugActiveProcess} An unexpected failure occurred while processing a DebugActiveProcess API request. You may choose OK to terminate the process, or Cancel to ignore the error.
pub const DEBUG_ATTACH_FAILED = 590;

/// {Fatal System Error} The %hs system process terminated unexpectedly with a status of 0x%08x (0x%08x 0x%08x). The system has been shut down.
pub const SYSTEM_PROCESS_TERMINATED = 591;

/// {Data Not Accepted} The TDI client could not handle the data received during an indication.
pub const DATA_NOT_ACCEPTED = 592;

/// NTVDM encountered a hard error.
pub const VDM_HARD_ERROR = 593;

/// {Cancel Timeout} The driver %hs failed to complete a cancelled I/O request in the allotted time.
pub const DRIVER_CANCEL_TIMEOUT = 594;

/// {Reply Message Mismatch} An attempt was made to reply to an LPC message, but the thread specified by the client ID in the message was not waiting on that message.
pub const REPLY_MESSAGE_MISMATCH = 595;

/// {Delayed Write Failed} Windows was unable to save all the data for the file %hs. The data has been lost. This error may be caused by a failure of your computer hardware or network connection. Please try to save this file elsewhere.
pub const LOST_WRITEBEHIND_DATA = 596;

/// The parameter(s) passed to the server in the client/server shared memory window were invalid. Too much data may have been put in the shared memory window.
pub const CLIENT_SERVER_PARAMETERS_INVALID = 597;

/// The stream is not a tiny stream.
pub const NOT_TINY_STREAM = 598;

/// The request must be handled by the stack overflow code.
pub const STACK_OVERFLOW_READ = 599;

/// Internal OFS status codes indicating how an allocation operation is handled. Either it is retried after the containing onode is moved or the extent stream is converted to a large stream.
pub const CONVERT_TO_LARGE = 600;

/// The attempt to find the object found an object matching by ID on the volume but it is out of the scope of the handle used for the operation.
pub const FOUND_OUT_OF_SCOPE = 601;

/// The bucket array must be grown. Retry transaction after doing so.
pub const ALLOCATE_BUCKET = 602;

/// The user/kernel marshalling buffer has overflowed.
pub const MARSHALL_OVERFLOW = 603;

/// The supplied variant structure contains invalid data.
pub const INVALID_VARIANT = 604;

/// The specified buffer contains ill-formed data.
pub const BAD_COMPRESSION_BUFFER = 605;

/// {Audit Failed} An attempt to generate a security audit failed.
pub const AUDIT_FAILED = 606;

/// The timer resolution was not previously set by the current process.
pub const TIMER_RESOLUTION_NOT_SET = 607;

/// There is insufficient account information to log you on.
pub const INSUFFICIENT_LOGON_INFO = 608;

/// {Invalid DLL Entrypoint} The dynamic link library %hs is not written correctly. The stack pointer has been left in an inconsistent state. The entrypoint should be declared as WINAPI or STDCALL. Select YES to fail the DLL load. Select NO to continue execution. Selecting NO may cause the application to operate incorrectly.
pub const BAD_DLL_ENTRYPOINT = 609;

/// {Invalid Service Callback Entrypoint} The %hs service is not written correctly. The stack pointer has been left in an inconsistent state. The callback entrypoint should be declared as WINAPI or STDCALL. Selecting OK will cause the service to continue operation. However, the service process may operate incorrectly.
pub const BAD_SERVICE_ENTRYPOINT = 610;

/// There is an IP address conflict with another system on the network.
pub const IP_ADDRESS_CONFLICT1 = 611;

/// There is an IP address conflict with another system on the network.
pub const IP_ADDRESS_CONFLICT2 = 612;

/// {Low On Registry Space} The system has reached the maximum size allowed for the system part of the registry. Additional storage requests will be ignored.
pub const REGISTRY_QUOTA_LIMIT = 613;

/// A callback return system service cannot be executed when no callback is active.
pub const NO_CALLBACK_ACTIVE = 614;

/// The password provided is too short to meet the policy of your user account. Please choose a longer password.
pub const PWD_TOO_SHORT = 615;

/// The policy of your user account does not allow you to change passwords too frequently. This is done to prevent users from changing back to a familiar, but potentially discovered, password. If you feel your password has been compromised then please contact your administrator immediately to have a new one assigned.
pub const PWD_TOO_RECENT = 616;

/// You have attempted to change your password to one that you have used in the past. The policy of your user account does not allow this. Please select a password that you have not previously used.
pub const PWD_HISTORY_CONFLICT = 617;

/// The specified compression format is unsupported.
pub const UNSUPPORTED_COMPRESSION = 618;

/// The specified hardware profile configuration is invalid.
pub const INVALID_HW_PROFILE = 619;

/// The specified Plug and Play registry device path is invalid.
pub const INVALID_PLUGPLAY_DEVICE_PATH = 620;

/// The specified quota list is internally inconsistent with its descriptor.
pub const QUOTA_LIST_INCONSISTENT = 621;

/// {Windows Evaluation Notification} The evaluation period for this installation of Windows has expired. This system will shutdown in 1 hour. To restore access to this installation of Windows, please upgrade this installation using a licensed distribution of this product.
pub const EVALUATION_EXPIRATION = 622;

/// {Illegal System DLL Relocation} The system DLL %hs was relocated in memory. The application will not run properly. The relocation occurred because the DLL %hs occupied an address range reserved for Windows system DLLs. The vendor supplying the DLL should be contacted for a new DLL.
pub const ILLEGAL_DLL_RELOCATION = 623;

/// {DLL Initialization Failed} The application failed to initialize because the window station is shutting down.
pub const DLL_INIT_FAILED_LOGOFF = 624;

/// The validation process needs to continue on to the next step.
pub const VALIDATE_CONTINUE = 625;

/// There are no more matches for the current index enumeration.
pub const NO_MORE_MATCHES = 626;

/// The range could not be added to the range list because of a conflict.
pub const RANGE_LIST_CONFLICT = 627;

/// The server process is running under a SID different than that required by client.
pub const SERVER_SID_MISMATCH = 628;

/// A group marked use for deny only cannot be enabled.
pub const CANT_ENABLE_DENY_ONLY = 629;

/// {EXCEPTION} Multiple floating point faults.
pub const FLOAT_MULTIPLE_FAULTS = 630;

/// {EXCEPTION} Multiple floating point traps.
pub const FLOAT_MULTIPLE_TRAPS = 631;

/// The requested interface is not supported.
pub const NOINTERFACE = 632;

/// {System Standby Failed} The driver %hs does not support standby mode. Updating this driver may allow the system to go to standby mode.
pub const DRIVER_FAILED_SLEEP = 633;

/// The system file %1 has become corrupt and has been replaced.
pub const CORRUPT_SYSTEM_FILE = 634;

/// {Virtual Memory Minimum Too Low} Your system is low on virtual memory. Windows is increasing the size of your virtual memory paging file. During this process, memory requests for some applications may be denied. For more information, see Help.
pub const COMMITMENT_MINIMUM = 635;

/// A device was removed so enumeration must be restarted.
pub const PNP_RESTART_ENUMERATION = 636;

/// {Fatal System Error} The system image %s is not properly signed. The file has been replaced with the signed file. The system has been shut down.
pub const SYSTEM_IMAGE_BAD_SIGNATURE = 637;

/// Device will not start without a reboot.
pub const PNP_REBOOT_REQUIRED = 638;

/// There is not enough power to complete the requested operation.
pub const INSUFFICIENT_POWER = 639;

/// ERROR_MULTIPLE_FAULT_VIOLATION
pub const MULTIPLE_FAULT_VIOLATION = 640;

/// The system is in the process of shutting down.
pub const SYSTEM_SHUTDOWN = 641;

/// An attempt to remove a processes DebugPort was made, but a port was not already associated with the process.
pub const PORT_NOT_SET = 642;

/// This version of Windows is not compatible with the behavior version of directory forest, domain or domain controller.
pub const DS_VERSION_CHECK_FAILURE = 643;

/// The specified range could not be found in the range list.
pub const RANGE_NOT_FOUND = 644;

/// The driver was not loaded because the system is booting into safe mode.
pub const NOT_SAFE_MODE_DRIVER = 646;

/// The driver was not loaded because it failed its initialization call.
pub const FAILED_DRIVER_ENTRY = 647;

/// The "%hs" encountered an error while applying power or reading the device configuration. This may be caused by a failure of your hardware or by a poor connection.
pub const DEVICE_ENUMERATION_ERROR = 648;

/// The create operation failed because the name contained at least one mount point which resolves to a volume to which the specified device object is not attached.
pub const MOUNT_POINT_NOT_RESOLVED = 649;

/// The device object parameter is either not a valid device object or is not attached to the volume specified by the file name.
pub const INVALID_DEVICE_OBJECT_PARAMETER = 650;

/// A Machine Check Error has occurred. Please check the system eventlog for additional information.
pub const MCA_OCCURED = 651;

/// There was error [%2] processing the driver database.
pub const DRIVER_DATABASE_ERROR = 652;

/// System hive size has exceeded its limit.
pub const SYSTEM_HIVE_TOO_LARGE = 653;

/// The driver could not be loaded because a previous version of the driver is still in memory.
pub const DRIVER_FAILED_PRIOR_UNLOAD = 654;

/// {Volume Shadow Copy Service} Please wait while the Volume Shadow Copy Service prepares volume %hs for hibernation.
pub const VOLSNAP_PREPARE_HIBERNATE = 655;

/// The system has failed to hibernate (The error code is %hs). Hibernation will be disabled until the system is restarted.
pub const HIBERNATION_FAILURE = 656;

/// The password provided is too long to meet the policy of your user account. Please choose a shorter password.
pub const PWD_TOO_LONG = 657;

/// The requested operation could not be completed due to a file system limitation.
pub const FILE_SYSTEM_LIMITATION = 665;

/// An assertion failure has occurred.
pub const ASSERTION_FAILURE = 668;

/// An error occurred in the ACPI subsystem.
pub const ACPI_ERROR = 669;

/// WOW Assertion Error.
pub const WOW_ASSERTION = 670;

/// A device is missing in the system BIOS MPS table. This device will not be used. Please contact your system vendor for system BIOS update.
pub const PNP_BAD_MPS_TABLE = 671;

/// A translator failed to translate resources.
pub const PNP_TRANSLATION_FAILED = 672;

/// A IRQ translator failed to translate resources.
pub const PNP_IRQ_TRANSLATION_FAILED = 673;

/// Driver %2 returned invalid ID for a child device (%3).
pub const PNP_INVALID_ID = 674;

/// {Kernel Debugger Awakened} the system debugger was awakened by an interrupt.
pub const WAKE_SYSTEM_DEBUGGER = 675;

/// {Handles Closed} Handles to objects have been automatically closed as a result of the requested operation.
pub const HANDLES_CLOSED = 676;

/// {Too Much Information} The specified access control list (ACL) contained more information than was expected.
pub const EXTRANEOUS_INFORMATION = 677;

/// This warning level status indicates that the transaction state already exists for the registry sub-tree, but that a transaction commit was previously aborted. The commit has NOT been completed, but has not been rolled back either (so it may still be committed if desired).
pub const RXACT_COMMIT_NECESSARY = 678;

/// {Media Changed} The media may have changed.
pub const MEDIA_CHECK = 679;

/// {GUID Substitution} During the translation of a global identifier (GUID) to a Windows security ID (SID), no administratively-defined GUID prefix was found. A substitute prefix was used, which will not compromise system security. However, this may provide a more restrictive access than intended.
pub const GUID_SUBSTITUTION_MADE = 680;

/// The create operation stopped after reaching a symbolic link.
pub const STOPPED_ON_SYMLINK = 681;

/// A long jump has been executed.
pub const LONGJUMP = 682;

/// The Plug and Play query operation was not successful.
pub const PLUGPLAY_QUERY_VETOED = 683;

/// A frame consolidation has been executed.
pub const UNWIND_CONSOLIDATE = 684;

/// {Registry Hive Recovered} Registry hive (file): %hs was corrupted and it has been recovered. Some data might have been lost.
pub const REGISTRY_HIVE_RECOVERED = 685;

/// The application is attempting to run executable code from the module %hs. This may be insecure. An alternative, %hs, is available. Should the application use the secure module %hs?
pub const DLL_MIGHT_BE_INSECURE = 686;

/// The application is loading executable code from the module %hs. This is secure, but may be incompatible with previous releases of the operating system. An alternative, %hs, is available. Should the application use the secure module %hs?
pub const DLL_MIGHT_BE_INCOMPATIBLE = 687;

/// Debugger did not handle the exception.
pub const DBG_EXCEPTION_NOT_HANDLED = 688;

/// Debugger will reply later.
pub const DBG_REPLY_LATER = 689;

/// Debugger cannot provide handle.
pub const DBG_UNABLE_TO_PROVIDE_HANDLE = 690;

/// Debugger terminated thread.
pub const DBG_TERMINATE_THREAD = 691;

/// Debugger terminated process.
pub const DBG_TERMINATE_PROCESS = 692;

/// Debugger got control C.
pub const DBG_CONTROL_C = 693;

/// Debugger printed exception on control C.
pub const DBG_PRINTEXCEPTION_C = 694;

/// Debugger received RIP exception.
pub const DBG_RIPEXCEPTION = 695;

/// Debugger received control break.
pub const DBG_CONTROL_BREAK = 696;

/// Debugger command communication exception.
pub const DBG_COMMAND_EXCEPTION = 697;

/// {Object Exists} An attempt was made to create an object and the object name already existed.
pub const OBJECT_NAME_EXISTS = 698;

/// {Thread Suspended} A thread termination occurred while the thread was suspended. The thread was resumed, and termination proceeded.
pub const THREAD_WAS_SUSPENDED = 699;

/// {Image Relocated} An image file could not be mapped at the address specified in the image file. Local fixups must be performed on this image.
pub const IMAGE_NOT_AT_BASE = 700;

/// This informational level status indicates that a specified registry sub-tree transaction state did not yet exist and had to be created.
pub const RXACT_STATE_CREATED = 701;

/// {Segment Load} A virtual DOS machine (VDM) is loading, unloading, or moving an MS-DOS or Win16 program segment image. An exception is raised so a debugger can load, unload or track symbols and breakpoints within these 16-bit segments.
pub const SEGMENT_NOTIFICATION = 702;

/// {Invalid Current Directory} The process cannot switch to the startup current directory %hs. Select OK to set current directory to %hs, or select CANCEL to exit.
pub const BAD_CURRENT_DIRECTORY = 703;

/// {Redundant Read} To satisfy a read request, the NT fault-tolerant file system successfully read the requested data from a redundant copy. This was done because the file system encountered a failure on a member of the fault-tolerant volume, but was unable to reassign the failing area of the device.
pub const FT_READ_RECOVERY_FROM_BACKUP = 704;

/// {Redundant Write} To satisfy a write request, the NT fault-tolerant file system successfully wrote a redundant copy of the information. This was done because the file system encountered a failure on a member of the fault-tolerant volume, but was not able to reassign the failing area of the device.
pub const FT_WRITE_RECOVERY = 705;

/// {Machine Type Mismatch} The image file %hs is valid, but is for a machine type other than the current machine. Select OK to continue, or CANCEL to fail the DLL load.
pub const IMAGE_MACHINE_TYPE_MISMATCH = 706;

/// {Partial Data Received} The network transport returned partial data to its client. The remaining data will be sent later.
pub const RECEIVE_PARTIAL = 707;

/// {Expedited Data Received} The network transport returned data to its client that was marked as expedited by the remote system.
pub const RECEIVE_EXPEDITED = 708;

/// {Partial Expedited Data Received} The network transport returned partial data to its client and this data was marked as expedited by the remote system. The remaining data will be sent later.
pub const RECEIVE_PARTIAL_EXPEDITED = 709;

/// {TDI Event Done} The TDI indication has completed successfully.
pub const EVENT_DONE = 710;

/// {TDI Event Pending} The TDI indication has entered the pending state.
pub const EVENT_PENDING = 711;

/// Checking file system on %wZ.
pub const CHECKING_FILE_SYSTEM = 712;

/// {Fatal Application Exit} %hs.
pub const FATAL_APP_EXIT = 713;

/// The specified registry key is referenced by a predefined handle.
pub const PREDEFINED_HANDLE = 714;

/// {Page Unlocked} The page protection of a locked page was changed to 'No Access' and the page was unlocked from memory and from the process.
pub const WAS_UNLOCKED = 715;

/// %hs
pub const SERVICE_NOTIFICATION = 716;

/// {Page Locked} One of the pages to lock was already locked.
pub const WAS_LOCKED = 717;

/// Application popup: %1 : %2
pub const LOG_HARD_ERROR = 718;

/// ERROR_ALREADY_WIN32
pub const ALREADY_WIN32 = 719;

/// {Machine Type Mismatch} The image file %hs is valid, but is for a machine type other than the current machine.
pub const IMAGE_MACHINE_TYPE_MISMATCH_EXE = 720;

/// A yield execution was performed and no thread was available to run.
pub const NO_YIELD_PERFORMED = 721;

/// The resumable flag to a timer API was ignored.
pub const TIMER_RESUME_IGNORED = 722;

/// The arbiter has deferred arbitration of these resources to its parent.
pub const ARBITRATION_UNHANDLED = 723;

/// The inserted CardBus device cannot be started because of a configuration error on "%hs".
pub const CARDBUS_NOT_SUPPORTED = 724;

/// The CPUs in this multiprocessor system are not all the same revision level. To use all processors the operating system restricts itself to the features of the least capable processor in the system. Should problems occur with this system, contact the CPU manufacturer to see if this mix of processors is supported.
pub const MP_PROCESSOR_MISMATCH = 725;

/// The system was put into hibernation.
pub const HIBERNATED = 726;

/// The system was resumed from hibernation.
pub const RESUME_HIBERNATION = 727;

/// Windows has detected that the system firmware (BIOS) was updated [previous firmware date = %2, current firmware date %3].
pub const FIRMWARE_UPDATED = 728;

/// A device driver is leaking locked I/O pages causing system degradation. The system has automatically enabled tracking code in order to try and catch the culprit.
pub const DRIVERS_LEAKING_LOCKED_PAGES = 729;

/// The system has awoken.
pub const WAKE_SYSTEM = 730;

/// ERROR_WAIT_1
pub const WAIT_1 = 731;

/// ERROR_WAIT_2
pub const WAIT_2 = 732;

/// ERROR_WAIT_3
pub const WAIT_3 = 733;

/// ERROR_WAIT_63
pub const WAIT_63 = 734;

/// ERROR_ABANDONED_WAIT_0
pub const ABANDONED_WAIT_0 = 735;

/// ERROR_ABANDONED_WAIT_63
pub const ABANDONED_WAIT_63 = 736;

/// ERROR_USER_APC
pub const USER_APC = 737;

/// ERROR_KERNEL_APC
pub const KERNEL_APC = 738;

/// ERROR_ALERTED
pub const ALERTED = 739;

/// The requested operation requires elevation.
pub const ELEVATION_REQUIRED = 740;

/// A reparse should be performed by the Object Manager since the name of the file resulted in a symbolic link.
pub const REPARSE = 741;

/// An open/create operation completed while an oplock break is underway.
pub const OPLOCK_BREAK_IN_PROGRESS = 742;

/// A new volume has been mounted by a file system.
pub const VOLUME_MOUNTED = 743;

/// This success level status indicates that the transaction state already exists for the registry sub-tree, but that a transaction commit was previously aborted. The commit has now been completed.
pub const RXACT_COMMITTED = 744;

/// This indicates that a notify change request has been completed due to closing the handle which made the notify change request.
pub const NOTIFY_CLEANUP = 745;

/// {Connect Failure on Primary Transport} An attempt was made to connect to the remote server %hs on the primary transport, but the connection failed. The computer WAS able to connect on a secondary transport.
pub const PRIMARY_TRANSPORT_CONNECT_FAILED = 746;

/// Page fault was a transition fault.
pub const PAGE_FAULT_TRANSITION = 747;

/// Page fault was a demand zero fault.
pub const PAGE_FAULT_DEMAND_ZERO = 748;

/// Page fault was a demand zero fault.
pub const PAGE_FAULT_COPY_ON_WRITE = 749;

/// Page fault was a demand zero fault.
pub const PAGE_FAULT_GUARD_PAGE = 750;

/// Page fault was satisfied by reading from a secondary storage device.
pub const PAGE_FAULT_PAGING_FILE = 751;

/// Cached page was locked during operation.
pub const CACHE_PAGE_LOCKED = 752;

/// Crash dump exists in paging file.
pub const CRASH_DUMP = 753;

/// Specified buffer contains all zeros.
pub const BUFFER_ALL_ZEROS = 754;

/// A reparse should be performed by the Object Manager since the name of the file resulted in a symbolic link.
pub const REPARSE_OBJECT = 755;

/// The device has succeeded a query-stop and its resource requirements have changed.
pub const RESOURCE_REQUIREMENTS_CHANGED = 756;

/// The translator has translated these resources into the global space and no further translations should be performed.
pub const TRANSLATION_COMPLETE = 757;

/// A process being terminated has no threads to terminate.
pub const NOTHING_TO_TERMINATE = 758;

/// The specified process is not part of a job.
pub const PROCESS_NOT_IN_JOB = 759;

/// The specified process is part of a job.
pub const PROCESS_IN_JOB = 760;

/// {Volume Shadow Copy Service} The system is now ready for hibernation.
pub const VOLSNAP_HIBERNATE_READY = 761;

/// A file system or file system filter driver has successfully completed an FsFilter operation.
pub const FSFILTER_OP_COMPLETED_SUCCESSFULLY = 762;

/// The specified interrupt vector was already connected.
pub const INTERRUPT_VECTOR_ALREADY_CONNECTED = 763;

/// The specified interrupt vector is still connected.
pub const INTERRUPT_STILL_CONNECTED = 764;

/// An operation is blocked waiting for an oplock.
pub const WAIT_FOR_OPLOCK = 765;

/// Debugger handled exception.
pub const DBG_EXCEPTION_HANDLED = 766;

/// Debugger continued.
pub const DBG_CONTINUE = 767;

/// An exception occurred in a user mode callback and the kernel callback frame should be removed.
pub const CALLBACK_POP_STACK = 768;

/// Compression is disabled for this volume.
pub const COMPRESSION_DISABLED = 769;

/// The data provider cannot fetch backwards through a result set.
pub const CANTFETCHBACKWARDS = 770;

/// The data provider cannot scroll backwards through a result set.
pub const CANTSCROLLBACKWARDS = 771;

/// The data provider requires that previously fetched data is released before asking for more data.
pub const ROWSNOTRELEASED = 772;

/// The data provider was not able to interpret the flags set for a column binding in an accessor.
pub const BAD_ACCESSOR_FLAGS = 773;

/// One or more errors occurred while processing the request.
pub const ERRORS_ENCOUNTERED = 774;

/// The implementation is not capable of performing the request.
pub const NOT_CAPABLE = 775;

/// The client of a component requested an operation which is not valid given the state of the component instance.
pub const REQUEST_OUT_OF_SEQUENCE = 776;

/// A version number could not be parsed.
pub const VERSION_PARSE_ERROR = 777;

/// The iterator's start position is invalid.
pub const BADSTARTPOSITION = 778;

/// The hardware has reported an uncorrectable memory error.
pub const MEMORY_HARDWARE = 779;

/// The attempted operation required self healing to be enabled.
pub const DISK_REPAIR_DISABLED = 780;

/// The Desktop heap encountered an error while allocating session memory. There is more information in the system event log.
pub const INSUFFICIENT_RESOURCE_FOR_SPECIFIED_SHARED_SECTION_SIZE = 781;

/// The system power state is transitioning from %2 to %3.
pub const SYSTEM_POWERSTATE_TRANSITION = 782;

/// The system power state is transitioning from %2 to %3 but could enter %4.
pub const SYSTEM_POWERSTATE_COMPLEX_TRANSITION = 783;

/// A thread is getting dispatched with MCA EXCEPTION because of MCA.
pub const MCA_EXCEPTION = 784;

/// Access to %1 is monitored by policy rule %2.
pub const ACCESS_AUDIT_BY_POLICY = 785;

/// Access to %1 has been restricted by your Administrator by policy rule %2.
pub const ACCESS_DISABLED_NO_SAFER_UI_BY_POLICY = 786;

/// A valid hibernation file has been invalidated and should be abandoned.
pub const ABANDON_HIBERFILE = 787;

/// {Delayed Write Failed} Windows was unable to save all the data for the file %hs; the data has been lost. This error may be caused by network connectivity issues. Please try to save this file elsewhere.
pub const LOST_WRITEBEHIND_DATA_NETWORK_DISCONNECTED = 788;

/// {Delayed Write Failed} Windows was unable to save all the data for the file %hs; the data has been lost. This error was returned by the server on which the file exists. Please try to save this file elsewhere.
pub const LOST_WRITEBEHIND_DATA_NETWORK_SERVER_ERROR = 789;

/// {Delayed Write Failed} Windows was unable to save all the data for the file %hs; the data has been lost. This error may be caused if the device has been removed or the media is write-protected.
pub const LOST_WRITEBEHIND_DATA_LOCAL_DISK_ERROR = 790;

/// The resources required for this device conflict with the MCFG table.
pub const BAD_MCFG_TABLE = 791;

/// The volume repair could not be performed while it is online. Please schedule to take the volume offline so that it can be repaired.
pub const DISK_REPAIR_REDIRECTED = 792;

/// The volume repair was not successful.
pub const DISK_REPAIR_UNSUCCESSFUL = 793;

/// One of the volume corruption logs is full. Further corruptions that may be detected won't be logged.
pub const CORRUPT_LOG_OVERFULL = 794;

/// One of the volume corruption logs is internally corrupted and needs to be recreated. The volume may contain undetected corruptions and must be scanned.
pub const CORRUPT_LOG_CORRUPTED = 795;

/// One of the volume corruption logs is unavailable for being operated on.
pub const CORRUPT_LOG_UNAVAILABLE = 796;

/// One of the volume corruption logs was deleted while still having corruption records in them. The volume contains detected corruptions and must be scanned.
pub const CORRUPT_LOG_DELETED_FULL = 797;

/// One of the volume corruption logs was cleared by chkdsk and no longer contains real corruptions.
pub const CORRUPT_LOG_CLEARED = 798;

/// Orphaned files exist on the volume but could not be recovered because no more new names could be created in the recovery directory. Files must be moved from the recovery directory.
pub const ORPHAN_NAME_EXHAUSTED = 799;

/// The oplock that was associated with this handle is now associated with a different handle.
pub const OPLOCK_SWITCHED_TO_NEW_HANDLE = 800;

/// An oplock of the requested level cannot be granted. An oplock of a lower level may be available.
pub const CANNOT_GRANT_REQUESTED_OPLOCK = 801;

/// The operation did not complete successfully because it would cause an oplock to be broken. The caller has requested that existing oplocks not be broken.
pub const CANNOT_BREAK_OPLOCK = 802;

/// The handle with which this oplock was associated has been closed. The oplock is now broken.
pub const OPLOCK_HANDLE_CLOSED = 803;

/// The specified access control entry (ACE) does not contain a condition.
pub const NO_ACE_CONDITION = 804;

/// The specified access control entry (ACE) contains an invalid condition.
pub const INVALID_ACE_CONDITION = 805;

/// Access to the specified file handle has been revoked.
pub const FILE_HANDLE_REVOKED = 806;

/// An image file was mapped at a different address from the one specified in the image file but fixups will still be automatically performed on the image.
pub const IMAGE_AT_DIFFERENT_BASE = 807;

/// Access to the extended attribute was denied.
pub const EA_ACCESS_DENIED = 994;

/// The I/O operation has been aborted because of either a thread exit or an application request.
pub const OPERATION_ABORTED = 995;

/// Overlapped I/O event is not in a signaled state.
pub const IO_INCOMPLETE = 996;

/// Overlapped I/O operation is in progress.
pub const IO_PENDING = 997;

/// Invalid access to memory location.
pub const NOACCESS = 998;

/// Error performing inpage operation.
pub const SWAPERROR = 999;

/// Recursion too deep; the stack overflowed.
pub const STACK_OVERFLOW = 1001;

/// The window cannot act on the sent message.
pub const INVALID_MESSAGE = 1002;

/// Cannot complete this function.
pub const CAN_NOT_COMPLETE = 1003;

/// Invalid flags.
pub const INVALID_FLAGS = 1004;

/// The volume does not contain a recognized file system. Please make sure that all required file system drivers are loaded and that the volume is not corrupted.
pub const UNRECOGNIZED_VOLUME = 1005;

/// The volume for a file has been externally altered so that the opened file is no longer valid.
pub const FILE_INVALID = 1006;

/// The requested operation cannot be performed in full-screen mode.
pub const FULLSCREEN_MODE = 1007;

/// An attempt was made to reference a token that does not exist.
pub const NO_TOKEN = 1008;

/// The configuration registry database is corrupt.
pub const BADDB = 1009;

/// The configuration registry key is invalid.
pub const BADKEY = 1010;

/// The configuration registry key could not be opened.
pub const CANTOPEN = 1011;

/// The configuration registry key could not be read.
pub const CANTREAD = 1012;

/// The configuration registry key could not be written.
pub const CANTWRITE = 1013;

/// One of the files in the registry database had to be recovered by use of a log or alternate copy. The recovery was successful.
pub const REGISTRY_RECOVERED = 1014;

/// The registry is corrupted. The structure of one of the files containing registry data is corrupted, or the system's memory image of the file is corrupted, or the file could not be recovered because the alternate copy or log was absent or corrupted.
pub const REGISTRY_CORRUPT = 1015;

/// An I/O operation initiated by the registry failed unrecoverably. The registry could not read in, or write out, or flush, one of the files that contain the system's image of the registry.
pub const REGISTRY_IO_FAILED = 1016;

/// The system has attempted to load or restore a file into the registry, but the specified file is not in a registry file format.
pub const NOT_REGISTRY_FILE = 1017;

/// Illegal operation attempted on a registry key that has been marked for deletion.
pub const KEY_DELETED = 1018;

/// System could not allocate the required space in a registry log.
pub const NO_LOG_SPACE = 1019;

/// Cannot create a symbolic link in a registry key that already has subkeys or values.
pub const KEY_HAS_CHILDREN = 1020;

/// Cannot create a stable subkey under a volatile parent key.
pub const CHILD_MUST_BE_VOLATILE = 1021;

/// A notify change request is being completed and the information is not being returned in the caller's buffer. The caller now needs to enumerate the files to find the changes.
pub const NOTIFY_ENUM_DIR = 1022;

/// A stop control has been sent to a service that other running services are dependent on.
pub const DEPENDENT_SERVICES_RUNNING = 1051;

/// The requested control is not valid for this service.
pub const INVALID_SERVICE_CONTROL = 1052;

/// The service did not respond to the start or control request in a timely fashion.
pub const SERVICE_REQUEST_TIMEOUT = 1053;

/// A thread could not be created for the service.
pub const SERVICE_NO_THREAD = 1054;

/// The service database is locked.
pub const SERVICE_DATABASE_LOCKED = 1055;

/// An instance of the service is already running.
pub const SERVICE_ALREADY_RUNNING = 1056;

/// The account name is invalid or does not exist, or the password is invalid for the account name specified.
pub const INVALID_SERVICE_ACCOUNT = 1057;

/// The service cannot be started, either because it is disabled or because it has no enabled devices associated with it.
pub const SERVICE_DISABLED = 1058;

/// Circular service dependency was specified.
pub const CIRCULAR_DEPENDENCY = 1059;

/// The specified service does not exist as an installed service.
pub const SERVICE_DOES_NOT_EXIST = 1060;

/// The service cannot accept control messages at this time.
pub const SERVICE_CANNOT_ACCEPT_CTRL = 1061;

/// The service has not been started.
pub const SERVICE_NOT_ACTIVE = 1062;

/// The service process could not connect to the service controller.
pub const FAILED_SERVICE_CONTROLLER_CONNECT = 1063;

/// An exception occurred in the service when handling the control request.
pub const EXCEPTION_IN_SERVICE = 1064;

/// The database specified does not exist.
pub const DATABASE_DOES_NOT_EXIST = 1065;

/// The service has returned a service-specific error code.
pub const SERVICE_SPECIFIC_ERROR = 1066;

/// The process terminated unexpectedly.
pub const PROCESS_ABORTED = 1067;

/// The dependency service or group failed to start.
pub const SERVICE_DEPENDENCY_FAIL = 1068;

/// The service did not start due to a logon failure.
pub const SERVICE_LOGON_FAILED = 1069;

/// After starting, the service hung in a start-pending state.
pub const SERVICE_START_HANG = 1070;

/// The specified service database lock is invalid.
pub const INVALID_SERVICE_LOCK = 1071;

/// The specified service has been marked for deletion.
pub const SERVICE_MARKED_FOR_DELETE = 1072;

/// The specified service already exists.
pub const SERVICE_EXISTS = 1073;

/// The system is currently running with the last-known-good configuration.
pub const ALREADY_RUNNING_LKG = 1074;

/// The dependency service does not exist or has been marked for deletion.
pub const SERVICE_DEPENDENCY_DELETED = 1075;

/// The current boot has already been accepted for use as the last-known-good control set.
pub const BOOT_ALREADY_ACCEPTED = 1076;

/// No attempts to start the service have been made since the last boot.
pub const SERVICE_NEVER_STARTED = 1077;

/// The name is already in use as either a service name or a service display name.
pub const DUPLICATE_SERVICE_NAME = 1078;

/// The account specified for this service is different from the account specified for other services running in the same process.
pub const DIFFERENT_SERVICE_ACCOUNT = 1079;

/// Failure actions can only be set for Win32 services, not for drivers.
pub const CANNOT_DETECT_DRIVER_FAILURE = 1080;

/// This service runs in the same process as the service control manager. Therefore, the service control manager cannot take action if this service's process terminates unexpectedly.
pub const CANNOT_DETECT_PROCESS_ABORT = 1081;

/// No recovery program has been configured for this service.
pub const NO_RECOVERY_PROGRAM = 1082;

/// The executable program that this service is configured to run in does not implement the service.
pub const SERVICE_NOT_IN_EXE = 1083;

/// This service cannot be started in Safe Mode.
pub const NOT_SAFEBOOT_SERVICE = 1084;

/// The physical end of the tape has been reached.
pub const END_OF_MEDIA = 1100;

/// A tape access reached a filemark.
pub const FILEMARK_DETECTED = 1101;

/// The beginning of the tape or a partition was encountered.
pub const BEGINNING_OF_MEDIA = 1102;

/// A tape access reached the end of a set of files.
pub const SETMARK_DETECTED = 1103;

/// No more data is on the tape.
pub const NO_DATA_DETECTED = 1104;

/// Tape could not be partitioned.
pub const PARTITION_FAILURE = 1105;

/// When accessing a new tape of a multivolume partition, the current block size is incorrect.
pub const INVALID_BLOCK_LENGTH = 1106;

/// Tape partition information could not be found when loading a tape.
pub const DEVICE_NOT_PARTITIONED = 1107;

/// Unable to lock the media eject mechanism.
pub const UNABLE_TO_LOCK_MEDIA = 1108;

/// Unable to unload the media.
pub const UNABLE_TO_UNLOAD_MEDIA = 1109;

/// The media in the drive may have changed.
pub const MEDIA_CHANGED = 1110;

/// The I/O bus was reset.
pub const BUS_RESET = 1111;

/// No media in drive.
pub const NO_MEDIA_IN_DRIVE = 1112;

/// No mapping for the Unicode character exists in the target multi-byte code page.
pub const NO_UNICODE_TRANSLATION = 1113;

/// A dynamic link library (DLL) initialization routine failed.
pub const DLL_INIT_FAILED = 1114;

/// A system shutdown is in progress.
pub const SHUTDOWN_IN_PROGRESS = 1115;

/// Unable to abort the system shutdown because no shutdown was in progress.
pub const NO_SHUTDOWN_IN_PROGRESS = 1116;

/// The request could not be performed because of an I/O device error.
pub const IO_DEVICE = 1117;

/// No serial device was successfully initialized. The serial driver will unload.
pub const SERIAL_NO_DEVICE = 1118;

/// Unable to open a device that was sharing an interrupt request (IRQ) with other devices. At least one other device that uses that IRQ was already opened.
pub const IRQ_BUSY = 1119;

/// A serial I/O operation was completed by another write to the serial port. The IOCTL_SERIAL_XOFF_COUNTER reached zero.)
pub const MORE_WRITES = 1120;

/// A serial I/O operation completed because the timeout period expired. The IOCTL_SERIAL_XOFF_COUNTER did not reach zero.)
pub const COUNTER_TIMEOUT = 1121;

/// No ID address mark was found on the floppy disk.
pub const FLOPPY_ID_MARK_NOT_FOUND = 1122;

/// Mismatch between the floppy disk sector ID field and the floppy disk controller track address.
pub const FLOPPY_WRONG_CYLINDER = 1123;

/// The floppy disk controller reported an error that is not recognized by the floppy disk driver.
pub const FLOPPY_UNKNOWN_ERROR = 1124;

/// The floppy disk controller returned inconsistent results in its registers.
pub const FLOPPY_BAD_REGISTERS = 1125;

/// While accessing the hard disk, a recalibrate operation failed, even after retries.
pub const DISK_RECALIBRATE_FAILED = 1126;

/// While accessing the hard disk, a disk operation failed even after retries.
pub const DISK_OPERATION_FAILED = 1127;

/// While accessing the hard disk, a disk controller reset was needed, but even that failed.
pub const DISK_RESET_FAILED = 1128;

/// Physical end of tape encountered.
pub const EOM_OVERFLOW = 1129;

/// Not enough server storage is available to process this command.
pub const NOT_ENOUGH_SERVER_MEMORY = 1130;

/// A potential deadlock condition has been detected.
pub const POSSIBLE_DEADLOCK = 1131;

/// The base address or the file offset specified does not have the proper alignment.
pub const MAPPED_ALIGNMENT = 1132;

/// An attempt to change the system power state was vetoed by another application or driver.
pub const SET_POWER_STATE_VETOED = 1140;

/// The system BIOS failed an attempt to change the system power state.
pub const SET_POWER_STATE_FAILED = 1141;

/// An attempt was made to create more links on a file than the file system supports.
pub const TOO_MANY_LINKS = 1142;

/// The specified program requires a newer version of Windows.
pub const OLD_WIN_VERSION = 1150;

/// The specified program is not a Windows or MS-DOS program.
pub const APP_WRONG_OS = 1151;

/// Cannot start more than one instance of the specified program.
pub const SINGLE_INSTANCE_APP = 1152;

/// The specified program was written for an earlier version of Windows.
pub const RMODE_APP = 1153;

/// One of the library files needed to run this application is damaged.
pub const INVALID_DLL = 1154;

/// No application is associated with the specified file for this operation.
pub const NO_ASSOCIATION = 1155;

/// An error occurred in sending the command to the application.
pub const DDE_FAIL = 1156;

/// One of the library files needed to run this application cannot be found.
pub const DLL_NOT_FOUND = 1157;

/// The current process has used all of its system allowance of handles for Window Manager objects.
pub const NO_MORE_USER_HANDLES = 1158;

/// The message can be used only with synchronous operations.
pub const MESSAGE_SYNC_ONLY = 1159;

/// The indicated source element has no media.
pub const SOURCE_ELEMENT_EMPTY = 1160;

/// The indicated destination element already contains media.
pub const DESTINATION_ELEMENT_FULL = 1161;

/// The indicated element does not exist.
pub const ILLEGAL_ELEMENT_ADDRESS = 1162;

/// The indicated element is part of a magazine that is not present.
pub const MAGAZINE_NOT_PRESENT = 1163;

/// The indicated device requires reinitialization due to hardware errors.
pub const DEVICE_REINITIALIZATION_NEEDED = 1164;

/// The device has indicated that cleaning is required before further operations are attempted.
pub const DEVICE_REQUIRES_CLEANING = 1165;

/// The device has indicated that its door is open.
pub const DEVICE_DOOR_OPEN = 1166;

/// The device is not connected.
pub const DEVICE_NOT_CONNECTED = 1167;

/// Element not found.
pub const NOT_FOUND = 1168;

/// There was no match for the specified key in the index.
pub const NO_MATCH = 1169;

/// The property set specified does not exist on the object.
pub const SET_NOT_FOUND = 1170;

/// The point passed to GetMouseMovePoints is not in the buffer.
pub const POINT_NOT_FOUND = 1171;

/// The tracking (workstation) service is not running.
pub const NO_TRACKING_SERVICE = 1172;

/// The Volume ID could not be found.
pub const NO_VOLUME_ID = 1173;

/// Unable to remove the file to be replaced.
pub const UNABLE_TO_REMOVE_REPLACED = 1175;

/// Unable to move the replacement file to the file to be replaced. The file to be replaced has retained its original name.
pub const UNABLE_TO_MOVE_REPLACEMENT = 1176;

/// Unable to move the replacement file to the file to be replaced. The file to be replaced has been renamed using the backup name.
pub const UNABLE_TO_MOVE_REPLACEMENT_2 = 1177;

/// The volume change journal is being deleted.
pub const JOURNAL_DELETE_IN_PROGRESS = 1178;

/// The volume change journal is not active.
pub const JOURNAL_NOT_ACTIVE = 1179;

/// A file was found, but it may not be the correct file.
pub const POTENTIAL_FILE_FOUND = 1180;

/// The journal entry has been deleted from the journal.
pub const JOURNAL_ENTRY_DELETED = 1181;

/// A system shutdown has already been scheduled.
pub const SHUTDOWN_IS_SCHEDULED = 1190;

/// The system shutdown cannot be initiated because there are other users logged on to the computer.
pub const SHUTDOWN_USERS_LOGGED_ON = 1191;

/// The specified device name is invalid.
pub const BAD_DEVICE = 1200;

/// The device is not currently connected but it is a remembered connection.
pub const CONNECTION_UNAVAIL = 1201;

/// The local device name has a remembered connection to another network resource.
pub const DEVICE_ALREADY_REMEMBERED = 1202;

/// The network path was either typed incorrectly, does not exist, or the network provider is not currently available. Please try retyping the path or contact your network administrator.
pub const NO_NET_OR_BAD_PATH = 1203;

/// The specified network provider name is invalid.
pub const BAD_PROVIDER = 1204;

/// Unable to open the network connection profile.
pub const CANNOT_OPEN_PROFILE = 1205;

/// The network connection profile is corrupted.
pub const BAD_PROFILE = 1206;

/// Cannot enumerate a noncontainer.
pub const NOT_CONTAINER = 1207;

/// An extended error has occurred.
pub const EXTENDED_ERROR = 1208;

/// The format of the specified group name is invalid.
pub const INVALID_GROUPNAME = 1209;

/// The format of the specified computer name is invalid.
pub const INVALID_COMPUTERNAME = 1210;

/// The format of the specified event name is invalid.
pub const INVALID_EVENTNAME = 1211;

/// The format of the specified domain name is invalid.
pub const INVALID_DOMAINNAME = 1212;

/// The format of the specified service name is invalid.
pub const INVALID_SERVICENAME = 1213;

/// The format of the specified network name is invalid.
pub const INVALID_NETNAME = 1214;

/// The format of the specified share name is invalid.
pub const INVALID_SHARENAME = 1215;

/// The format of the specified password is invalid.
pub const INVALID_PASSWORDNAME = 1216;

/// The format of the specified message name is invalid.
pub const INVALID_MESSAGENAME = 1217;

/// The format of the specified message destination is invalid.
pub const INVALID_MESSAGEDEST = 1218;

/// Multiple connections to a server or shared resource by the same user, using more than one user name, are not allowed. Disconnect all previous connections to the server or shared resource and try again.
pub const SESSION_CREDENTIAL_CONFLICT = 1219;

/// An attempt was made to establish a session to a network server, but there are already too many sessions established to that server.
pub const REMOTE_SESSION_LIMIT_EXCEEDED = 1220;

/// The workgroup or domain name is already in use by another computer on the network.
pub const DUP_DOMAINNAME = 1221;

/// The network is not present or not started.
pub const NO_NETWORK = 1222;

/// The operation was canceled by the user.
pub const CANCELLED = 1223;

/// The requested operation cannot be performed on a file with a user-mapped section open.
pub const USER_MAPPED_FILE = 1224;

/// The remote computer refused the network connection.
pub const CONNECTION_REFUSED = 1225;

/// The network connection was gracefully closed.
pub const GRACEFUL_DISCONNECT = 1226;

/// The network transport endpoint already has an address associated with it.
pub const ADDRESS_ALREADY_ASSOCIATED = 1227;

/// An address has not yet been associated with the network endpoint.
pub const ADDRESS_NOT_ASSOCIATED = 1228;

/// An operation was attempted on a nonexistent network connection.
pub const CONNECTION_INVALID = 1229;

/// An invalid operation was attempted on an active network connection.
pub const CONNECTION_ACTIVE = 1230;

/// The network location cannot be reached. For information about network troubleshooting, see Windows Help.
pub const NETWORK_UNREACHABLE = 1231;

/// The network location cannot be reached. For information about network troubleshooting, see Windows Help.
pub const HOST_UNREACHABLE = 1232;

/// The network location cannot be reached. For information about network troubleshooting, see Windows Help.
pub const PROTOCOL_UNREACHABLE = 1233;

/// No service is operating at the destination network endpoint on the remote system.
pub const PORT_UNREACHABLE = 1234;

/// The request was aborted.
pub const REQUEST_ABORTED = 1235;

/// The network connection was aborted by the local system.
pub const CONNECTION_ABORTED = 1236;

/// The operation could not be completed. A retry should be performed.
pub const RETRY = 1237;

/// A connection to the server could not be made because the limit on the number of concurrent connections for this account has been reached.
pub const CONNECTION_COUNT_LIMIT = 1238;

/// Attempting to log in during an unauthorized time of day for this account.
pub const LOGIN_TIME_RESTRICTION = 1239;

/// The account is not authorized to log in from this station.
pub const LOGIN_WKSTA_RESTRICTION = 1240;

/// The network address could not be used for the operation requested.
pub const INCORRECT_ADDRESS = 1241;

/// The service is already registered.
pub const ALREADY_REGISTERED = 1242;

/// The specified service does not exist.
pub const SERVICE_NOT_FOUND = 1243;

/// The operation being requested was not performed because the user has not been authenticated.
pub const NOT_AUTHENTICATED = 1244;

/// The operation being requested was not performed because the user has not logged on to the network. The specified service does not exist.
pub const NOT_LOGGED_ON = 1245;

/// Continue with work in progress.
pub const CONTINUE = 1246;

/// An attempt was made to perform an initialization operation when initialization has already been completed.
pub const ALREADY_INITIALIZED = 1247;

/// No more local devices.
pub const NO_MORE_DEVICES = 1248;

/// The specified site does not exist.
pub const NO_SUCH_SITE = 1249;

/// A domain controller with the specified name already exists.
pub const DOMAIN_CONTROLLER_EXISTS = 1250;

/// This operation is supported only when you are connected to the server.
pub const ONLY_IF_CONNECTED = 1251;

/// The group policy framework should call the extension even if there are no changes.
pub const OVERRIDE_NOCHANGES = 1252;

/// The specified user does not have a valid profile.
pub const BAD_USER_PROFILE = 1253;

/// This operation is not supported on a computer running Windows Server 2003 for Small Business Server.
pub const NOT_SUPPORTED_ON_SBS = 1254;

/// The server machine is shutting down.
pub const SERVER_SHUTDOWN_IN_PROGRESS = 1255;

/// The remote system is not available. For information about network troubleshooting, see Windows Help.
pub const HOST_DOWN = 1256;

/// The security identifier provided is not from an account domain.
pub const NON_ACCOUNT_SID = 1257;

/// The security identifier provided does not have a domain component.
pub const NON_DOMAIN_SID = 1258;

/// AppHelp dialog canceled thus preventing the application from starting.
pub const APPHELP_BLOCK = 1259;

/// This program is blocked by group policy. For more information, contact your system administrator.
pub const ACCESS_DISABLED_BY_POLICY = 1260;

/// A program attempt to use an invalid register value. Normally caused by an uninitialized register. This error is Itanium specific.
pub const REG_NAT_CONSUMPTION = 1261;

/// The share is currently offline or does not exist.
pub const CSCSHARE_OFFLINE = 1262;

/// The Kerberos protocol encountered an error while validating the KDC certificate during smartcard logon. There is more information in the system event log.
pub const PKINIT_FAILURE = 1263;

/// The Kerberos protocol encountered an error while attempting to utilize the smartcard subsystem.
pub const SMARTCARD_SUBSYSTEM_FAILURE = 1264;

/// The system cannot contact a domain controller to service the authentication request. Please try again later.
pub const DOWNGRADE_DETECTED = 1265;

/// The machine is locked and cannot be shut down without the force option.
pub const MACHINE_LOCKED = 1271;

/// An application-defined callback gave invalid data when called.
pub const CALLBACK_SUPPLIED_INVALID_DATA = 1273;

/// The group policy framework should call the extension in the synchronous foreground policy refresh.
pub const SYNC_FOREGROUND_REFRESH_REQUIRED = 1274;

/// This driver has been blocked from loading.
pub const DRIVER_BLOCKED = 1275;

/// A dynamic link library (DLL) referenced a module that was neither a DLL nor the process's executable image.
pub const INVALID_IMPORT_OF_NON_DLL = 1276;

/// Windows cannot open this program since it has been disabled.
pub const ACCESS_DISABLED_WEBBLADE = 1277;

/// Windows cannot open this program because the license enforcement system has been tampered with or become corrupted.
pub const ACCESS_DISABLED_WEBBLADE_TAMPER = 1278;

/// A transaction recover failed.
pub const RECOVERY_FAILURE = 1279;

/// The current thread has already been converted to a fiber.
pub const ALREADY_FIBER = 1280;

/// The current thread has already been converted from a fiber.
pub const ALREADY_THREAD = 1281;

/// The system detected an overrun of a stack-based buffer in this application. This overrun could potentially allow a malicious user to gain control of this application.
pub const STACK_BUFFER_OVERRUN = 1282;

/// Data present in one of the parameters is more than the function can operate on.
pub const PARAMETER_QUOTA_EXCEEDED = 1283;

/// An attempt to do an operation on a debug object failed because the object is in the process of being deleted.
pub const DEBUGGER_INACTIVE = 1284;

/// An attempt to delay-load a .dll or get a function address in a delay-loaded .dll failed.
pub const DELAY_LOAD_FAILED = 1285;

/// %1 is a 16-bit application. You do not have permissions to execute 16-bit applications. Check your permissions with your system administrator.
pub const VDM_DISALLOWED = 1286;

/// Insufficient information exists to identify the cause of failure.
pub const UNIDENTIFIED_ERROR = 1287;

/// The parameter passed to a C runtime function is incorrect.
pub const INVALID_CRUNTIME_PARAMETER = 1288;

/// The operation occurred beyond the valid data length of the file.
pub const BEYOND_VDL = 1289;

/// The service start failed since one or more services in the same process have an incompatible service SID type setting. A service with restricted service SID type can only coexist in the same process with other services with a restricted SID type. If the service SID type for this service was just configured, the hosting process must be restarted in order to start this service.
/// On Windows Server 2003 and Windows XP, an unrestricted service cannot coexist in the same process with other services. The service with the unrestricted service SID type must be moved to an owned process in order to start this service.
pub const INCOMPATIBLE_SERVICE_SID_TYPE = 1290;

/// The process hosting the driver for this device has been terminated.
pub const DRIVER_PROCESS_TERMINATED = 1291;

/// An operation attempted to exceed an implementation-defined limit.
pub const IMPLEMENTATION_LIMIT = 1292;

/// Either the target process, or the target thread's containing process, is a protected process.
pub const PROCESS_IS_PROTECTED = 1293;

/// The service notification client is lagging too far behind the current state of services in the machine.
pub const SERVICE_NOTIFY_CLIENT_LAGGING = 1294;

/// The requested file operation failed because the storage quota was exceeded. To free up disk space, move files to a different location or delete unnecessary files. For more information, contact your system administrator.
pub const DISK_QUOTA_EXCEEDED = 1295;

/// The requested file operation failed because the storage policy blocks that type of file. For more information, contact your system administrator.
pub const CONTENT_BLOCKED = 1296;

/// A privilege that the service requires to function properly does not exist in the service account configuration. You may use the Services Microsoft Management Console (MMC) snap-in (services.msc) and the Local Security Settings MMC snap-in (secpol.msc) to view the service configuration and the account configuration.
pub const INCOMPATIBLE_SERVICE_PRIVILEGE = 1297;

/// A thread involved in this operation appears to be unresponsive.
pub const APP_HANG = 1298;

/// Indicates a particular Security ID may not be assigned as the label of an object.
pub const INVALID_LABEL = 1299;

/// Not all privileges or groups referenced are assigned to the caller.
pub const NOT_ALL_ASSIGNED = 1300;

/// Some mapping between account names and security IDs was not done.
pub const SOME_NOT_MAPPED = 1301;

/// No system quota limits are specifically set for this account.
pub const NO_QUOTAS_FOR_ACCOUNT = 1302;

/// No encryption key is available. A well-known encryption key was returned.
pub const LOCAL_USER_SESSION_KEY = 1303;

/// The password is too complex to be converted to a LAN Manager password. The LAN Manager password returned is a NULL string.
pub const NULL_LM_PASSWORD = 1304;

/// The revision level is unknown.
pub const UNKNOWN_REVISION = 1305;

/// Indicates two revision levels are incompatible.
pub const REVISION_MISMATCH = 1306;

/// This security ID may not be assigned as the owner of this object.
pub const INVALID_OWNER = 1307;

/// This security ID may not be assigned as the primary group of an object.
pub const INVALID_PRIMARY_GROUP = 1308;

/// An attempt has been made to operate on an impersonation token by a thread that is not currently impersonating a client.
pub const NO_IMPERSONATION_TOKEN = 1309;

/// The group may not be disabled.
pub const CANT_DISABLE_MANDATORY = 1310;

/// There are currently no logon servers available to service the logon request.
pub const NO_LOGON_SERVERS = 1311;

/// A specified logon session does not exist. It may already have been terminated.
pub const NO_SUCH_LOGON_SESSION = 1312;

/// A specified privilege does not exist.
pub const NO_SUCH_PRIVILEGE = 1313;

/// A required privilege is not held by the client.
pub const PRIVILEGE_NOT_HELD = 1314;

/// The name provided is not a properly formed account name.
pub const INVALID_ACCOUNT_NAME = 1315;

/// The specified account already exists.
pub const USER_EXISTS = 1316;

/// The specified account does not exist.
pub const NO_SUCH_USER = 1317;

/// The specified group already exists.
pub const GROUP_EXISTS = 1318;

/// The specified group does not exist.
pub const NO_SUCH_GROUP = 1319;

/// Either the specified user account is already a member of the specified group, or the specified group cannot be deleted because it contains a member.
pub const MEMBER_IN_GROUP = 1320;

/// The specified user account is not a member of the specified group account.
pub const MEMBER_NOT_IN_GROUP = 1321;

/// This operation is disallowed as it could result in an administration account being disabled, deleted or unable to log on.
pub const LAST_ADMIN = 1322;

/// Unable to update the password. The value provided as the current password is incorrect.
pub const WRONG_PASSWORD = 1323;

/// Unable to update the password. The value provided for the new password contains values that are not allowed in passwords.
pub const ILL_FORMED_PASSWORD = 1324;

/// Unable to update the password. The value provided for the new password does not meet the length, complexity, or history requirements of the domain.
pub const PASSWORD_RESTRICTION = 1325;

/// The user name or password is incorrect.
pub const LOGON_FAILURE = 1326;

/// Account restrictions are preventing this user from signing in. For example: blank passwords aren't allowed, sign-in times are limited, or a policy restriction has been enforced.
pub const ACCOUNT_RESTRICTION = 1327;

/// Your account has time restrictions that keep you from signing in right now.
pub const INVALID_LOGON_HOURS = 1328;

/// This user isn't allowed to sign in to this computer.
pub const INVALID_WORKSTATION = 1329;

/// The password for this account has expired.
pub const PASSWORD_EXPIRED = 1330;

/// This user can't sign in because this account is currently disabled.
pub const ACCOUNT_DISABLED = 1331;

/// No mapping between account names and security IDs was done.
pub const NONE_MAPPED = 1332;

/// Too many local user identifiers (LUIDs) were requested at one time.
pub const TOO_MANY_LUIDS_REQUESTED = 1333;

/// No more local user identifiers (LUIDs) are available.
pub const LUIDS_EXHAUSTED = 1334;

/// The subauthority part of a security ID is invalid for this particular use.
pub const INVALID_SUB_AUTHORITY = 1335;

/// The access control list (ACL) structure is invalid.
pub const INVALID_ACL = 1336;

/// The security ID structure is invalid.
pub const INVALID_SID = 1337;

/// The security descriptor structure is invalid.
pub const INVALID_SECURITY_DESCR = 1338;

/// The inherited access control list (ACL) or access control entry (ACE) could not be built.
pub const BAD_INHERITANCE_ACL = 1340;

/// The server is currently disabled.
pub const SERVER_DISABLED = 1341;

/// The server is currently enabled.
pub const SERVER_NOT_DISABLED = 1342;

/// The value provided was an invalid value for an identifier authority.
pub const INVALID_ID_AUTHORITY = 1343;

/// No more memory is available for security information updates.
pub const ALLOTTED_SPACE_EXCEEDED = 1344;

/// The specified attributes are invalid, or incompatible with the attributes for the group as a whole.
pub const INVALID_GROUP_ATTRIBUTES = 1345;

/// Either a required impersonation level was not provided, or the provided impersonation level is invalid.
pub const BAD_IMPERSONATION_LEVEL = 1346;

/// Cannot open an anonymous level security token.
pub const CANT_OPEN_ANONYMOUS = 1347;

/// The validation information class requested was invalid.
pub const BAD_VALIDATION_CLASS = 1348;

/// The type of the token is inappropriate for its attempted use.
pub const BAD_TOKEN_TYPE = 1349;

/// Unable to perform a security operation on an object that has no associated security.
pub const NO_SECURITY_ON_OBJECT = 1350;

/// Configuration information could not be read from the domain controller, either because the machine is unavailable, or access has been denied.
pub const CANT_ACCESS_DOMAIN_INFO = 1351;

/// The security account manager (SAM) or local security authority (LSA) server was in the wrong state to perform the security operation.
pub const INVALID_SERVER_STATE = 1352;

/// The domain was in the wrong state to perform the security operation.
pub const INVALID_DOMAIN_STATE = 1353;

/// This operation is only allowed for the Primary Domain Controller of the domain.
pub const INVALID_DOMAIN_ROLE = 1354;

/// The specified domain either does not exist or could not be contacted.
pub const NO_SUCH_DOMAIN = 1355;

/// The specified domain already exists.
pub const DOMAIN_EXISTS = 1356;

/// An attempt was made to exceed the limit on the number of domains per server.
pub const DOMAIN_LIMIT_EXCEEDED = 1357;

/// Unable to complete the requested operation because of either a catastrophic media failure or a data structure corruption on the disk.
pub const INTERNAL_DB_CORRUPTION = 1358;

/// An internal error occurred.
pub const INTERNAL_ERROR = 1359;

/// Generic access types were contained in an access mask which should already be mapped to nongeneric types.
pub const GENERIC_NOT_MAPPED = 1360;

/// A security descriptor is not in the right format (absolute or self-relative).
pub const BAD_DESCRIPTOR_FORMAT = 1361;

/// The requested action is restricted for use by logon processes only. The calling process has not registered as a logon process.
pub const NOT_LOGON_PROCESS = 1362;

/// Cannot start a new logon session with an ID that is already in use.
pub const LOGON_SESSION_EXISTS = 1363;

/// A specified authentication package is unknown.
pub const NO_SUCH_PACKAGE = 1364;

/// The logon session is not in a state that is consistent with the requested operation.
pub const BAD_LOGON_SESSION_STATE = 1365;

/// The logon session ID is already in use.
pub const LOGON_SESSION_COLLISION = 1366;

/// A logon request contained an invalid logon type value.
pub const INVALID_LOGON_TYPE = 1367;

/// Unable to impersonate using a named pipe until data has been read from that pipe.
pub const CANNOT_IMPERSONATE = 1368;

/// The transaction state of a registry subtree is incompatible with the requested operation.
pub const RXACT_INVALID_STATE = 1369;

/// An internal security database corruption has been encountered.
pub const RXACT_COMMIT_FAILURE = 1370;

/// Cannot perform this operation on built-in accounts.
pub const SPECIAL_ACCOUNT = 1371;

/// Cannot perform this operation on this built-in special group.
pub const SPECIAL_GROUP = 1372;

/// Cannot perform this operation on this built-in special user.
pub const SPECIAL_USER = 1373;

/// The user cannot be removed from a group because the group is currently the user's primary group.
pub const MEMBERS_PRIMARY_GROUP = 1374;

/// The token is already in use as a primary token.
pub const TOKEN_ALREADY_IN_USE = 1375;

/// The specified local group does not exist.
pub const NO_SUCH_ALIAS = 1376;

/// The specified account name is not a member of the group.
pub const MEMBER_NOT_IN_ALIAS = 1377;

/// The specified account name is already a member of the group.
pub const MEMBER_IN_ALIAS = 1378;

/// The specified local group already exists.
pub const ALIAS_EXISTS = 1379;

/// Logon failure: the user has not been granted the requested logon type at this computer.
pub const LOGON_NOT_GRANTED = 1380;

/// The maximum number of secrets that may be stored in a single system has been exceeded.
pub const TOO_MANY_SECRETS = 1381;

/// The length of a secret exceeds the maximum length allowed.
pub const SECRET_TOO_LONG = 1382;

/// The local security authority database contains an internal inconsistency.
pub const INTERNAL_DB_ERROR = 1383;

/// During a logon attempt, the user's security context accumulated too many security IDs.
pub const TOO_MANY_CONTEXT_IDS = 1384;

/// Logon failure: the user has not been granted the requested logon type at this computer.
pub const LOGON_TYPE_NOT_GRANTED = 1385;

/// A cross-encrypted password is necessary to change a user password.
pub const NT_CROSS_ENCRYPTION_REQUIRED = 1386;

/// A member could not be added to or removed from the local group because the member does not exist.
pub const NO_SUCH_MEMBER = 1387;

/// A new member could not be added to a local group because the member has the wrong account type.
pub const INVALID_MEMBER = 1388;

/// Too many security IDs have been specified.
pub const TOO_MANY_SIDS = 1389;

/// A cross-encrypted password is necessary to change this user password.
pub const LM_CROSS_ENCRYPTION_REQUIRED = 1390;

/// Indicates an ACL contains no inheritable components.
pub const NO_INHERITANCE = 1391;

/// The file or directory is corrupted and unreadable.
pub const FILE_CORRUPT = 1392;

/// The disk structure is corrupted and unreadable.
pub const DISK_CORRUPT = 1393;

/// There is no user session key for the specified logon session.
pub const NO_USER_SESSION_KEY = 1394;

/// The service being accessed is licensed for a particular number of connections. No more connections can be made to the service at this time because there are already as many connections as the service can accept.
pub const LICENSE_QUOTA_EXCEEDED = 1395;

/// The target account name is incorrect.
pub const WRONG_TARGET_NAME = 1396;

/// Mutual Authentication failed. The server's password is out of date at the domain controller.
pub const MUTUAL_AUTH_FAILED = 1397;

/// There is a time and/or date difference between the client and server.
pub const TIME_SKEW = 1398;

/// This operation cannot be performed on the current domain.
pub const CURRENT_DOMAIN_NOT_ALLOWED = 1399;

/// Invalid window handle.
pub const INVALID_WINDOW_HANDLE = 1400;

/// Invalid menu handle.
pub const INVALID_MENU_HANDLE = 1401;

/// Invalid cursor handle.
pub const INVALID_CURSOR_HANDLE = 1402;

/// Invalid accelerator table handle.
pub const INVALID_ACCEL_HANDLE = 1403;

/// Invalid hook handle.
pub const INVALID_HOOK_HANDLE = 1404;

/// Invalid handle to a multiple-window position structure.
pub const INVALID_DWP_HANDLE = 1405;

/// Cannot create a top-level child window.
pub const TLW_WITH_WSCHILD = 1406;

/// Cannot find window class.
pub const CANNOT_FIND_WND_CLASS = 1407;

/// Invalid window; it belongs to other thread.
pub const WINDOW_OF_OTHER_THREAD = 1408;

/// Hot key is already registered.
pub const HOTKEY_ALREADY_REGISTERED = 1409;

/// Class already exists.
pub const CLASS_ALREADY_EXISTS = 1410;

/// Class does not exist.
pub const CLASS_DOES_NOT_EXIST = 1411;

/// Class still has open windows.
pub const CLASS_HAS_WINDOWS = 1412;

/// Invalid index.
pub const INVALID_INDEX = 1413;

/// Invalid icon handle.
pub const INVALID_ICON_HANDLE = 1414;

/// Using private DIALOG window words.
pub const PRIVATE_DIALOG_INDEX = 1415;

/// The list box identifier was not found.
pub const LISTBOX_ID_NOT_FOUND = 1416;

/// No wildcards were found.
pub const NO_WILDCARD_CHARACTERS = 1417;

/// Thread does not have a clipboard open.
pub const CLIPBOARD_NOT_OPEN = 1418;

/// Hot key is not registered.
pub const HOTKEY_NOT_REGISTERED = 1419;

/// The window is not a valid dialog window.
pub const WINDOW_NOT_DIALOG = 1420;

/// Control ID not found.
pub const CONTROL_ID_NOT_FOUND = 1421;

/// Invalid message for a combo box because it does not have an edit control.
pub const INVALID_COMBOBOX_MESSAGE = 1422;

/// The window is not a combo box.
pub const WINDOW_NOT_COMBOBOX = 1423;

/// Height must be less than 256.
pub const INVALID_EDIT_HEIGHT = 1424;

/// Invalid device context (DC) handle.
pub const DC_NOT_FOUND = 1425;

/// Invalid hook procedure type.
pub const INVALID_HOOK_FILTER = 1426;

/// Invalid hook procedure.
pub const INVALID_FILTER_PROC = 1427;

/// Cannot set nonlocal hook without a module handle.
pub const HOOK_NEEDS_HMOD = 1428;

/// This hook procedure can only be set globally.
pub const GLOBAL_ONLY_HOOK = 1429;

/// The journal hook procedure is already installed.
pub const JOURNAL_HOOK_SET = 1430;

/// The hook procedure is not installed.
pub const HOOK_NOT_INSTALLED = 1431;

/// Invalid message for single-selection list box.
pub const INVALID_LB_MESSAGE = 1432;

/// LB_SETCOUNT sent to non-lazy list box.
pub const SETCOUNT_ON_BAD_LB = 1433;

/// This list box does not support tab stops.
pub const LB_WITHOUT_TABSTOPS = 1434;

/// Cannot destroy object created by another thread.
pub const DESTROY_OBJECT_OF_OTHER_THREAD = 1435;

/// Child windows cannot have menus.
pub const CHILD_WINDOW_MENU = 1436;

/// The window does not have a system menu.
pub const NO_SYSTEM_MENU = 1437;

/// Invalid message box style.
pub const INVALID_MSGBOX_STYLE = 1438;

/// Invalid system-wide (SPI_*) parameter.
pub const INVALID_SPI_VALUE = 1439;

/// Screen already locked.
pub const SCREEN_ALREADY_LOCKED = 1440;

/// All handles to windows in a multiple-window position structure must have the same parent.
pub const HWNDS_HAVE_DIFF_PARENT = 1441;

/// The window is not a child window.
pub const NOT_CHILD_WINDOW = 1442;

/// Invalid GW_* command.
pub const INVALID_GW_COMMAND = 1443;

/// Invalid thread identifier.
pub const INVALID_THREAD_ID = 1444;

/// Cannot process a message from a window that is not a multiple document interface (MDI) window.
pub const NON_MDICHILD_WINDOW = 1445;

/// Popup menu already active.
pub const POPUP_ALREADY_ACTIVE = 1446;

/// The window does not have scroll bars.
pub const NO_SCROLLBARS = 1447;

/// Scroll bar range cannot be greater than MAXLONG.
pub const INVALID_SCROLLBAR_RANGE = 1448;

/// Cannot show or remove the window in the way specified.
pub const INVALID_SHOWWIN_COMMAND = 1449;

/// Insufficient system resources exist to complete the requested service.
pub const NO_SYSTEM_RESOURCES = 1450;

/// Insufficient system resources exist to complete the requested service.
pub const NONPAGED_SYSTEM_RESOURCES = 1451;

/// Insufficient system resources exist to complete the requested service.
pub const PAGED_SYSTEM_RESOURCES = 1452;

/// Insufficient quota to complete the requested service.
pub const WORKING_SET_QUOTA = 1453;

/// Insufficient quota to complete the requested service.
pub const PAGEFILE_QUOTA = 1454;

/// The paging file is too small for this operation to complete.
pub const COMMITMENT_LIMIT = 1455;

/// A menu item was not found.
pub const MENU_ITEM_NOT_FOUND = 1456;

/// Invalid keyboard layout handle.
pub const INVALID_KEYBOARD_HANDLE = 1457;

/// Hook type not allowed.
pub const HOOK_TYPE_NOT_ALLOWED = 1458;

/// This operation requires an interactive window station.
pub const REQUIRES_INTERACTIVE_WINDOWSTATION = 1459;

/// This operation returned because the timeout period expired.
pub const TIMEOUT = 1460;

/// Invalid monitor handle.
pub const INVALID_MONITOR_HANDLE = 1461;

/// Incorrect size argument.
pub const INCORRECT_SIZE = 1462;

/// The symbolic link cannot be followed because its type is disabled.
pub const SYMLINK_CLASS_DISABLED = 1463;

/// This application does not support the current operation on symbolic links.
pub const SYMLINK_NOT_SUPPORTED = 1464;

/// Windows was unable to parse the requested XML data.
pub const XML_PARSE_ERROR = 1465;

/// An error was encountered while processing an XML digital signature.
pub const XMLDSIG_ERROR = 1466;

/// This application must be restarted.
pub const RESTART_APPLICATION = 1467;

/// The caller made the connection request in the wrong routing compartment.
pub const WRONG_COMPARTMENT = 1468;

/// There was an AuthIP failure when attempting to connect to the remote host.
pub const AUTHIP_FAILURE = 1469;

/// Insufficient NVRAM resources exist to complete the requested service. A reboot might be required.
pub const NO_NVRAM_RESOURCES = 1470;

/// Unable to finish the requested operation because the specified process is not a GUI process.
pub const NOT_GUI_PROCESS = 1471;

/// The event log file is corrupted.
pub const EVENTLOG_FILE_CORRUPT = 1500;

/// No event log file could be opened, so the event logging service did not start.
pub const EVENTLOG_CANT_START = 1501;

/// The event log file is full.
pub const LOG_FILE_FULL = 1502;

/// The event log file has changed between read operations.
pub const EVENTLOG_FILE_CHANGED = 1503;

/// The specified task name is invalid.
pub const INVALID_TASK_NAME = 1550;

/// The specified task index is invalid.
pub const INVALID_TASK_INDEX = 1551;

/// The specified thread is already joining a task.
pub const THREAD_ALREADY_IN_TASK = 1552;

/// The Windows Installer Service could not be accessed. This can occur if the Windows Installer is not correctly installed. Contact your support personnel for assistance.
pub const INSTALL_SERVICE_FAILURE = 1601;

/// User cancelled installation.
pub const INSTALL_USEREXIT = 1602;

/// Fatal error during installation.
pub const INSTALL_FAILURE = 1603;

/// Installation suspended, incomplete.
pub const INSTALL_SUSPEND = 1604;

/// This action is only valid for products that are currently installed.
pub const UNKNOWN_PRODUCT = 1605;

/// Feature ID not registered.
pub const UNKNOWN_FEATURE = 1606;

/// Component ID not registered.
pub const UNKNOWN_COMPONENT = 1607;

/// Unknown property.
pub const UNKNOWN_PROPERTY = 1608;

/// Handle is in an invalid state.
pub const INVALID_HANDLE_STATE = 1609;

/// The configuration data for this product is corrupt. Contact your support personnel.
pub const BAD_CONFIGURATION = 1610;

/// Component qualifier not present.
pub const INDEX_ABSENT = 1611;

/// The installation source for this product is not available. Verify that the source exists and that you can access it.
pub const INSTALL_SOURCE_ABSENT = 1612;

/// This installation package cannot be installed by the Windows Installer service. You must install a Windows service pack that contains a newer version of the Windows Installer service.
pub const INSTALL_PACKAGE_VERSION = 1613;

/// Product is uninstalled.
pub const PRODUCT_UNINSTALLED = 1614;

/// SQL query syntax invalid or unsupported.
pub const BAD_QUERY_SYNTAX = 1615;

/// Record field does not exist.
pub const INVALID_FIELD = 1616;

/// The device has been removed.
pub const DEVICE_REMOVED = 1617;

/// Another installation is already in progress. Complete that installation before proceeding with this install.
pub const INSTALL_ALREADY_RUNNING = 1618;

/// This installation package could not be opened. Verify that the package exists and that you can access it, or contact the application vendor to verify that this is a valid Windows Installer package.
pub const INSTALL_PACKAGE_OPEN_FAILED = 1619;

/// This installation package could not be opened. Contact the application vendor to verify that this is a valid Windows Installer package.
pub const INSTALL_PACKAGE_INVALID = 1620;

/// There was an error starting the Windows Installer service user interface. Contact your support personnel.
pub const INSTALL_UI_FAILURE = 1621;

/// Error opening installation log file. Verify that the specified log file location exists and that you can write to it.
pub const INSTALL_LOG_FAILURE = 1622;

/// The language of this installation package is not supported by your system.
pub const INSTALL_LANGUAGE_UNSUPPORTED = 1623;

/// Error applying transforms. Verify that the specified transform paths are valid.
pub const INSTALL_TRANSFORM_FAILURE = 1624;

/// This installation is forbidden by system policy. Contact your system administrator.
pub const INSTALL_PACKAGE_REJECTED = 1625;

/// Function could not be executed.
pub const FUNCTION_NOT_CALLED = 1626;

/// Function failed during execution.
pub const FUNCTION_FAILED = 1627;

/// Invalid or unknown table specified.
pub const INVALID_TABLE = 1628;

/// Data supplied is of wrong type.
pub const DATATYPE_MISMATCH = 1629;

/// Data of this type is not supported.
pub const UNSUPPORTED_TYPE = 1630;

/// The Windows Installer service failed to start. Contact your support personnel.
pub const CREATE_FAILED = 1631;

/// The Temp folder is on a drive that is full or is inaccessible. Free up space on the drive or verify that you have write permission on the Temp folder.
pub const INSTALL_TEMP_UNWRITABLE = 1632;

/// This installation package is not supported by this processor type. Contact your product vendor.
pub const INSTALL_PLATFORM_UNSUPPORTED = 1633;

/// Component not used on this computer.
pub const INSTALL_NOTUSED = 1634;

/// This update package could not be opened. Verify that the update package exists and that you can access it, or contact the application vendor to verify that this is a valid Windows Installer update package.
pub const PATCH_PACKAGE_OPEN_FAILED = 1635;

/// This update package could not be opened. Contact the application vendor to verify that this is a valid Windows Installer update package.
pub const PATCH_PACKAGE_INVALID = 1636;

/// This update package cannot be processed by the Windows Installer service. You must install a Windows service pack that contains a newer version of the Windows Installer service.
pub const PATCH_PACKAGE_UNSUPPORTED = 1637;

/// Another version of this product is already installed. Installation of this version cannot continue. To configure or remove the existing version of this product, use Add/Remove Programs on the Control Panel.
pub const PRODUCT_VERSION = 1638;

/// Invalid command line argument. Consult the Windows Installer SDK for detailed command line help.
pub const INVALID_COMMAND_LINE = 1639;

/// Only administrators have permission to add, remove, or configure server software during a Terminal services remote session. If you want to install or configure software on the server, contact your network administrator.
pub const INSTALL_REMOTE_DISALLOWED = 1640;

/// The requested operation completed successfully. The system will be restarted so the changes can take effect.
pub const SUCCESS_REBOOT_INITIATED = 1641;

/// The upgrade cannot be installed by the Windows Installer service because the program to be upgraded may be missing, or the upgrade may update a different version of the program. Verify that the program to be upgraded exists on your computer and that you have the correct upgrade.
pub const PATCH_TARGET_NOT_FOUND = 1642;

/// The update package is not permitted by software restriction policy.
pub const PATCH_PACKAGE_REJECTED = 1643;

/// One or more customizations are not permitted by software restriction policy.
pub const INSTALL_TRANSFORM_REJECTED = 1644;

/// The Windows Installer does not permit installation from a Remote Desktop Connection.
pub const INSTALL_REMOTE_PROHIBITED = 1645;

/// Uninstallation of the update package is not supported.
pub const PATCH_REMOVAL_UNSUPPORTED = 1646;

/// The update is not applied to this product.
pub const UNKNOWN_PATCH = 1647;

/// No valid sequence could be found for the set of updates.
pub const PATCH_NO_SEQUENCE = 1648;

/// Update removal was disallowed by policy.
pub const PATCH_REMOVAL_DISALLOWED = 1649;

/// The XML update data is invalid.
pub const INVALID_PATCH_XML = 1650;

/// Windows Installer does not permit updating of managed advertised products. At least one feature of the product must be installed before applying the update.
pub const PATCH_MANAGED_ADVERTISED_PRODUCT = 1651;

/// The Windows Installer service is not accessible in Safe Mode. Please try again when your computer is not in Safe Mode or you can use System Restore to return your machine to a previous good state.
pub const INSTALL_SERVICE_SAFEBOOT = 1652;

/// A fail fast exception occurred. Exception handlers will not be invoked and the process will be terminated immediately.
pub const FAIL_FAST_EXCEPTION = 1653;

/// The app that you are trying to run is not supported on this version of Windows.
pub const INSTALL_REJECTED = 1654;

/// The string binding is invalid.
pub const RPC_S_INVALID_STRING_BINDING = 1700;

/// The binding handle is not the correct type.
pub const RPC_S_WRONG_KIND_OF_BINDING = 1701;

/// The binding handle is invalid.
pub const RPC_S_INVALID_BINDING = 1702;

/// The RPC protocol sequence is not supported.
pub const RPC_S_PROTSEQ_NOT_SUPPORTED = 1703;

/// The RPC protocol sequence is invalid.
pub const RPC_S_INVALID_RPC_PROTSEQ = 1704;

/// The string universal unique identifier (UUID) is invalid.
pub const RPC_S_INVALID_STRING_UUID = 1705;

/// The endpoint format is invalid.
pub const RPC_S_INVALID_ENDPOINT_FORMAT = 1706;

/// The network address is invalid.
pub const RPC_S_INVALID_NET_ADDR = 1707;

/// No endpoint was found.
pub const RPC_S_NO_ENDPOINT_FOUND = 1708;

/// The timeout value is invalid.
pub const RPC_S_INVALID_TIMEOUT = 1709;

/// The object universal unique identifier (UUID) was not found.
pub const RPC_S_OBJECT_NOT_FOUND = 1710;

/// The object universal unique identifier (UUID) has already been registered.
pub const RPC_S_ALREADY_REGISTERED = 1711;

/// The type universal unique identifier (UUID) has already been registered.
pub const RPC_S_TYPE_ALREADY_REGISTERED = 1712;

/// The RPC server is already listening.
pub const RPC_S_ALREADY_LISTENING = 1713;

/// No protocol sequences have been registered.
pub const RPC_S_NO_PROTSEQS_REGISTERED = 1714;

/// The RPC server is not listening.
pub const RPC_S_NOT_LISTENING = 1715;

/// The manager type is unknown.
pub const RPC_S_UNKNOWN_MGR_TYPE = 1716;

/// The interface is unknown.
pub const RPC_S_UNKNOWN_IF = 1717;

/// There are no bindings.
pub const RPC_S_NO_BINDINGS = 1718;

/// There are no protocol sequences.
pub const RPC_S_NO_PROTSEQS = 1719;

/// The endpoint cannot be created.
pub const RPC_S_CANT_CREATE_ENDPOINT = 1720;

/// Not enough resources are available to complete this operation.
pub const RPC_S_OUT_OF_RESOURCES = 1721;

/// The RPC server is unavailable.
pub const RPC_S_SERVER_UNAVAILABLE = 1722;

/// The RPC server is too busy to complete this operation.
pub const RPC_S_SERVER_TOO_BUSY = 1723;

/// The network options are invalid.
pub const RPC_S_INVALID_NETWORK_OPTIONS = 1724;

/// There are no remote procedure calls active on this thread.
pub const RPC_S_NO_CALL_ACTIVE = 1725;

/// The remote procedure call failed.
pub const RPC_S_CALL_FAILED = 1726;

/// The remote procedure call failed and did not execute.
pub const RPC_S_CALL_FAILED_DNE = 1727;

/// A remote procedure call (RPC) protocol error occurred.
pub const RPC_S_PROTOCOL_ERROR = 1728;

/// Access to the HTTP proxy is denied.
pub const RPC_S_PROXY_ACCESS_DENIED = 1729;

/// The transfer syntax is not supported by the RPC server.
pub const RPC_S_UNSUPPORTED_TRANS_SYN = 1730;

/// The universal unique identifier (UUID) type is not supported.
pub const RPC_S_UNSUPPORTED_TYPE = 1732;

/// The tag is invalid.
pub const RPC_S_INVALID_TAG = 1733;

/// The array bounds are invalid.
pub const RPC_S_INVALID_BOUND = 1734;

/// The binding does not contain an entry name.
pub const RPC_S_NO_ENTRY_NAME = 1735;

/// The name syntax is invalid.
pub const RPC_S_INVALID_NAME_SYNTAX = 1736;

/// The name syntax is not supported.
pub const RPC_S_UNSUPPORTED_NAME_SYNTAX = 1737;

/// No network address is available to use to construct a universal unique identifier (UUID).
pub const RPC_S_UUID_NO_ADDRESS = 1739;

/// The endpoint is a duplicate.
pub const RPC_S_DUPLICATE_ENDPOINT = 1740;

/// The authentication type is unknown.
pub const RPC_S_UNKNOWN_AUTHN_TYPE = 1741;

/// The maximum number of calls is too small.
pub const RPC_S_MAX_CALLS_TOO_SMALL = 1742;

/// The string is too long.
pub const RPC_S_STRING_TOO_LONG = 1743;

/// The RPC protocol sequence was not found.
pub const RPC_S_PROTSEQ_NOT_FOUND = 1744;

/// The procedure number is out of range.
pub const RPC_S_PROCNUM_OUT_OF_RANGE = 1745;

/// The binding does not contain any authentication information.
pub const RPC_S_BINDING_HAS_NO_AUTH = 1746;

/// The authentication service is unknown.
pub const RPC_S_UNKNOWN_AUTHN_SERVICE = 1747;

/// The authentication level is unknown.
pub const RPC_S_UNKNOWN_AUTHN_LEVEL = 1748;

/// The security context is invalid.
pub const RPC_S_INVALID_AUTH_IDENTITY = 1749;

/// The authorization service is unknown.
pub const RPC_S_UNKNOWN_AUTHZ_SERVICE = 1750;

/// The entry is invalid.
pub const EPT_S_INVALID_ENTRY = 1751;

/// The server endpoint cannot perform the operation.
pub const EPT_S_CANT_PERFORM_OP = 1752;

/// There are no more endpoints available from the endpoint mapper.
pub const EPT_S_NOT_REGISTERED = 1753;

/// No interfaces have been exported.
pub const RPC_S_NOTHING_TO_EXPORT = 1754;

/// The entry name is incomplete.
pub const RPC_S_INCOMPLETE_NAME = 1755;

/// The version option is invalid.
pub const RPC_S_INVALID_VERS_OPTION = 1756;

/// There are no more members.
pub const RPC_S_NO_MORE_MEMBERS = 1757;

/// There is nothing to unexport.
pub const RPC_S_NOT_ALL_OBJS_UNEXPORTED = 1758;

/// The interface was not found.
pub const RPC_S_INTERFACE_NOT_FOUND = 1759;

/// The entry already exists.
pub const RPC_S_ENTRY_ALREADY_EXISTS = 1760;

/// The entry is not found.
pub const RPC_S_ENTRY_NOT_FOUND = 1761;

/// The name service is unavailable.
pub const RPC_S_NAME_SERVICE_UNAVAILABLE = 1762;

/// The network address family is invalid.
pub const RPC_S_INVALID_NAF_ID = 1763;

/// The requested operation is not supported.
pub const RPC_S_CANNOT_SUPPORT = 1764;

/// No security context is available to allow impersonation.
pub const RPC_S_NO_CONTEXT_AVAILABLE = 1765;

/// An internal error occurred in a remote procedure call (RPC).
pub const RPC_S_INTERNAL_ERROR = 1766;

/// The RPC server attempted an integer division by zero.
pub const RPC_S_ZERO_DIVIDE = 1767;

/// An addressing error occurred in the RPC server.
pub const RPC_S_ADDRESS_ERROR = 1768;

/// A floating-point operation at the RPC server caused a division by zero.
pub const RPC_S_FP_DIV_ZERO = 1769;

/// A floating-point underflow occurred at the RPC server.
pub const RPC_S_FP_UNDERFLOW = 1770;

/// A floating-point overflow occurred at the RPC server.
pub const RPC_S_FP_OVERFLOW = 1771;

/// The list of RPC servers available for the binding of auto handles has been exhausted.
pub const RPC_X_NO_MORE_ENTRIES = 1772;

/// Unable to open the character translation table file.
pub const RPC_X_SS_CHAR_TRANS_OPEN_FAIL = 1773;

/// The file containing the character translation table has fewer than 512 bytes.
pub const RPC_X_SS_CHAR_TRANS_SHORT_FILE = 1774;

/// A null context handle was passed from the client to the host during a remote procedure call.
pub const RPC_X_SS_IN_NULL_CONTEXT = 1775;

/// The context handle changed during a remote procedure call.
pub const RPC_X_SS_CONTEXT_DAMAGED = 1777;

/// The binding handles passed to a remote procedure call do not match.
pub const RPC_X_SS_HANDLES_MISMATCH = 1778;

/// The stub is unable to get the remote procedure call handle.
pub const RPC_X_SS_CANNOT_GET_CALL_HANDLE = 1779;

/// A null reference pointer was passed to the stub.
pub const RPC_X_NULL_REF_POINTER = 1780;

/// The enumeration value is out of range.
pub const RPC_X_ENUM_VALUE_OUT_OF_RANGE = 1781;

/// The byte count is too small.
pub const RPC_X_BYTE_COUNT_TOO_SMALL = 1782;

/// The stub received bad data.
pub const RPC_X_BAD_STUB_DATA = 1783;

/// The supplied user buffer is not valid for the requested operation.
pub const INVALID_USER_BUFFER = 1784;

/// The disk media is not recognized. It may not be formatted.
pub const UNRECOGNIZED_MEDIA = 1785;

/// The workstation does not have a trust secret.
pub const NO_TRUST_LSA_SECRET = 1786;

/// The security database on the server does not have a computer account for this workstation trust relationship.
pub const NO_TRUST_SAM_ACCOUNT = 1787;

/// The trust relationship between the primary domain and the trusted domain failed.
pub const TRUSTED_DOMAIN_FAILURE = 1788;

/// The trust relationship between this workstation and the primary domain failed.
pub const TRUSTED_RELATIONSHIP_FAILURE = 1789;

/// The network logon failed.
pub const TRUST_FAILURE = 1790;

/// A remote procedure call is already in progress for this thread.
pub const RPC_S_CALL_IN_PROGRESS = 1791;

/// An attempt was made to logon, but the network logon service was not started.
pub const NETLOGON_NOT_STARTED = 1792;

/// The user's account has expired.
pub const ACCOUNT_EXPIRED = 1793;

/// The redirector is in use and cannot be unloaded.
pub const REDIRECTOR_HAS_OPEN_HANDLES = 1794;

/// The specified printer driver is already installed.
pub const PRINTER_DRIVER_ALREADY_INSTALLED = 1795;

/// The specified port is unknown.
pub const UNKNOWN_PORT = 1796;

/// The printer driver is unknown.
pub const UNKNOWN_PRINTER_DRIVER = 1797;

/// The print processor is unknown.
pub const UNKNOWN_PRINTPROCESSOR = 1798;

/// The specified separator file is invalid.
pub const INVALID_SEPARATOR_FILE = 1799;

/// The specified priority is invalid.
pub const INVALID_PRIORITY = 1800;

/// The printer name is invalid.
pub const INVALID_PRINTER_NAME = 1801;

/// The printer already exists.
pub const PRINTER_ALREADY_EXISTS = 1802;

/// The printer command is invalid.
pub const INVALID_PRINTER_COMMAND = 1803;

/// The specified datatype is invalid.
pub const INVALID_DATATYPE = 1804;

/// The environment specified is invalid.
pub const INVALID_ENVIRONMENT = 1805;

/// There are no more bindings.
pub const RPC_S_NO_MORE_BINDINGS = 1806;

/// The account used is an interdomain trust account. Use your global user account or local user account to access this server.
pub const NOLOGON_INTERDOMAIN_TRUST_ACCOUNT = 1807;

/// The account used is a computer account. Use your global user account or local user account to access this server.
pub const NOLOGON_WORKSTATION_TRUST_ACCOUNT = 1808;

/// The account used is a server trust account. Use your global user account or local user account to access this server.
pub const NOLOGON_SERVER_TRUST_ACCOUNT = 1809;

/// The name or security ID (SID) of the domain specified is inconsistent with the trust information for that domain.
pub const DOMAIN_TRUST_INCONSISTENT = 1810;

/// The server is in use and cannot be unloaded.
pub const SERVER_HAS_OPEN_HANDLES = 1811;

/// The specified image file did not contain a resource section.
pub const RESOURCE_DATA_NOT_FOUND = 1812;

/// The specified resource type cannot be found in the image file.
pub const RESOURCE_TYPE_NOT_FOUND = 1813;

/// The specified resource name cannot be found in the image file.
pub const RESOURCE_NAME_NOT_FOUND = 1814;

/// The specified resource language ID cannot be found in the image file.
pub const RESOURCE_LANG_NOT_FOUND = 1815;

/// Not enough quota is available to process this command.
pub const NOT_ENOUGH_QUOTA = 1816;

/// No interfaces have been registered.
pub const RPC_S_NO_INTERFACES = 1817;

/// The remote procedure call was cancelled.
pub const RPC_S_CALL_CANCELLED = 1818;

/// The binding handle does not contain all required information.
pub const RPC_S_BINDING_INCOMPLETE = 1819;

/// A communications failure occurred during a remote procedure call.
pub const RPC_S_COMM_FAILURE = 1820;

/// The requested authentication level is not supported.
pub const RPC_S_UNSUPPORTED_AUTHN_LEVEL = 1821;

/// No principal name registered.
pub const RPC_S_NO_PRINC_NAME = 1822;

/// The error specified is not a valid Windows RPC error code.
pub const RPC_S_NOT_RPC_ERROR = 1823;

/// A UUID that is valid only on this computer has been allocated.
pub const RPC_S_UUID_LOCAL_ONLY = 1824;

/// A security package specific error occurred.
pub const RPC_S_SEC_PKG_ERROR = 1825;

/// Thread is not canceled.
pub const RPC_S_NOT_CANCELLED = 1826;

/// Invalid operation on the encoding/decoding handle.
pub const RPC_X_INVALID_ES_ACTION = 1827;

/// Incompatible version of the serializing package.
pub const RPC_X_WRONG_ES_VERSION = 1828;

/// Incompatible version of the RPC stub.
pub const RPC_X_WRONG_STUB_VERSION = 1829;

/// The RPC pipe object is invalid or corrupted.
pub const RPC_X_INVALID_PIPE_OBJECT = 1830;

/// An invalid operation was attempted on an RPC pipe object.
pub const RPC_X_WRONG_PIPE_ORDER = 1831;

/// Unsupported RPC pipe version.
pub const RPC_X_WRONG_PIPE_VERSION = 1832;

/// HTTP proxy server rejected the connection because the cookie authentication failed.
pub const RPC_S_COOKIE_AUTH_FAILED = 1833;

/// The group member was not found.
pub const RPC_S_GROUP_MEMBER_NOT_FOUND = 1898;

/// The endpoint mapper database entry could not be created.
pub const EPT_S_CANT_CREATE = 1899;

/// The object universal unique identifier (UUID) is the nil UUID.
pub const RPC_S_INVALID_OBJECT = 1900;

/// The specified time is invalid.
pub const INVALID_TIME = 1901;

/// The specified form name is invalid.
pub const INVALID_FORM_NAME = 1902;

/// The specified form size is invalid.
pub const INVALID_FORM_SIZE = 1903;

/// The specified printer handle is already being waited on.
pub const ALREADY_WAITING = 1904;

/// The specified printer has been deleted.
pub const PRINTER_DELETED = 1905;

/// The state of the printer is invalid.
pub const INVALID_PRINTER_STATE = 1906;

/// The user's password must be changed before signing in.
pub const PASSWORD_MUST_CHANGE = 1907;

/// Could not find the domain controller for this domain.
pub const DOMAIN_CONTROLLER_NOT_FOUND = 1908;

/// The referenced account is currently locked out and may not be logged on to.
pub const ACCOUNT_LOCKED_OUT = 1909;

/// The object exporter specified was not found.
pub const OR_INVALID_OXID = 1910;

/// The object specified was not found.
pub const OR_INVALID_OID = 1911;

/// The object resolver set specified was not found.
pub const OR_INVALID_SET = 1912;

/// Some data remains to be sent in the request buffer.
pub const RPC_S_SEND_INCOMPLETE = 1913;

/// Invalid asynchronous remote procedure call handle.
pub const RPC_S_INVALID_ASYNC_HANDLE = 1914;

/// Invalid asynchronous RPC call handle for this operation.
pub const RPC_S_INVALID_ASYNC_CALL = 1915;

/// The RPC pipe object has already been closed.
pub const RPC_X_PIPE_CLOSED = 1916;

/// The RPC call completed before all pipes were processed.
pub const RPC_X_PIPE_DISCIPLINE_ERROR = 1917;

/// No more data is available from the RPC pipe.
pub const RPC_X_PIPE_EMPTY = 1918;

/// No site name is available for this machine.
pub const NO_SITENAME = 1919;

/// The file cannot be accessed by the system.
pub const CANT_ACCESS_FILE = 1920;

/// The name of the file cannot be resolved by the system.
pub const CANT_RESOLVE_FILENAME = 1921;

/// The entry is not of the expected type.
pub const RPC_S_ENTRY_TYPE_MISMATCH = 1922;

/// Not all object UUIDs could be exported to the specified entry.
pub const RPC_S_NOT_ALL_OBJS_EXPORTED = 1923;

/// Interface could not be exported to the specified entry.
pub const RPC_S_INTERFACE_NOT_EXPORTED = 1924;

/// The specified profile entry could not be added.
pub const RPC_S_PROFILE_NOT_ADDED = 1925;

/// The specified profile element could not be added.
pub const RPC_S_PRF_ELT_NOT_ADDED = 1926;

/// The specified profile element could not be removed.
pub const RPC_S_PRF_ELT_NOT_REMOVED = 1927;

/// The group element could not be added.
pub const RPC_S_GRP_ELT_NOT_ADDED = 1928;

/// The group element could not be removed.
pub const RPC_S_GRP_ELT_NOT_REMOVED = 1929;

/// The printer driver is not compatible with a policy enabled on your computer that blocks NT 4.0 drivers.
pub const KM_DRIVER_BLOCKED = 1930;

/// The context has expired and can no longer be used.
pub const CONTEXT_EXPIRED = 1931;

/// The current user's delegated trust creation quota has been exceeded.
pub const PER_USER_TRUST_QUOTA_EXCEEDED = 1932;

/// The total delegated trust creation quota has been exceeded.
pub const ALL_USER_TRUST_QUOTA_EXCEEDED = 1933;

/// The current user's delegated trust deletion quota has been exceeded.
pub const USER_DELETE_TRUST_QUOTA_EXCEEDED = 1934;

/// The computer you are signing into is protected by an authentication firewall. The specified account is not allowed to authenticate to the computer.
pub const AUTHENTICATION_FIREWALL_FAILED = 1935;

/// Remote connections to the Print Spooler are blocked by a policy set on your machine.
pub const REMOTE_PRINT_CONNECTIONS_BLOCKED = 1936;

/// Authentication failed because NTLM authentication has been disabled.
pub const NTLM_BLOCKED = 1937;

/// Logon Failure: EAS policy requires that the user change their password before this operation can be performed.
pub const PASSWORD_CHANGE_REQUIRED = 1938;

/// The pixel format is invalid.
pub const INVALID_PIXEL_FORMAT = 2000;

/// The specified driver is invalid.
pub const BAD_DRIVER = 2001;

/// The window style or class attribute is invalid for this operation.
pub const INVALID_WINDOW_STYLE = 2002;

/// The requested metafile operation is not supported.
pub const METAFILE_NOT_SUPPORTED = 2003;

/// The requested transformation operation is not supported.
pub const TRANSFORM_NOT_SUPPORTED = 2004;

/// The requested clipping operation is not supported.
pub const CLIPPING_NOT_SUPPORTED = 2005;

/// The specified color management module is invalid.
pub const INVALID_CMM = 2010;

/// The specified color profile is invalid.
pub const INVALID_PROFILE = 2011;

/// The specified tag was not found.
pub const TAG_NOT_FOUND = 2012;

/// A required tag is not present.
pub const TAG_NOT_PRESENT = 2013;

/// The specified tag is already present.
pub const DUPLICATE_TAG = 2014;

/// The specified color profile is not associated with the specified device.
pub const PROFILE_NOT_ASSOCIATED_WITH_DEVICE = 2015;

/// The specified color profile was not found.
pub const PROFILE_NOT_FOUND = 2016;

/// The specified color space is invalid.
pub const INVALID_COLORSPACE = 2017;

/// Image Color Management is not enabled.
pub const ICM_NOT_ENABLED = 2018;

/// There was an error while deleting the color transform.
pub const DELETING_ICM_XFORM = 2019;

/// The specified color transform is invalid.
pub const INVALID_TRANSFORM = 2020;

/// The specified transform does not match the bitmap's color space.
pub const COLORSPACE_MISMATCH = 2021;

/// The specified named color index is not present in the profile.
pub const INVALID_COLORINDEX = 2022;

/// The specified profile is intended for a device of a different type than the specified device.
pub const PROFILE_DOES_NOT_MATCH_DEVICE = 2023;

/// The network connection was made successfully, but the user had to be prompted for a password other than the one originally specified.
pub const CONNECTED_OTHER_PASSWORD = 2108;

/// The network connection was made successfully using default credentials.
pub const CONNECTED_OTHER_PASSWORD_DEFAULT = 2109;

/// The specified username is invalid.
pub const BAD_USERNAME = 2202;

/// This network connection does not exist.
pub const NOT_CONNECTED = 2250;

/// This network connection has files open or requests pending.
pub const OPEN_FILES = 2401;

/// Active connections still exist.
pub const ACTIVE_CONNECTIONS = 2402;

/// The device is in use by an active process and cannot be disconnected.
pub const DEVICE_IN_USE = 2404;

/// The specified print monitor is unknown.
pub const UNKNOWN_PRINT_MONITOR = 3000;

/// The specified printer driver is currently in use.
pub const PRINTER_DRIVER_IN_USE = 3001;

/// The spool file was not found.
pub const SPOOL_FILE_NOT_FOUND = 3002;

/// A StartDocPrinter call was not issued.
pub const SPL_NO_STARTDOC = 3003;

/// An AddJob call was not issued.
pub const SPL_NO_ADDJOB = 3004;

/// The specified print processor has already been installed.
pub const PRINT_PROCESSOR_ALREADY_INSTALLED = 3005;

/// The specified print monitor has already been installed.
pub const PRINT_MONITOR_ALREADY_INSTALLED = 3006;

/// The specified print monitor does not have the required functions.
pub const INVALID_PRINT_MONITOR = 3007;

/// The specified print monitor is currently in use.
pub const PRINT_MONITOR_IN_USE = 3008;

/// The requested operation is not allowed when there are jobs queued to the printer.
pub const PRINTER_HAS_JOBS_QUEUED = 3009;

/// The requested operation is successful. Changes will not be effective until the system is rebooted.
pub const SUCCESS_REBOOT_REQUIRED = 3010;

/// The requested operation is successful. Changes will not be effective until the service is restarted.
pub const SUCCESS_RESTART_REQUIRED = 3011;

/// No printers were found.
pub const PRINTER_NOT_FOUND = 3012;

/// The printer driver is known to be unreliable.
pub const PRINTER_DRIVER_WARNED = 3013;

/// The printer driver is known to harm the system.
pub const PRINTER_DRIVER_BLOCKED = 3014;

/// The specified printer driver package is currently in use.
pub const PRINTER_DRIVER_PACKAGE_IN_USE = 3015;

/// Unable to find a core driver package that is required by the printer driver package.
pub const CORE_DRIVER_PACKAGE_NOT_FOUND = 3016;

/// The requested operation failed. A system reboot is required to roll back changes made.
pub const FAIL_REBOOT_REQUIRED = 3017;

/// The requested operation failed. A system reboot has been initiated to roll back changes made.
pub const FAIL_REBOOT_INITIATED = 3018;

/// The specified printer driver was not found on the system and needs to be downloaded.
pub const PRINTER_DRIVER_DOWNLOAD_NEEDED = 3019;

/// The requested print job has failed to print. A print system update requires the job to be resubmitted.
pub const PRINT_JOB_RESTART_REQUIRED = 3020;

/// The printer driver does not contain a valid manifest, or contains too many manifests.
pub const INVALID_PRINTER_DRIVER_MANIFEST = 3021;

/// The specified printer cannot be shared.
pub const PRINTER_NOT_SHAREABLE = 3022;

/// The operation was paused.
pub const REQUEST_PAUSED = 3050;

/// Reissue the given operation as a cached IO operation.
pub const IO_REISSUE_AS_CACHED = 3950;

/// Specified event object handle is invalid.
pub const WSA_INVALID_HANDLE = 6;

/// Insufficient memory available.
pub const WSA_NOT_ENOUGH_MEMORY = 8;

/// One or more parameters are invalid.
pub const WSA_INVALID_PARAMETER = 87;

/// Overlapped operation aborted.
pub const WSA_OPERATION_ABORTED = 995;

/// Overlapped I/O event object not in signaled state.
pub const WSA_IO_INCOMPLETE = 996;

/// Overlapped operations will complete later.
pub const WSA_IO_PENDING = 997;

/// Interrupted function call.
pub const WSAEINTR = 10004;

/// File handle is not valid.
pub const WSAEBADF = 10009;

/// Permission denied.
pub const WSAEACCES = 10013;

/// Bad address.
pub const WSAEFAULT = 10014;

/// Invalid argument.
pub const WSAEINVAL = 10022;

/// Too many open files.
pub const WSAEMFILE = 10024;

/// Resource temporarily unavailable.
pub const WSAEWOULDBLOCK = 10035;

/// Operation now in progress.
pub const WSAEINPROGRESS = 10036;

/// Operation already in progress.
pub const WSAEALREADY = 10037;

/// Socket operation on nonsocket.
pub const WSAENOTSOCK = 10038;

/// Destination address required.
pub const WSAEDESTADDRREQ = 10039;

/// Message too long.
pub const WSAEMSGSIZE = 10040;

/// Protocol wrong type for socket.
pub const WSAEPROTOTYPE = 10041;

/// Bad protocol option.
pub const WSAENOPROTOOPT = 10042;

/// Protocol not supported.
pub const WSAEPROTONOSUPPORT = 10043;

/// Socket type not supported.
pub const WSAESOCKTNOSUPPORT = 10044;

/// Operation not supported.
pub const WSAEOPNOTSUPP = 10045;

/// Protocol family not supported.
pub const WSAEPFNOSUPPORT = 10046;

/// Address family not supported by protocol family.
pub const WSAEAFNOSUPPORT = 10047;

/// Address already in use.
pub const WSAEADDRINUSE = 10048;

/// Cannot assign requested address.
pub const WSAEADDRNOTAVAIL = 10049;

/// Network is down.
pub const WSAENETDOWN = 10050;

/// Network is unreachable.
pub const WSAENETUNREACH = 10051;

/// Network dropped connection on reset.
pub const WSAENETRESET = 10052;

/// Software caused connection abort.
pub const WSAECONNABORTED = 10053;

/// Connection reset by peer.
pub const WSAECONNRESET = 10054;

/// No buffer space available.
pub const WSAENOBUFS = 10055;

/// Socket is already connected.
pub const WSAEISCONN = 10056;

/// Socket is not connected.
pub const WSAENOTCONN = 10057;

/// Cannot send after socket shutdown.
pub const WSAESHUTDOWN = 10058;

/// Too many references.
pub const WSAETOOMANYREFS = 10059;

/// Connection timed out.
pub const WSAETIMEDOUT = 10060;

/// Connection refused.
pub const WSAECONNREFUSED = 10061;

/// Cannot translate name.
pub const WSAELOOP = 10062;

/// Name too long.
pub const WSAENAMETOOLONG = 10063;

/// Host is down.
pub const WSAEHOSTDOWN = 10064;

/// No route to host.
pub const WSAEHOSTUNREACH = 10065;

/// Directory not empty.
pub const WSAENOTEMPTY = 10066;

/// Too many processes.
pub const WSAEPROCLIM = 10067;

/// User quota exceeded.
pub const WSAEUSERS = 10068;

/// Disk quota exceeded.
pub const WSAEDQUOT = 10069;

/// Stale file handle reference.
pub const WSAESTALE = 10070;

/// Item is remote.
pub const WSAEREMOTE = 10071;

/// Network subsystem is unavailable.
pub const WSASYSNOTREADY = 10091;

/// Winsock.dll version out of range.
pub const WSAVERNOTSUPPORTED = 10092;

/// Successful WSAStartup not yet performed.
pub const WSANOTINITIALISED = 10093;

/// Graceful shutdown in progress.
pub const WSAEDISCON = 10101;

/// No more results.
pub const WSAENOMORE = 10102;

/// Call has been canceled.
pub const WSAECANCELLED = 10103;

/// Procedure call table is invalid.
pub const WSAEINVALIDPROCTABLE = 10104;

/// Service provider is invalid.
pub const WSAEINVALIDPROVIDER = 10105;

/// Service provider failed to initialize.
pub const WSAEPROVIDERFAILEDINIT = 10106;

/// System call failure.
pub const WSASYSCALLFAILURE = 10107;

/// Service not found.
pub const WSASERVICE_NOT_FOUND = 10108;

/// Class type not found.
pub const WSATYPE_NOT_FOUND = 10109;

/// No more results.
pub const WSA_E_NO_MORE = 10110;

/// Call was canceled.
pub const WSA_E_CANCELLED = 10111;

/// Database query was refused.
pub const WSAEREFUSED = 10112;

/// Host not found.
pub const WSAHOST_NOT_FOUND = 11001;

/// Nonauthoritative host not found.
pub const WSATRY_AGAIN = 11002;

/// This is a nonrecoverable error.
pub const WSANO_RECOVERY = 11003;

/// Valid name, no data record of requested type.
pub const WSANO_DATA = 11004;

/// QoS receivers.
pub const WSA_QOS_RECEIVERS = 11005;

/// QoS senders.
pub const WSA_QOS_SENDERS = 11006;

/// No QoS senders.
pub const WSA_QOS_NO_SENDERS = 11007;

/// QoS no receivers.
pub const WSA_QOS_NO_RECEIVERS = 11008;

/// QoS request confirmed.
pub const WSA_QOS_REQUEST_CONFIRMED = 11009;

/// QoS admission error.
pub const WSA_QOS_ADMISSION_FAILURE = 11010;

/// QoS policy failure.
pub const WSA_QOS_POLICY_FAILURE = 11011;

/// QoS bad style.
pub const WSA_QOS_BAD_STYLE = 11012;

/// QoS bad object.
pub const WSA_QOS_BAD_OBJECT = 11013;

/// QoS traffic control error.
pub const WSA_QOS_TRAFFIC_CTRL_ERROR = 11014;

/// QoS generic error.
pub const WSA_QOS_GENERIC_ERROR = 11015;

/// QoS service type error.
pub const WSA_QOS_ESERVICETYPE = 11016;

/// QoS flowspec error.
pub const WSA_QOS_EFLOWSPEC = 11017;

/// Invalid QoS provider buffer.
pub const WSA_QOS_EPROVSPECBUF = 11018;

/// Invalid QoS filter style.
pub const WSA_QOS_EFILTERSTYLE = 11019;

/// Invalid QoS filter type.
pub const WSA_QOS_EFILTERTYPE = 11020;

/// Incorrect QoS filter count.
pub const WSA_QOS_EFILTERCOUNT = class;

/// Invalid QoS object length.
pub const WSA_QOS_EOBJLENGTH = 11022;

/// Incorrect QoS flow count.
pub const WSA_QOS_EFLOWCOUNT = 11023;

/// Unrecognized QoS object.
pub const WSA_QOS_EUNKOWNPSOBJ = 11024;

/// Invalid QoS policy object.
pub const WSA_QOS_EPOLICYOBJ = 11025;

/// Invalid QoS flow descriptor.
pub const WSA_QOS_EFLOWDESC = 11026;

/// Invalid QoS provider-specific flowspec.
pub const WSA_QOS_EPSFLOWSPEC = 11027;

/// Invalid QoS provider-specific filterspec.
pub const WSA_QOS_EPSFILTERSPEC = 11028;

/// Invalid QoS shape discard mode object.
pub const WSA_QOS_ESDMODEOBJ = 11029;

/// Invalid QoS shaping rate object.
pub const WSA_QOS_ESHAPERATEOBJ = 11030;

/// Reserved policy QoS element type.
pub const WSA_QOS_RESERVED_PETYPE = 11031;
