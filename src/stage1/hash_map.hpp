/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_HASH_MAP_HPP
#define ZIG_HASH_MAP_HPP

#include "util.hpp"

#include <stdint.h>

template<typename K>
struct MakePointer {
    typedef K const *Type;
    static Type convert(K const &val) {
        return &val;
    }
};

template<typename K>
struct MakePointer<K*> {
    typedef K *Type;
    static Type convert(K * const &val) {
        return val;
    }
};

template<typename K>
struct MakePointer<K const *> {
    typedef K const *Type;
    static Type convert(K const * const &val) {
        return val;
    }
};

template<typename K, typename V,
    uint32_t (*HashFunction)(typename MakePointer<K>::Type key),
    bool (*EqualFn)(typename MakePointer<K>::Type a, typename MakePointer<K>::Type b)>
class HashMap {
public:
    void init(int capacity) {
        init_capacity(capacity);
    }
    void deinit(void) {
        _entries.deinit();
        heap::c_allocator.deallocate(_index_bytes,
                _indexes_len * capacity_index_size(_indexes_len));
    }

    struct Entry {
        uint32_t hash;
        uint32_t distance_from_start_index;
        K key;
        V value;
    };

    void clear() {
        _entries.clear();
        memset(_index_bytes, 0, _indexes_len * capacity_index_size(_indexes_len));
        _max_distance_from_start_index = 0;
        _modification_count += 1;
    }

    size_t size() const {
        return _entries.length;
    }

    void put(const K &key, const V &value) {
        _modification_count += 1;

        // This allows us to take a pointer to an entry in `internal_put` which
        // will not become a dead pointer when the array list is appended.
        _entries.ensure_capacity(_entries.length + 1);

        if (_index_bytes == nullptr) {
            if (_entries.length < 16) {
                _entries.append({HashFunction(MakePointer<K>::convert(key)), 0, key, value});
                return;
            } else {
                _indexes_len = 32;
                _index_bytes = heap::c_allocator.allocate<uint8_t>(_indexes_len);
                _max_distance_from_start_index = 0;
                for (size_t i = 0; i < _entries.length; i += 1) {
                    Entry *entry = &_entries.items[i];
                    put_index(entry, i, _index_bytes);
                }
                return internal_put(key, value, _index_bytes);
            }
        }

        // if we would get too full (60%), double the indexes size
        if ((_entries.length + 1) * 5 >= _indexes_len * 3) {
            heap::c_allocator.deallocate(_index_bytes,
                    _indexes_len * capacity_index_size(_indexes_len));
            _indexes_len *= 2;
            size_t sz = capacity_index_size(_indexes_len);
            // This zero initializes the bytes, setting them all empty.
            _index_bytes = heap::c_allocator.allocate<uint8_t>(_indexes_len * sz);
            _max_distance_from_start_index = 0;
            for (size_t i = 0; i < _entries.length; i += 1) {
                Entry *entry = &_entries.items[i];
                switch (sz) {
                    case 1:
                        put_index(entry, i, (uint8_t*)_index_bytes);
                        continue;
                    case 2:
                        put_index(entry, i, (uint16_t*)_index_bytes);
                        continue;
                    case 4:
                        put_index(entry, i, (uint32_t*)_index_bytes);
                        continue;
                    default:
                        put_index(entry, i, (size_t*)_index_bytes);
                        continue;
                }
            }
        }

        switch (capacity_index_size(_indexes_len)) {
            case 1: return internal_put(key, value, (uint8_t*)_index_bytes);
            case 2: return internal_put(key, value, (uint16_t*)_index_bytes);
            case 4: return internal_put(key, value, (uint32_t*)_index_bytes);
            default: return internal_put(key, value, (size_t*)_index_bytes);
        }
    }

