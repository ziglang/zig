//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fallback_malloc.h"

#include <__threading_support>
#ifndef _LIBCXXABI_HAS_NO_THREADS
#if defined(__ELF__) && defined(_LIBCXXABI_LINK_PTHREAD_LIB)
#pragma comment(lib, "pthread")
#endif
#endif

#include <stdlib.h> // for malloc, calloc, free
#include <string.h> // for memset
#include <new> // for std::__libcpp_aligned_{alloc,free}

//  A small, simple heap manager based (loosely) on
//  the startup heap manager from FreeBSD, optimized for space.
//
//  Manages a fixed-size memory pool, supports malloc and free only.
//  No support for realloc.
//
//  Allocates chunks in multiples of four bytes, with a four byte header
//  for each chunk. The overhead of each chunk is kept low by keeping pointers
//  as two byte offsets within the heap, rather than (4 or 8 byte) pointers.

namespace {

// When POSIX threads are not available, make the mutex operations a nop
#ifndef _LIBCXXABI_HAS_NO_THREADS
_LIBCPP_SAFE_STATIC
static std::__libcpp_mutex_t heap_mutex = _LIBCPP_MUTEX_INITIALIZER;
#else
static void* heap_mutex = 0;
#endif

class mutexor {
public:
#ifndef _LIBCXXABI_HAS_NO_THREADS
  mutexor(std::__libcpp_mutex_t* m) : mtx_(m) {
    std::__libcpp_mutex_lock(mtx_);
  }
  ~mutexor() { std::__libcpp_mutex_unlock(mtx_); }
#else
  mutexor(void*) {}
  ~mutexor() {}
#endif
private:
  mutexor(const mutexor& rhs);
  mutexor& operator=(const mutexor& rhs);
#ifndef _LIBCXXABI_HAS_NO_THREADS
  std::__libcpp_mutex_t* mtx_;
#endif
};

static const size_t HEAP_SIZE = 512;
char heap[HEAP_SIZE] __attribute__((aligned));

typedef unsigned short heap_offset;
typedef unsigned short heap_size;

struct heap_node {
  heap_offset next_node; // offset into heap
  heap_size len;         // size in units of "sizeof(heap_node)"
};

static const heap_node* list_end =
    (heap_node*)(&heap[HEAP_SIZE]); // one past the end of the heap
static heap_node* freelist = NULL;

heap_node* node_from_offset(const heap_offset offset) {
  return (heap_node*)(heap + (offset * sizeof(heap_node)));
}

heap_offset offset_from_node(const heap_node* ptr) {
  return static_cast<heap_offset>(
      static_cast<size_t>(reinterpret_cast<const char*>(ptr) - heap) /
      sizeof(heap_node));
}

void init_heap() {
  freelist = (heap_node*)heap;
  freelist->next_node = offset_from_node(list_end);
  freelist->len = HEAP_SIZE / sizeof(heap_node);
}

//  How big a chunk we allocate
size_t alloc_size(size_t len) {
  return (len + sizeof(heap_node) - 1) / sizeof(heap_node) + 1;
}

bool is_fallback_ptr(void* ptr) {
  return ptr >= heap && ptr < (heap + HEAP_SIZE);
}

void* fallback_malloc(size_t len) {
  heap_node *p, *prev;
  const size_t nelems = alloc_size(len);
  mutexor mtx(&heap_mutex);

  if (NULL == freelist)
    init_heap();

  //  Walk the free list, looking for a "big enough" chunk
  for (p = freelist, prev = 0; p && p != list_end;
       prev = p, p = node_from_offset(p->next_node)) {

    if (p->len > nelems) { //  chunk is larger, shorten, and return the tail
      heap_node* q;

      p->len = static_cast<heap_size>(p->len - nelems);
      q = p + p->len;
      q->next_node = 0;
      q->len = static_cast<heap_size>(nelems);
      return (void*)(q + 1);
    }

    if (p->len == nelems) { // exact size match
      if (prev == 0)
        freelist = node_from_offset(p->next_node);
      else
        prev->next_node = p->next_node;
      p->next_node = 0;
      return (void*)(p + 1);
    }
  }
  return NULL; // couldn't find a spot big enough
}

//  Return the start of the next block
heap_node* after(struct heap_node* p) { return p + p->len; }

void fallback_free(void* ptr) {
  struct heap_node* cp = ((struct heap_node*)ptr) - 1; // retrieve the chunk
  struct heap_node *p, *prev;

  mutexor mtx(&heap_mutex);

#ifdef DEBUG_FALLBACK_MALLOC
  std::printf("Freeing item at %d of size %d\n", offset_from_node(cp), cp->len);
#endif

  for (p = freelist, prev = 0; p && p != list_end;
       prev = p, p = node_from_offset(p->next_node)) {
#ifdef DEBUG_FALLBACK_MALLOC
    std::printf("  p=%d, cp=%d, after(p)=%d, after(cp)=%d\n",
      offset_from_node(p), offset_from_node(cp),
      offset_from_node(after(p)), offset_from_node(after(cp)));
#endif
    if (after(p) == cp) {
#ifdef DEBUG_FALLBACK_MALLOC
      std::printf("  Appending onto chunk at %d\n", offset_from_node(p));
#endif
      p->len = static_cast<heap_size>(
          p->len + cp->len); // make the free heap_node larger
      return;
    } else if (after(cp) == p) { // there's a free heap_node right after
#ifdef DEBUG_FALLBACK_MALLOC
      std::printf("  Appending free chunk at %d\n", offset_from_node(p));
#endif
      cp->len = static_cast<heap_size>(cp->len + p->len);
      if (prev == 0) {
        freelist = cp;
        cp->next_node = p->next_node;
      } else
        prev->next_node = offset_from_node(cp);
      return;
    }
  }
//  Nothing to merge with, add it to the start of the free list
#ifdef DEBUG_FALLBACK_MALLOC
  std::printf("  Making new free list entry %d\n", offset_from_node(cp));
#endif
  cp->next_node = offset_from_node(freelist);
  freelist = cp;
}

#ifdef INSTRUMENT_FALLBACK_MALLOC
size_t print_free_list() {
  struct heap_node *p, *prev;
  heap_size total_free = 0;
  if (NULL == freelist)
    init_heap();

  for (p = freelist, prev = 0; p && p != list_end;
       prev = p, p = node_from_offset(p->next_node)) {
    std::printf("%sOffset: %d\tsize: %d Next: %d\n",
      (prev == 0 ? "" : "  "), offset_from_node(p), p->len, p->next_node);
    total_free += p->len;
  }
  std::printf("Total Free space: %d\n", total_free);
  return total_free;
}
#endif
} // end unnamed namespace

