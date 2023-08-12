//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <__algorithm/min.h>
#include <__algorithm/pstl_backends/cpu_backends/libdispatch.h>
#include <__config>
#include <dispatch/dispatch.h>
#include <thread>

_LIBCPP_BEGIN_NAMESPACE_STD

namespace __par_backend::inline __libdispatch {


void __dispatch_apply(size_t chunk_count, void* context, void (*func)(void* context, size_t chunk)) noexcept {
  ::dispatch_apply_f(chunk_count, DISPATCH_APPLY_AUTO, context, func);
}

__chunk_partitions __partition_chunks(ptrdiff_t element_count) {
  if (element_count == 0) {
    return __chunk_partitions{1, 0, 0};
  } else if (element_count == 1) {
    return __chunk_partitions{1, 0, 1};
  }

  __chunk_partitions partitions;
  partitions.__chunk_count_ = [&] {
    ptrdiff_t cores = std::max(1u, thread::hardware_concurrency());

    auto medium = [&](ptrdiff_t n) { return cores + ((n - cores) / cores); };

    // This is an approximation of `log(1.01, sqrt(n))` which seemes to be reasonable for `n` larger than 500 and tops
    // at 800 tasks for n ~ 8 million
    auto large = [](ptrdiff_t n) { return static_cast<ptrdiff_t>(100.499 * std::log(std::sqrt(n))); };

    if (element_count < cores)
      return element_count;
    else if (element_count < 500)
      return medium(element_count);
    else
      return std::min(medium(element_count), large(element_count)); // provide a "smooth" transition
  }();
  partitions.__chunk_size_       = element_count / partitions.__chunk_count_;
  partitions.__first_chunk_size_ = partitions.__chunk_size_;

  const ptrdiff_t leftover_item_count = element_count - (partitions.__chunk_count_ * partitions.__chunk_size_);

  if (leftover_item_count == 0)
    return partitions;

  if (leftover_item_count == partitions.__chunk_size_) {
    partitions.__chunk_count_ += 1;
    return partitions;
  }

  const ptrdiff_t n_extra_items_per_chunk = leftover_item_count / partitions.__chunk_count_;
  const ptrdiff_t n_final_leftover_items  = leftover_item_count - (n_extra_items_per_chunk * partitions.__chunk_count_);

  partitions.__chunk_size_ += n_extra_items_per_chunk;
  partitions.__first_chunk_size_ = partitions.__chunk_size_ + n_final_leftover_items;
  return partitions;
}

// NOLINTNEXTLINE(llvm-namespace-comment) // This is https://llvm.org/PR56804
} // namespace __par_backend::inline __libdispatch

_LIBCPP_END_NAMESPACE_STD
