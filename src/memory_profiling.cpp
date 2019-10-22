#include "memory_profiling.hpp"
#include "hash_map.hpp"
#include "list.hpp"
#include "util.hpp"
#include <string.h>

#ifdef ZIG_ENABLE_MEM_PROFILE

static bool str_eql_str(const char *a, const char *b) {
    return strcmp(a, b) == 0;
}

static uint32_t str_hash(const char *s) {
    // FNV 32-bit hash
    uint32_t h = 2166136261;
    for (; *s; s += 1) {
        h = h ^ *s;
        h = h * 16777619;
    }
    return h;
}

struct CountAndSize {
    size_t item_count;
    size_t type_size;
};

ZigList<const char *> unknown_names = {};
HashMap<const char *, CountAndSize, str_hash, str_eql_str> usage_table = {};
bool table_active = false;


static const char *get_default_name(const char *name_or_null, size_t type_size) {
    if (name_or_null != nullptr) return name_or_null;
    if (type_size >= unknown_names.length) {
        table_active = false;
        unknown_names.resize(type_size + 1);
        table_active = true;
    }
    if (unknown_names.at(type_size) == nullptr) {
        char buf[100];
        sprintf(buf, "Unknown_%zu%c", type_size, 0);
        unknown_names.at(type_size) = strdup(buf);
    }
    return unknown_names.at(type_size);
}

void memprof_alloc(const char *name, size_t count, size_t type_size) {
    if (!table_active) return;
    if (count == 0) return;
    // temporarily disable during table put
    table_active = false;
    name = get_default_name(name, type_size);
    auto existing_entry = usage_table.put_unique(name, {count, type_size});
    if (existing_entry != nullptr) {
        assert(existing_entry->value.type_size == type_size); // allocated name does not match type
        existing_entry->value.item_count += count;
    }
    table_active = true;
}

void memprof_dealloc(const char *name, size_t count, size_t type_size) {
    if (!table_active) return;
    if (count == 0) return;
    name = get_default_name(name, type_size);
    auto existing_entry = usage_table.maybe_get(name);
    if (existing_entry == nullptr) {
        zig_panic("deallocated more than allocated; compromised memory usage stats");
    }
    if (existing_entry->value.type_size != type_size) {
        zig_panic("deallocated name '%s' does not match expected type size %zu", name, type_size);
    }
    existing_entry->value.item_count -= count;
}

void memprof_init(void) {
    usage_table.init(1024);
    table_active = true;
}

struct MemItem {
    const char *type_name;
    CountAndSize count_and_size;
};

static size_t get_bytes(const MemItem *item) {
    return item->count_and_size.item_count * item->count_and_size.type_size;
}

static int compare_bytes_desc(const void *a, const void *b) {
    size_t size_a = get_bytes((const MemItem *)(a));
    size_t size_b = get_bytes((const MemItem *)(b));
    if (size_a > size_b)
        return -1;
    if (size_a < size_b)
        return 1;
    return 0;
}

void memprof_dump_stats(FILE *file) {
    assert(table_active);
    // disable modifications from this function
    table_active = false;

    ZigList<MemItem> list = {};

    auto it = usage_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        list.append({entry->key, entry->value});
    }

    qsort(list.items, list.length, sizeof(MemItem), compare_bytes_desc);

    size_t total_bytes_used = 0;

    for (size_t i = 0; i < list.length; i += 1) {
        const MemItem *item = &list.at(i);
        fprintf(file, "%s: %zu items, %zu bytes each, total ", item->type_name,
                item->count_and_size.item_count, item->count_and_size.type_size);
        size_t bytes = get_bytes(item);
        zig_pretty_print_bytes(file, bytes);
        fprintf(file, "\n");

        total_bytes_used += bytes;
    }

    fprintf(stderr, "Total bytes used: ");
    zig_pretty_print_bytes(file, total_bytes_used);
    fprintf(file, "\n");

    list.deinit();
    table_active = true;
}

#endif
