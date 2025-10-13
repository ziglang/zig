const std = @import("std");
const gpa = std.heap.wasm_allocator;
const abi = std.Build.abi.time_report;
const fmtEscapeHtml = @import("root").fmtEscapeHtml;
const step_list = &@import("root").step_list;

const js = struct {
    extern "time_report" fn updateGeneric(
        /// The index of the step.
        step_idx: u32,
        // The HTML which will be used to populate the template slots.
        inner_html_ptr: [*]const u8,
        inner_html_len: usize,
    ) void;
    extern "time_report" fn updateCompile(
        /// The index of the step.
        step_idx: u32,
        // The HTML which will be used to populate the template slots.
        inner_html_ptr: [*]const u8,
        inner_html_len: usize,
        // The HTML which will populate the <tbody> of the file table.
        file_table_html_ptr: [*]const u8,
        file_table_html_len: usize,
        // The HTML which will populate the <tbody> of the decl table.
        decl_table_html_ptr: [*]const u8,
        decl_table_html_len: usize,
        /// Whether the LLVM backend was used. If not, LLVM-specific statistics are hidden.
        use_llvm: bool,
    ) void;
};

pub fn genericResultMessage(msg_bytes: []u8) error{OutOfMemory}!void {
    if (msg_bytes.len != @sizeOf(abi.GenericResult)) @panic("malformed GenericResult message");
    const msg: *const abi.GenericResult = @ptrCast(msg_bytes);
    if (msg.step_idx >= step_list.*.len) @panic("malformed GenericResult message");
    const inner_html = try std.fmt.allocPrint(gpa,
        \\<code slot="step-name">{[step_name]f}</code>
        \\<span slot="stat-total-time">{[stat_total_time]D}</span>
    , .{
        .step_name = fmtEscapeHtml(step_list.*[msg.step_idx].name),
        .stat_total_time = msg.ns_total,
    });
    defer gpa.free(inner_html);
    js.updateGeneric(msg.step_idx, inner_html.ptr, inner_html.len);
}

