const json = @import("std").json;
const MaybeDefined = @import("json_serialize.zig").MaybeDefined;

pub const String = []const u8;
pub const Integer = i64;
pub const Float = f64;
pub const Any = json.Value;

pub const ErrorCodes = struct {
    // Defined by JSON RPC
    pub const ParseError = -32700;
    pub const InvalidRequest = -32600;
    pub const MethodNotFound = -32601;
    pub const InvalidParams = -32602;
    pub const InternalError = -32603;

    // Implementation specific JSON RPC errors
    pub const serverErrorStart = -32099;
    pub const serverErrorEnd = -32000;
    pub const ServerNotInitialized = -32002;
    pub const UnknownErrorCode = -32001;
 
    // Defined by LSP
    pub const RequestCancelled = -32800;
    pub const ContentModified = -32801;
};

pub const DocumentUri = String;

pub const Position = struct {
    line: Integer,
    character: Integer
};

pub const Range = struct {
    start: Position,
    end: Position
};

pub const Location = struct {
    uri: DocumentUri,
    range: Range
};

pub const LocationLink = struct {
    originSelectionRange: MaybeDefined(Range) = MaybeDefined(Range).NotDefined,
    targetUri: DocumentUri,
    targetRange: Range,
    targetSelectionRange: Range
};

pub const Diagnostic = struct {
    range: Range,
    severity: MaybeDefined(Integer) = MaybeDefined(Integer).NotDefined,
    code: MaybeDefined(Any) = MaybeDefined(Any).NotDefined,
    source: MaybeDefined(String) = MaybeDefined(String).NotDefined,
    message: String,
    relatedInformation: MaybeDefined([]DiagnosticRelatedInformation) = MaybeDefined([]DiagnosticRelatedInformation).NotDefined
};

pub const DiagnosticRelatedInformation = struct {
    location: Location,
    message: String
};

pub const DiagnosticSeverity = struct {
    pub const Error = 1;
    pub const Warning = 2;
    pub const Information = 3;
    pub const Hint = 4;
};

pub const Command = struct {
    title: String,
    command: String,
    arguments: MaybeDefined([]Any)
};

pub const TextEdit = struct {
    range: Range,
    newText: String
};

pub const TextDocumentSyncKind = struct {
    pub const None = 0;
    pub const Full = 1;
    pub const Incremental = 2;
};

pub const InitializeParams = struct {
    processId: ?Integer,
    rootPath: MaybeDefined(?String),
    rootUri: ?DocumentUri,
    initializationOptions: MaybeDefined(Any),
    capabilities: ClientCapabilities,
    trace: MaybeDefined(String),
    workspaceFolders: MaybeDefined(?[]WorkspaceFolder),
};

pub const Trace = struct {
    pub const Off = "off";
    pub const Messages = "messages";
    pub const Verbose = "verbose";
};

pub const WorkspaceFolder = struct {};
pub const ClientCapabilities = struct {};

pub const DidChangeTextDocumentParams = struct {
    contentChanges: []TextDocumentContentChangeEvent,
    textDocument: VersionedTextDocumentIdentifier,
};

pub const TextDocumentContentChangeEvent = struct {
    range: MaybeDefined(Range),
    rangeLength: MaybeDefined(Integer),
    text: String,
};

pub const TextDocumentIdentifier = struct {
    uri: DocumentUri,
};

pub const VersionedTextDocumentIdentifier = struct {
    uri: DocumentUri,
    version: ?Integer,
};

pub const PublishDiagnosticsParams = struct {
    uri: DocumentUri,
    diagnostics: []Diagnostic,
};
