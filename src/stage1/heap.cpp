/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include <new>
#include <string.h>

#include "config.h"
#include "heap.hpp"

namespace heap {

extern mem::Allocator &bootstrap_allocator;

//
// BootstrapAllocator implementation is identical to CAllocator minus
// profile profile functionality. Splitting off to a base interface doesn't
// seem worthwhile.
//

void BootstrapAllocator::init(const char *name) {}
void BootstrapAllocator::deinit() {}

void *BootstrapAllocator::internal_allocate(const mem::TypeInfo &info, size_t count) {
    return mem::os::calloc(count, info.size);
}

void *BootstrapAllocator::internal_allocate_nonzero(const mem::TypeInfo &info, size_t count) {
    return mem::os::malloc(count * info.size);
}

void *BootstrapAllocator::internal_reallocate(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) {
    auto new_ptr = this->internal_reallocate_nonzero(info, old_ptr, old_count, new_count);
    if (new_count > old_count)
        memset(reinterpret_cast<uint8_t *>(new_ptr) + (old_count * info.size), 0, (new_count - old_count) * info.size);
    return new_ptr;
}

void *BootstrapAllocator::internal_reallocate_nonzero(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) {
    return mem::os::realloc(old_ptr, new_count * info.size);
}

void BootstrapAllocator::internal_deallocate(const mem::TypeInfo &info, void *ptr, size_t count) {
    mem::os::free(ptr);
}

void CAllocator::init(const char *name) { }

void CAllocator::deinit() { }

CAllocator *CAllocator::construct(mem::Allocator *allocator, const char *name) {
    auto p = new(allocator->create<CAllocator>()) CAllocator();
    p->init(name);
    return p;
}

void CAllocator::destruct(mem::Allocator *allocator) {
    this->deinit();
    allocator->destroy(this);
}

void *CAllocator::internal_allocate(const mem::TypeInfo &info, size_t count) {
    return mem::os::calloc(count, info.size);
}

void *CAllocator::internal_allocate_nonzero(const mem::TypeInfo &info, size_t count) {
    return mem::os::malloc(count * info.size);
}

void *CAllocator::internal_reallocate(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) {
    auto new_ptr = this->internal_reallocate_nonzero(info, old_ptr, old_count, new_count);
    if (new_count > old_count)
        memset(reinterpret_cast<uint8_t *>(new_ptr) + (old_count * info.size), 0, (new_count - old_count) * info.size);
    return new_ptr;
}

void *CAllocator::internal_reallocate_nonzero(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) {
    return mem::os::realloc(old_ptr, new_count * info.size);
}

void CAllocator::internal_deallocate(const mem::TypeInfo &info, void *ptr, size_t count) {
    mem::os::free(ptr);
}

struct ArenaAllocator::Impl {
    Allocator *backing;

    // regular allocations bump through a segment of static size
    struct Segment {
        static constexpr size_t size = 65536;
        static constexpr size_t object_threshold = 4096;

        uint8_t data[size];
    };

    // active segment
    Segment *segment;
    size_t segment_offset;

    // keep track of segments
    struct SegmentTrack {
        static constexpr size_t size = (4096 - sizeof(SegmentTrack *)) / sizeof(Segment *);

        // null if first
        SegmentTrack *prev;
        Segment *segments[size];
    };
    static_assert(sizeof(SegmentTrack) <= 4096, "unwanted struct padding");

    // active segment track
    SegmentTrack *segment_track;
    size_t segment_track_remain;

    // individual allocations punted to backing allocator
    struct Object {
        uint8_t *ptr;
        size_t len;
    };

    // keep track of objects
    struct ObjectTrack {
        static constexpr size_t size = (4096 - sizeof(ObjectTrack *)) / sizeof(Object);

        // null if first
        ObjectTrack *prev;
        Object objects[size];
    };
    static_assert(sizeof(ObjectTrack) <= 4096, "unwanted struct padding");

    // active object track
    ObjectTrack *object_track;
    size_t object_track_remain;

    ATTRIBUTE_RETURNS_NOALIAS inline void *allocate(const mem::TypeInfo& info, size_t count);
    inline void *reallocate(const mem::TypeInfo& info, void *old_ptr, size_t old_count, size_t new_count);

