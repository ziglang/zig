/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "config.h"

#ifdef ZIG_ENABLE_MEM_PROFILE

#include "mem.hpp"
#include "mem_list.hpp"
#include "mem_profile.hpp"
#include "heap.hpp"

namespace mem {

void Profile::init(const char *name, const char *kind) {
    this->name = name;
    this->kind = kind;
    this->usage_table.init(heap::bootstrap_allocator, 1024);
}

void Profile::deinit() {
    assert(this->name != nullptr);
    if (mem::report_print)
        this->print_report();
    this->usage_table.deinit(heap::bootstrap_allocator);
    this->name = nullptr;
}

void Profile::record_alloc(const TypeInfo &info, size_t count) {
    if (count == 0) return;
    auto existing_entry = this->usage_table.put_unique(
        heap::bootstrap_allocator,
        UsageKey{info.name_ptr, info.name_len},
        Entry{info, 1, count, 0, 0} );
    if (existing_entry != nullptr) {
        assert(existing_entry->value.info.size == info.size); // allocated name does not match type
        existing_entry->value.alloc.calls += 1;
        existing_entry->value.alloc.objects += count;
    }
}

void Profile::record_dealloc(const TypeInfo &info, size_t count) {
    if (count == 0) return;
    auto existing_entry = this->usage_table.maybe_get(UsageKey{info.name_ptr, info.name_len});
    if (existing_entry == nullptr) {
        fprintf(stderr, "deallocated name '");
        for (size_t i = 0; i < info.name_len; ++i)
            fputc(info.name_ptr[i], stderr);
        zig_panic("' (size %zu) not found in allocated table; compromised memory usage stats", info.size);
    }
    if (existing_entry->value.info.size != info.size) {
        fprintf(stderr, "deallocated name '");
        for (size_t i = 0; i < info.name_len; ++i)
            fputc(info.name_ptr[i], stderr);
        zig_panic("' does not match expected type size %zu", info.size);
    }
    assert(existing_entry->value.alloc.calls - existing_entry->value.dealloc.calls > 0);
    assert(existing_entry->value.alloc.objects - existing_entry->value.dealloc.objects >= count);
    existing_entry->value.dealloc.calls += 1;
    existing_entry->value.dealloc.objects += count;
}

static size_t entry_remain_total_bytes(const Profile::Entry *entry) {
    return (entry->alloc.objects - entry->dealloc.objects) * entry->info.size;
}

static int entry_compare(const void *a, const void *b) {
    size_t total_a = entry_remain_total_bytes(*reinterpret_cast<Profile::Entry *const *>(a));
    size_t total_b = entry_remain_total_bytes(*reinterpret_cast<Profile::Entry *const *>(b));
    if (total_a > total_b)
        return -1;
    if (total_a < total_b)
        return 1;
    return 0;
};

void Profile::print_report(FILE *file) {
    if (!file) {
        file = report_file;
        if (!file)
            file = stderr;
    }
    fprintf(file, "\n--- MEMORY PROFILE REPORT [%s]: %s ---\n", this->kind, this->name);

    List<const Entry *> list;
    auto it = this->usage_table.entry_iterator();
    for (;;) {
        auto entry = it.next();
        if (!entry)
            break;
        list.append(&heap::bootstrap_allocator, &entry->value);
    }

    qsort(list.items, list.length, sizeof(const Entry *), entry_compare);

    size_t total_bytes_alloc = 0;
    size_t total_bytes_dealloc = 0;

    size_t total_calls_alloc = 0;
    size_t total_calls_dealloc = 0;

    for (size_t i = 0; i < list.length; i += 1) {
        const Entry *entry = list.at(i);
        fprintf(file, "  ");
        for (size_t j = 0; j < entry->info.name_len; ++j)
            fputc(entry->info.name_ptr[j], file);
        fprintf(file, ": %zu bytes each", entry->info.size);

        fprintf(file, ", alloc{ %zu calls, %zu objects, total ", entry->alloc.calls, entry->alloc.objects);
        const auto alloc_num_bytes = entry->alloc.objects * entry->info.size;
        zig_pretty_print_bytes(file, alloc_num_bytes);

        fprintf(file, " }, dealloc{ %zu calls, %zu objects, total ", entry->dealloc.calls, entry->dealloc.objects);
        const auto dealloc_num_bytes = entry->dealloc.objects * entry->info.size;
        zig_pretty_print_bytes(file, dealloc_num_bytes);

        fprintf(file, " }, remain{ %zu calls, %zu objects, total ",
            entry->alloc.calls - entry->dealloc.calls,
            entry->alloc.objects - entry->dealloc.objects );
        const auto remain_num_bytes = alloc_num_bytes - dealloc_num_bytes;
        zig_pretty_print_bytes(file, remain_num_bytes);

        fprintf(file, " }\n");

        total_bytes_alloc += alloc_num_bytes;
        total_bytes_dealloc += dealloc_num_bytes;

        total_calls_alloc += entry->alloc.calls;
        total_calls_dealloc += entry->dealloc.calls;
    }

    fprintf(file, "\n  Total bytes allocated: ");
    zig_pretty_print_bytes(file, total_bytes_alloc);
    fprintf(file, ", deallocated: ");
    zig_pretty_print_bytes(file, total_bytes_dealloc);
    fprintf(file, ", remaining: ");
    zig_pretty_print_bytes(file, total_bytes_alloc - total_bytes_dealloc);

    fprintf(file, "\n  Total calls alloc: %zu, dealloc: %zu, remain: %zu\n",
        total_calls_alloc, total_calls_dealloc, (total_calls_alloc - total_calls_dealloc));

    list.deinit(&heap::bootstrap_allocator);
}

uint32_t Profile::usage_hash(UsageKey key) {
    // FNV 32-bit hash
    uint32_t h = 2166136261;
    for (size_t i = 0; i < key.name_len; ++i) {
        h = h ^ key.name_ptr[i];
        h = h * 16777619;
    }
    return h;
}

bool Profile::usage_equal(UsageKey a, UsageKey b) {
    return memcmp(a.name_ptr, b.name_ptr, a.name_len > b.name_len ? a.name_len : b.name_len) == 0;
}

void InternCounters::print_report(FILE *file) {
    if (!file) {
        file = report_file;
        if (!file)
            file = stderr;
    }
    fprintf(file, "\n--- IR INTERNING REPORT ---\n");
    fprintf(file, "  undefined: interned %zu times\n", intern_counters.x_undefined);
    fprintf(file, "  void: interned %zu times\n", intern_counters.x_void);
    fprintf(file, "  null: interned %zu times\n", intern_counters.x_null);
    fprintf(file, "  unreachable: interned %zu times\n", intern_counters.x_unreachable);
    fprintf(file, "  zero_byte: interned %zu times\n", intern_counters.zero_byte);
}

InternCounters intern_counters;

} // namespace mem

#endif