    Entry *put_unique(const K &key, const V &value) {
        // TODO make this more efficient
        Entry *entry = internal_get(key);
        if (entry)
            return entry;
        put(key, value);
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

    bool remove(const K &key) {
        bool deleted_something = maybe_remove(key);
        if (!deleted_something)
            zig_panic("key not found");
        return deleted_something;
    }

    bool maybe_remove(const K &key) {
        _modification_count += 1;
        if (_index_bytes == nullptr) {
            uint32_t hash = HashFunction(MakePointer<K>::convert(key));
            for (size_t i = 0; i < _entries.length; i += 1) {
                if (_entries.items[i].hash == hash && EqualFn(MakePointer<K>::convert(_entries.items[i].key), MakePointer<K>::convert(key))) {
                    _entries.swap_remove(i);
                    return true;
                }
            }
            return false;
        }
        switch (capacity_index_size(_indexes_len)) {
            case 1: return internal_remove(key, (uint8_t*)_index_bytes);
            case 2: return internal_remove(key, (uint16_t*)_index_bytes);
            case 4: return internal_remove(key, (uint32_t*)_index_bytes);
            default: return internal_remove(key, (size_t*)_index_bytes);
        }
    }

    class Iterator {
    public:
        Entry *next() {
            if (_inital_modification_count != _table->_modification_count)
                zig_panic("concurrent modification");
            if (_index >= _table->_entries.length)
                return nullptr;
            Entry *entry = &_table->_entries.items[_index];
            _index += 1;
            return entry;
        }
    private:
        const HashMap * _table;
        // iterator through the entry array
        size_t _index = 0;
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
    // Maintains insertion order.
    ZigList<Entry> _entries;
    // If _indexes_len is less than 2**8, this is an array of uint8_t.
    // If _indexes_len is less than 2**16, it is an array of uint16_t.
    // If _indexes_len is less than 2**32, it is an array of uint32_t.
    // Otherwise it is size_t.
    // It's off by 1. 0 means empty slot, 1 means index 0, etc.
    uint8_t *_index_bytes;
    // This is the number of indexes. When indexes are bytes, it equals number of bytes.
    // When indexes are uint16_t, _indexes_len is half the number of bytes.
    size_t _indexes_len;

    size_t _max_distance_from_start_index;
    // This is used to detect bugs where a hashtable is edited while an iterator is running.
    uint32_t _modification_count;

    void init_capacity(size_t capacity) {
        _entries = {};
        _entries.ensure_capacity(capacity);
        _indexes_len = 0;
        if (capacity >= 16) {
            // So that at capacity it will only be 60% full.
            _indexes_len = capacity * 5 / 3;
            size_t sz = capacity_index_size(_indexes_len);
            // This zero initializes _index_bytes which sets them all to empty.
            _index_bytes = heap::c_allocator.allocate<uint8_t>(_indexes_len * sz);
        } else {
            _index_bytes = nullptr;
        }

        _max_distance_from_start_index = 0;
        _modification_count = 0;
    }

    static size_t capacity_index_size(size_t len) {
        if (len < UINT8_MAX)
            return 1;
        if (len < UINT16_MAX)
            return 2;
        if (len < UINT32_MAX)
            return 4;
        return sizeof(size_t);
    }

    template <typename I>
    void internal_put(const K &key, const V &value, I *indexes) {
        uint32_t hash = HashFunction(MakePointer<K>::convert(key));
        uint32_t distance_from_start_index = 0;
        size_t start_index = hash_to_index(hash);
        for (size_t roll_over = 0; roll_over < _indexes_len;
                roll_over += 1, distance_from_start_index += 1)
        {
            size_t index_index = (start_index + roll_over) % _indexes_len;
            I index_data = indexes[index_index];
            if (index_data == 0) {
                _entries.append_assuming_capacity({ hash, distance_from_start_index, key, value });
                indexes[index_index] = _entries.length;
                if (distance_from_start_index > _max_distance_from_start_index)
                    _max_distance_from_start_index = distance_from_start_index;
                return;
            }
            // This pointer survives the following append because we call
            // _entries.ensure_capacity before internal_put.
            Entry *entry = &_entries.items[index_data - 1];
            if (entry->hash == hash && EqualFn(MakePointer<K>::convert(entry->key), MakePointer<K>::convert(key))) {
                *entry = {hash, distance_from_start_index, key, value};
                if (distance_from_start_index > _max_distance_from_start_index)
                    _max_distance_from_start_index = distance_from_start_index;
                return;
            }
            if (entry->distance_from_start_index < distance_from_start_index) {
                // In this case, we did not find the item. We will put a new entry.
                // However, we will use this index for the new entry, and move
                // the previous index down the line, to keep the _max_distance_from_start_index
                // as small as possible.
                _entries.append_assuming_capacity({ hash, distance_from_start_index, key, value });
                indexes[index_index] = _entries.length;
                if (distance_from_start_index > _max_distance_from_start_index)
                    _max_distance_from_start_index = distance_from_start_index;

                distance_from_start_index = entry->distance_from_start_index;

                // Find somewhere to put the index we replaced by shifting
                // following indexes backwards.
                roll_over += 1;
                distance_from_start_index += 1;
                for (; roll_over < _indexes_len; roll_over += 1, distance_from_start_index += 1) {
                    size_t index_index = (start_index + roll_over) % _indexes_len;
                    I next_index_data = indexes[index_index];
                    if (next_index_data == 0) {
                        if (distance_from_start_index > _max_distance_from_start_index)
                            _max_distance_from_start_index = distance_from_start_index;
                        entry->distance_from_start_index = distance_from_start_index;
                        indexes[index_index] = index_data;
                        return;
                    }
                    Entry *next_entry = &_entries.items[next_index_data - 1];
                    if (next_entry->distance_from_start_index < distance_from_start_index) {
                        if (distance_from_start_index > _max_distance_from_start_index)
                            _max_distance_from_start_index = distance_from_start_index;
                        entry->distance_from_start_index = distance_from_start_index;
                        indexes[index_index] = index_data;
                        distance_from_start_index = next_entry->distance_from_start_index;
                        entry = next_entry;
                        index_data = next_index_data;
                    }
                }
                zig_unreachable();
            }
        }
        zig_unreachable();
    }

    template <typename I>
    void put_index(Entry *entry, size_t entry_index, I *indexes) {
        size_t start_index = hash_to_index(entry->hash);
        size_t index_data = entry_index + 1;
        for (size_t roll_over = 0, distance_from_start_index = 0;
                roll_over < _indexes_len; roll_over += 1, distance_from_start_index += 1)
        {
            size_t index_index = (start_index + roll_over) % _indexes_len;
            size_t next_index_data = indexes[index_index];
            if (next_index_data == 0) {
                if (distance_from_start_index > _max_distance_from_start_index)
                    _max_distance_from_start_index = distance_from_start_index;
                entry->distance_from_start_index = distance_from_start_index;
                indexes[index_index] = index_data;
                return;
            }
            Entry *next_entry = &_entries.items[next_index_data - 1];
            if (next_entry->distance_from_start_index < distance_from_start_index) {
                if (distance_from_start_index > _max_distance_from_start_index)
                    _max_distance_from_start_index = distance_from_start_index;
                entry->distance_from_start_index = distance_from_start_index;
                indexes[index_index] = index_data;
                distance_from_start_index = next_entry->distance_from_start_index;
                entry = next_entry;
                index_data = next_index_data;
            }
        }
        zig_unreachable();
    }

    Entry *internal_get(const K &key) const {
        if (_index_bytes == nullptr) {
            uint32_t hash = HashFunction(MakePointer<K>::convert(key));
            for (size_t i = 0; i < _entries.length; i += 1) {
                if (_entries.items[i].hash == hash && EqualFn(MakePointer<K>::convert(_entries.items[i].key), MakePointer<K>::convert(key))) {
                    return &_entries.items[i];
                }
            }
            return nullptr;
        }
        switch (capacity_index_size(_indexes_len)) {
            case 1: return internal_get2(key, (uint8_t*)_index_bytes);
            case 2: return internal_get2(key, (uint16_t*)_index_bytes);
            case 4: return internal_get2(key, (uint32_t*)_index_bytes);
            default: return internal_get2(key, (size_t*)_index_bytes);
        }
    }

    template <typename I>
    Entry *internal_get2(const K &key, I *indexes) const {
        uint32_t hash = HashFunction(MakePointer<K>::convert(key));
        size_t start_index = hash_to_index(hash);
        for (size_t roll_over = 0; roll_over <= _max_distance_from_start_index; roll_over += 1) {
            size_t index_index = (start_index + roll_over) % _indexes_len;
            size_t index_data = indexes[index_index];
            if (index_data == 0)
                return nullptr;

            Entry *entry = &_entries.items[index_data - 1];
            if (entry->hash == hash && EqualFn(MakePointer<K>::convert(entry->key), MakePointer<K>::convert(key)))
                return entry;
        }
        return nullptr;
    }

    size_t hash_to_index(uint32_t hash) const {
        return ((size_t)hash) % _indexes_len;
    }

    template <typename I>
    bool internal_remove(const K &key, I *indexes) {
        uint32_t hash = HashFunction(MakePointer<K>::convert(key));
        size_t start_index = hash_to_index(hash);
        for (size_t roll_over = 0; roll_over <= _max_distance_from_start_index; roll_over += 1) {
            size_t index_index = (start_index + roll_over) % _indexes_len;
            size_t index_data = indexes[index_index];
            if (index_data == 0)
                return false;

            size_t index = index_data - 1;
            Entry *entry = &_entries.items[index];
            if (entry->hash != hash || !EqualFn(MakePointer<K>::convert(entry->key), MakePointer<K>::convert(key)))
                continue;

            size_t prev_index = index_index;
            _entries.swap_remove(index);
            if (_entries.length > 0 && _entries.length != index) {
                // Because of the swap remove, now we need to update the index that was
                // pointing to the last entry and is now pointing to this removed item slot.
                update_entry_index(_entries.length, index, indexes);
            }

            // Now we have to shift over the following indexes.
            roll_over += 1;
            for (; roll_over < _indexes_len; roll_over += 1) {
                size_t next_index = (start_index + roll_over) % _indexes_len;
                if (indexes[next_index] == 0) {
                    indexes[prev_index] = 0;
                    return true;
                }
                Entry *next_entry = &_entries.items[indexes[next_index] - 1];
                if (next_entry->distance_from_start_index == 0) {
                    indexes[prev_index] = 0;
                    return true;
                }
                indexes[prev_index] = indexes[next_index];
                prev_index = next_index;
                next_entry->distance_from_start_index -= 1;
            }
            zig_unreachable();
        }
        return false;
    }

    template <typename I>
    void update_entry_index(size_t old_entry_index, size_t new_entry_index, I *indexes) {
        size_t start_index = hash_to_index(_entries.items[new_entry_index].hash);
        for (size_t roll_over = 0; roll_over <= _max_distance_from_start_index; roll_over += 1) {
            size_t index_index = (start_index + roll_over) % _indexes_len;
            if (indexes[index_index] == old_entry_index + 1) {
                indexes[index_index] = new_entry_index + 1;
                return;
            }
        }
        zig_unreachable();
    }
};
#endif