    inline void new_segment();
    inline void track_segment();
    inline void track_object(Object object);
};

void *ArenaAllocator::Impl::allocate(const mem::TypeInfo& info, size_t count) {
#ifndef NDEBUG
    // make behavior when size == 0 portable
    if (info.size == 0 || count == 0)
        return nullptr;
#endif
    const size_t nbytes = info.size * count;
    this->segment_offset = (this->segment_offset + (info.alignment - 1)) & ~(info.alignment - 1);
    if (nbytes >= Segment::object_threshold) {
        auto ptr = this->backing->allocate<uint8_t>(nbytes);
        this->track_object({ptr, nbytes});
        return ptr;
    }
    if (this->segment_offset + nbytes > Segment::size)
        this->new_segment();
    auto ptr = &this->segment->data[this->segment_offset];
    this->segment_offset += nbytes;
    return ptr;
}

void *ArenaAllocator::Impl::reallocate(const mem::TypeInfo& info, void *old_ptr, size_t old_count, size_t new_count) {
#ifndef NDEBUG
    // make behavior when size == 0 portable
    if (info.size == 0 && old_ptr == nullptr)
        return nullptr;
#endif
    const size_t new_nbytes = info.size * new_count;
    if (new_nbytes <= info.size * old_count)
        return old_ptr;
    const size_t old_nbytes = info.size * old_count;
    this->segment_offset = (this->segment_offset + (info.alignment - 1)) & ~(info.alignment - 1);
    if (new_nbytes >= Segment::object_threshold) {
        auto new_ptr = this->backing->allocate<uint8_t>(new_nbytes);
        this->track_object({new_ptr, new_nbytes});
        memcpy(new_ptr, old_ptr, old_nbytes);
        return new_ptr;
    }
    if (this->segment_offset + new_nbytes > Segment::size)
        this->new_segment();
    auto new_ptr = &this->segment->data[this->segment_offset];
    this->segment_offset += new_nbytes;
    memcpy(new_ptr, old_ptr, old_nbytes);
    return new_ptr;
}

void ArenaAllocator::Impl::new_segment() {
    this->segment = this->backing->create<Segment>();
    this->segment_offset = 0;
    this->track_segment();
}

void ArenaAllocator::Impl::track_segment() {
    assert(this->segment != nullptr);
    if (this->segment_track_remain < 1) {
        auto prev = this->segment_track;
        this->segment_track = this->backing->create<SegmentTrack>();
        this->segment_track->prev = prev;
        this->segment_track_remain = SegmentTrack::size;
    }
    this->segment_track_remain -= 1;
    this->segment_track->segments[this->segment_track_remain] = this->segment;
}

void ArenaAllocator::Impl::track_object(Object object) {
    if (this->object_track_remain < 1) {
        auto prev = this->object_track;
        this->object_track = this->backing->create<ObjectTrack>();
        this->object_track->prev = prev;
        this->object_track_remain = ObjectTrack::size;
    }
    this->object_track_remain -= 1;
    this->object_track->objects[this->object_track_remain] = object;
}

void ArenaAllocator::init(Allocator *backing, const char *name) {
    this->impl = bootstrap_allocator.create<Impl>();
    {
        auto &r = *this->impl;
        r.backing = backing;
        r.segment_offset = Impl::Segment::size;
    }
}

void ArenaAllocator::deinit() {
    auto &backing = *this->impl->backing;

    // segments
    if (this->impl->segment_track) {
        // active track is not full and bounded by track_remain
        auto prev = this->impl->segment_track->prev;
        {
            auto t = this->impl->segment_track;
            for (size_t i = this->impl->segment_track_remain; i < Impl::SegmentTrack::size; ++i)
                backing.destroy(t->segments[i]);
            backing.destroy(t);
        }

        // previous tracks are full
        for (auto t = prev; t != nullptr;) {
            for (size_t i = 0; i < Impl::SegmentTrack::size; ++i)
                backing.destroy(t->segments[i]);
            prev = t->prev;
            backing.destroy(t);
            t = prev;
        }
    }

    // objects
    if (this->impl->object_track) {
        // active track is not full and bounded by track_remain
        auto prev = this->impl->object_track->prev;
        {
            auto t = this->impl->object_track;
            for (size_t i = this->impl->object_track_remain; i < Impl::ObjectTrack::size; ++i) {
                auto &obj = t->objects[i];
                backing.deallocate(obj.ptr, obj.len);
            }
            backing.destroy(t);
        }

        // previous tracks are full
        for (auto t = prev; t != nullptr;) {
            for (size_t i = 0; i < Impl::ObjectTrack::size; ++i) {
                auto &obj = t->objects[i];
                backing.deallocate(obj.ptr, obj.len);
            }
            prev = t->prev;
            backing.destroy(t);
            t = prev;
        }
    }
}

ArenaAllocator *ArenaAllocator::construct(mem::Allocator *allocator, mem::Allocator *backing, const char *name) {
    auto p = new(allocator->create<ArenaAllocator>()) ArenaAllocator;
    p->init(backing, name);
    return p;
}

void ArenaAllocator::destruct(mem::Allocator *allocator) {
    this->deinit();
    allocator->destroy(this);
}

void *ArenaAllocator::internal_allocate(const mem::TypeInfo &info, size_t count) {
    return this->impl->allocate(info, count);
}

void *ArenaAllocator::internal_allocate_nonzero(const mem::TypeInfo &info, size_t count) {
    return this->impl->allocate(info, count);
}

void *ArenaAllocator::internal_reallocate(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) {
    return this->internal_reallocate_nonzero(info, old_ptr, old_count, new_count);
}

void *ArenaAllocator::internal_reallocate_nonzero(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) {
    return this->impl->reallocate(info, old_ptr, old_count, new_count);
}

void ArenaAllocator::internal_deallocate(const mem::TypeInfo &info, void *ptr, size_t count) {
    // noop
}

BootstrapAllocator bootstrap_allocator_state;
mem::Allocator &bootstrap_allocator = bootstrap_allocator_state;

CAllocator c_allocator_state;
mem::Allocator &c_allocator = c_allocator_state;

} // namespace heap
