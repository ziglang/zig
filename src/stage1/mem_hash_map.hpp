/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_MEM_HASH_MAP_HPP
#define ZIG_MEM_HASH_MAP_HPP

#include "mem.hpp"

namespace mem {

template<typename K, typename V, uint32_t (*HashFunction)(K key), bool (*EqualFn)(K a, K b)>
class HashMap {
public:
    void init(Allocator& allocator, int capacity) {
        init_capacity(allocator, capacity);
    }
    void deinit(Allocator& allocator) {
        allocator.deallocate(_entries, _capacity);
    }

    struct Entry {
        K key;
        V value;
        bool used;
        int distance_from_start_index;
    };

    void clear() {
        for (int i = 0; i < _capacity; i += 1) {
            _entries[i].used = false;
        }
        _size = 0;
        _max_distance_from_start_index = 0;
        _modification_count += 1;
    }

    int size() const {
        return _size;
    }

    void put(Allocator& allocator, const K &key, const V &value) {
        _modification_count += 1;
        internal_put(key, value);

        // if we get too full (60%), double the capacity
        if (_size * 5 >= _capacity * 3) {
            Entry *old_entries = _entries;
            int old_capacity = _capacity;
            init_capacity(allocator, _capacity * 2);
            // dump all of the old elements into the new table
            for (int i = 0; i < old_capacity; i += 1) {
                Entry *old_entry = &old_entries[i];
                if (old_entry->used)
                    internal_put(old_entry->key, old_entry->value);
            }
            allocator.deallocate(old_entries, old_capacity);
        }
    }

    Entry *put_unique(Allocator& allocator, const K &key, const V &value) {
        // TODO make this more efficient
        Entry *entry = internal_get(key);
        if (entry)
            return entry;
        put(allocator, key, value);
        return nullptr;
    }

    const V &get(const K &key) const {
        Entry *entry = internal_get(key);
        if (!entry)
            zig_panic("key not found");
        return entry->value;
    }

    Entry *maybe_get(const K &key) const {
        return internal_get(key);
    }

    void maybe_remove(const K &key) {
        if (maybe_get(key)) {
            remove(key);
        }
    }

    void remove(const K &key) {
        _modification_count += 1;
        int start_index = key_to_index(key);
        for (int roll_over = 0; roll_over <= _max_distance_from_start_index; roll_over += 1) {
            int index = (start_index + roll_over) % _capacity;
            Entry *entry = &_entries[index];

            if (!entry->used)
                zig_panic("key not found");

            if (!EqualFn(entry->key, key))
                continue;

            for (; roll_over < _capacity; roll_over += 1) {
                int next_index = (start_index + roll_over + 1) % _capacity;
                Entry *next_entry = &_entries[next_index];
                if (!next_entry->used || next_entry->distance_from_start_index == 0) {
                    entry->used = false;
                    _size -= 1;
                    return;
                }
                *entry = *next_entry;
                entry->distance_from_start_index -= 1;
                entry = next_entry;
            }
            zig_panic("shifting everything in the table");
        }
        zig_panic("key not found");
    }

    class Iterator {
    public:
        Entry *next() {
            if (_inital_modification_count != _table->_modification_count)
                zig_panic("concurrent modification");
            if (_count >= _table->size())
                return NULL;
            for (; _index < _table->_capacity; _index += 1) {
                Entry *entry = &_table->_entries[_index];
                if (entry->used) {
                    _index += 1;
                    _count += 1;
                    return entry;
                }
            }
            zig_panic("no next item");
        }

    private:
        const HashMap * _table;
        // how many items have we returned
        int _count = 0;
        // iterator through the entry array
        int _index = 0;
        // used to detect concurrent modification
        uint32_t _inital_modification_count;
        Iterator(const HashMap * table) :
                _table(table), _inital_modification_count(table->_modification_count) {
        }
        friend HashMap;
    };

    // you must not modify the underlying HashMap while this iterator is still in use
    Iterator entry_iterator() const {
        return Iterator(this);
    }

private:
    Entry *_entries;
    int _capacity;
    int _size;
    int _max_distance_from_start_index;
    // this is used to detect bugs where a hashtable is edited while an iterator is running.
    uint32_t _modification_count;

    void init_capacity(Allocator& allocator, int capacity) {
        _capacity = capacity;
        _entries = allocator.allocate<Entry>(_capacity);
        _size = 0;
        _max_distance_from_start_index = 0;
        for (int i = 0; i < _capacity; i += 1) {
            _entries[i].used = false;
        }
    }

    void internal_put(K key, V value) {
        int start_index = key_to_index(key);
        for (int roll_over = 0, distance_from_start_index = 0;
                roll_over < _capacity; roll_over += 1, distance_from_start_index += 1)
        {
            int index = (start_index + roll_over) % _capacity;
            Entry *entry = &_entries[index];

            if (entry->used && !EqualFn(entry->key, key)) {
                if (entry->distance_from_start_index < distance_from_start_index) {
                    // robin hood to the rescue
                    Entry tmp = *entry;
                    if (distance_from_start_index > _max_distance_from_start_index)
                        _max_distance_from_start_index = distance_from_start_index;
                    *entry = {
                        key,
                        value,
                        true,
                        distance_from_start_index,
                    };
                    key = tmp.key;
                    value = tmp.value;
                    distance_from_start_index = tmp.distance_from_start_index;
                }
                continue;
            }

            if (!entry->used) {
                // adding an entry. otherwise overwriting old value with
                // same key
                _size += 1;
            }

            if (distance_from_start_index > _max_distance_from_start_index)
                _max_distance_from_start_index = distance_from_start_index;
            *entry = {
                key,
                value,
                true,
                distance_from_start_index,
            };
            return;
        }
        zig_panic("put into a full HashMap");
    }


    Entry *internal_get(const K &key) const {
        int start_index = key_to_index(key);
        for (int roll_over = 0; roll_over <= _max_distance_from_start_index; roll_over += 1) {
            int index = (start_index + roll_over) % _capacity;
            Entry *entry = &_entries[index];

            if (!entry->used)
                return NULL;

            if (EqualFn(entry->key, key))
                return entry;
        }
        return NULL;
    }

    int key_to_index(const K &key) const {
        return (int)(HashFunction(key) % ((uint32_t)_capacity));
    }
};

} // namespace mem

#endif