namespace __cxxabiv1 {

struct __attribute__((aligned)) __aligned_type {};

void* __aligned_malloc_with_fallback(size_t size) {
#if defined(_WIN32)
  if (void* dest = std::__libcpp_aligned_alloc(alignof(__aligned_type), size))
    return dest;
#elif defined(_LIBCPP_HAS_NO_LIBRARY_ALIGNED_ALLOCATION)
  if (void* dest = ::malloc(size))
    return dest;
#else
  if (size == 0)
    size = 1;
  if (void* dest = std::__libcpp_aligned_alloc(__alignof(__aligned_type), size))
    return dest;
#endif
  return fallback_malloc(size);
}

void* __calloc_with_fallback(size_t count, size_t size) {
  void* ptr = ::calloc(count, size);
  if (NULL != ptr)
    return ptr;
  // if calloc fails, fall back to emergency stash
  ptr = fallback_malloc(size * count);
  if (NULL != ptr)
    ::memset(ptr, 0, size * count);
  return ptr;
}

void __aligned_free_with_fallback(void* ptr) {
  if (is_fallback_ptr(ptr))
    fallback_free(ptr);
  else {
#if defined(_LIBCPP_HAS_NO_LIBRARY_ALIGNED_ALLOCATION)
    ::free(ptr);
#else
    std::__libcpp_aligned_free(ptr);
#endif
  }
}

void __free_with_fallback(void* ptr) {
  if (is_fallback_ptr(ptr))
    fallback_free(ptr);
  else
    ::free(ptr);
}

} // namespace __cxxabiv1
