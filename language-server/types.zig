const std = @import("std");
const json = std.json;
const MaybeDefined = @import("json_serialize.zig").MaybeDefined;

pub const String = []const u8;
pub const Integer = i64;
pub const Float = f64;
pub const Bool = bool;
pub const Array = json.Array;
pub const Object = json.ObjectMap;
pub const Any = json.Value;

// Specification:
// https://microsoft.github.io/language-server-protocol/specifications/specification-current/

pub const RequestId = union(enum) {
    String: String,
    Integer: Integer,
    Float: Float,
};

pub const Request = struct {
    jsonrpc: String = "2.0",
    method: String,

    /// Must be an Array or an Object
    params: Any,
    id: MaybeDefined(RequestId) = .NotDefined,

    pub fn validate(self: *const Request) bool {
        if (!std.mem.eql(u8, self.jsonrpc, "2.0")) {
            return false;
        }
        return switch (self.params) {
            .Object, .Array => true,
            else => false,
        };
    }
};

pub const Response = struct {
    jsonrpc: String = "2.0",
    @"error": MaybeDefined(Error) = .NotDefined,
    result: MaybeDefined(Any) = .NotDefined,
    id: ?RequestId,

    pub const Error = struct {
        code: Integer,
        message: String,
        data: MaybeDefined(Any),
    };

    pub fn validate(self: *const Response) bool {
        if (!std.mem.eql(u8, self.jsonrpc, "2.0")) {
            return false;
        }

        const errorDefined = self.@"error" == .Defined;
        const resultDefined = self.result == .Defined;

        // exactly one of them must be defined
        return errorDefined != resultDefined;
    }
};

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
    character: Integer,
};

pub const Range = struct {
    start: Position,
    end: Position,
};

pub const Location = struct {
    uri: DocumentUri,
    range: Range,
};

pub const LocationLink = struct {
    originSelectionRange: MaybeDefined(Range) = .NotDefined,
    targetUri: DocumentUri,
    targetRange: Range,
    targetSelectionRange: Range,
};

pub const Diagnostic = struct {
    range: Range,
    severity: MaybeDefined(Integer) = .NotDefined,
    code: MaybeDefined(Any) = .NotDefined,
    source: MaybeDefined(String) = .NotDefined,
    message: String,
    relatedInformation: MaybeDefined([]DiagnosticRelatedInformation) = .NotDefined,
};

pub const DiagnosticRelatedInformation = struct {
    location: Location,
    message: String,
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
    arguments: MaybeDefined([]Any),
};

pub const TextEdit = struct {
    range: Range,
    newText: String,
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
    // trace: MaybeDefined(String),
    // workspaceFolders: MaybeDefined(?[]WorkspaceFolder),
};

pub const InitializedParams = struct {};

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

pub const CompletionParams = struct {
    textDocument: TextDocumentIdentifier,
    position: Position,
    context: MaybeDefined(CompletionContext),
};

pub const CompletionTriggerKind = struct {
    pub const Invoked = 1;
    pub const TriggerCharacter = 2;
    pub const TriggerForIncompleteCompletions = 3;
};

pub const CompletionContext = struct {
    triggerKind: Integer,
    triggerCharacter: MaybeDefined(String),
};

// not complete definition
pub const CompletionItem = struct {
    label: String,
    kind: MaybeDefined(Integer) = .NotDefined,
    textEdit: MaybeDefined(TextEdit) = .NotDefined,
    filterText: MaybeDefined(String) = .NotDefined,
};

pub const CompletionItemKind = struct {
    pub const Text = 1;
    pub const Method = 2;
    pub const Function = 3;
    pub const Constructor = 4;
    pub const Field = 5;
    pub const Variable = 6;
    pub const Class = 7;
    pub const Interface = 8;
    pub const Module = 9;
    pub const Property = 10;
    pub const Unit = 11;
    pub const Value = 12;
    pub const Enum = 13;
    pub const Keyword = 14;
    pub const Snippet = 15;
    pub const Color = 16;
    pub const File = 17;
    pub const Reference = 18;
    pub const Folder = 19;
    pub const EnumMember = 20;
    pub const Constant = 21;
    pub const Struct = 22;
    pub const Event = 23;
    pub const Operator = 24;
    pub const TypeParameter = 25;
};

pub const DidCloseTextDocumentParams = struct {
    textDocument: TextDocumentIdentifier,
};

pub const DidOpenTextDocumentParams = struct {
    textDocument: TextDocumentItem,
};

pub const TextDocumentItem = struct {
    uri: DocumentUri,
    languageId: String,
    version: Integer,
    text: String,
};