pub fn compileResultMessage(msg_bytes: []u8) error{ OutOfMemory, WriteFailed }!void {
    const max_table_rows = 500;

    if (msg_bytes.len < @sizeOf(abi.CompileResult)) @panic("malformed CompileResult message");
    const hdr: *const abi.CompileResult = @ptrCast(msg_bytes[0..@sizeOf(abi.CompileResult)]);
    if (hdr.step_idx >= step_list.*.len) @panic("malformed CompileResult message");
    var trailing = msg_bytes[@sizeOf(abi.CompileResult)..];

    const llvm_pass_timings = trailing[0..hdr.llvm_pass_timings_len];
    trailing = trailing[hdr.llvm_pass_timings_len..];

    const FileTimeReport = struct {
        name: []const u8,
        ns_sema: u64,
        ns_codegen: u64,
        ns_link: u64,
    };
    const DeclTimeReport = struct {
        file_name: []const u8,
        name: []const u8,
        sema_count: u32,
        ns_sema: u64,
        ns_codegen: u64,
        ns_link: u64,
    };

    const slowest_files = try gpa.alloc(FileTimeReport, hdr.files_len);
    defer gpa.free(slowest_files);

    const slowest_decls = try gpa.alloc(DeclTimeReport, hdr.decls_len);
    defer gpa.free(slowest_decls);

    for (slowest_files) |*file_out| {
        const i = std.mem.indexOfScalar(u8, trailing, 0) orelse @panic("malformed CompileResult message");
        file_out.* = .{
            .name = trailing[0..i],
            .ns_sema = 0,
            .ns_codegen = 0,
            .ns_link = 0,
        };
        trailing = trailing[i + 1 ..];
    }

    for (slowest_decls) |*decl_out| {
        const i = std.mem.indexOfScalar(u8, trailing, 0) orelse @panic("malformed CompileResult message");
        const file_idx = std.mem.readInt(u32, trailing[i..][1..5], .little);
        const sema_count = std.mem.readInt(u32, trailing[i..][5..9], .little);
        const sema_ns = std.mem.readInt(u64, trailing[i..][9..17], .little);
        const codegen_ns = std.mem.readInt(u64, trailing[i..][17..25], .little);
        const link_ns = std.mem.readInt(u64, trailing[i..][25..33], .little);
        const file = &slowest_files[file_idx];
        decl_out.* = .{
            .file_name = file.name,
            .name = trailing[0..i],
            .sema_count = sema_count,
            .ns_sema = sema_ns,
            .ns_codegen = codegen_ns,
            .ns_link = link_ns,
        };
        trailing = trailing[i + 33 ..];
        file.ns_sema += sema_ns;
        file.ns_codegen += codegen_ns;
        file.ns_link += link_ns;
    }

    const S = struct {
        fn fileLessThan(_: void, lhs: FileTimeReport, rhs: FileTimeReport) bool {
            const lhs_ns = lhs.ns_sema + lhs.ns_codegen + lhs.ns_link;
            const rhs_ns = rhs.ns_sema + rhs.ns_codegen + rhs.ns_link;
            return lhs_ns > rhs_ns; // flipped to sort in reverse order
        }
        fn declLessThan(_: void, lhs: DeclTimeReport, rhs: DeclTimeReport) bool {
            //if (true) return lhs.sema_count > rhs.sema_count;
            const lhs_ns = lhs.ns_sema + lhs.ns_codegen + lhs.ns_link;
            const rhs_ns = rhs.ns_sema + rhs.ns_codegen + rhs.ns_link;
            return lhs_ns > rhs_ns; // flipped to sort in reverse order
        }
    };
    std.mem.sort(FileTimeReport, slowest_files, {}, S.fileLessThan);
    std.mem.sort(DeclTimeReport, slowest_decls, {}, S.declLessThan);

    const stats = hdr.stats;
    const inner_html = try std.fmt.allocPrint(gpa,
        \\<code slot="step-name">{[step_name]f}</code>
        \\<span slot="stat-reachable-files">{[stat_reachable_files]d}</span>
        \\<span slot="stat-imported-files">{[stat_imported_files]d}</span>
        \\<span slot="stat-generic-instances">{[stat_generic_instances]d}</span>
        \\<span slot="stat-inline-calls">{[stat_inline_calls]d}</span>
        \\<span slot="stat-compilation-time">{[stat_compilation_time]D}</span>
        \\<span slot="cpu-time-parse">{[cpu_time_parse]D}</span>
        \\<span slot="cpu-time-astgen">{[cpu_time_astgen]D}</span>
        \\<span slot="cpu-time-sema">{[cpu_time_sema]D}</span>
        \\<span slot="cpu-time-codegen">{[cpu_time_codegen]D}</span>
        \\<span slot="cpu-time-link">{[cpu_time_link]D}</span>
        \\<span slot="real-time-files">{[real_time_files]D}</span>
        \\<span slot="real-time-decls">{[real_time_decls]D}</span>
        \\<span slot="real-time-llvm-emit">{[real_time_llvm_emit]D}</span>
        \\<span slot="real-time-link-flush">{[real_time_link_flush]D}</span>
        \\<pre slot="llvm-pass-timings"><code>{[llvm_pass_timings]f}</code></pre>
        \\
    , .{
        .step_name = fmtEscapeHtml(step_list.*[hdr.step_idx].name),
        .stat_reachable_files = stats.n_reachable_files,
        .stat_imported_files = stats.n_imported_files,
        .stat_generic_instances = stats.n_generic_instances,
        .stat_inline_calls = stats.n_inline_calls,
        .stat_compilation_time = hdr.ns_total,

        .cpu_time_parse = stats.cpu_ns_parse,
        .cpu_time_astgen = stats.cpu_ns_astgen,
        .cpu_time_sema = stats.cpu_ns_sema,
        .cpu_time_codegen = stats.cpu_ns_codegen,
        .cpu_time_link = stats.cpu_ns_link,
        .real_time_files = stats.real_ns_files,
        .real_time_decls = stats.real_ns_decls,
        .real_time_llvm_emit = stats.real_ns_llvm_emit,
        .real_time_link_flush = stats.real_ns_link_flush,

        .llvm_pass_timings = fmtEscapeHtml(llvm_pass_timings),
    });
    defer gpa.free(inner_html);

    var file_table_html: std.Io.Writer.Allocating = .init(gpa);
    defer file_table_html.deinit();

    for (slowest_files[0..@min(max_table_rows, slowest_files.len)]) |file| {
        try file_table_html.writer.print(
            \\<tr>
            \\  <th scope="row"><code>{f}</code></th>
            \\  <td>{D}</td>
            \\  <td>{D}</td>
            \\  <td>{D}</td>
            \\  <td>{D}</td>
            \\</tr>
            \\
        , .{
            fmtEscapeHtml(file.name),
            file.ns_sema,
            file.ns_codegen,
            file.ns_link,
            file.ns_sema + file.ns_codegen + file.ns_link,
        });
    }
    if (slowest_files.len > max_table_rows) {
        try file_table_html.writer.print(
            \\<tr><td colspan="4">{d} more rows omitted</td></tr>
            \\
        , .{slowest_files.len - max_table_rows});
    }

    var decl_table_html: std.Io.Writer.Allocating = .init(gpa);
    defer decl_table_html.deinit();

    for (slowest_decls[0..@min(max_table_rows, slowest_decls.len)]) |decl| {
        try decl_table_html.writer.print(
            \\<tr>
            \\  <th scope="row"><code>{f}</code></th>
            \\  <th scope="row"><code>{f}</code></th>
            \\  <td>{d}</td>
            \\  <td>{D}</td>
            \\  <td>{D}</td>
            \\  <td>{D}</td>
            \\  <td>{D}</td>
            \\</tr>
            \\
        , .{
            fmtEscapeHtml(decl.file_name),
            fmtEscapeHtml(decl.name),
            decl.sema_count,
            decl.ns_sema,
            decl.ns_codegen,
            decl.ns_link,
            decl.ns_sema + decl.ns_codegen + decl.ns_link,
        });
    }
    if (slowest_decls.len > max_table_rows) {
        try decl_table_html.writer.print(
            \\<tr><td colspan="6">{d} more rows omitted</td></tr>
            \\
        , .{slowest_decls.len - max_table_rows});
    }

    js.updateCompile(
        hdr.step_idx,
        inner_html.ptr,
        inner_html.len,
        file_table_html.written().ptr,
        file_table_html.written().len,
        decl_table_html.written().ptr,
        decl_table_html.written().len,
        hdr.flags.use_llvm,
    );
}
