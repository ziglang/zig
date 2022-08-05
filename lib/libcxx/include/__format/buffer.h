// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_BUFFER_H
#define _LIBCPP___FORMAT_BUFFER_H

#include <__algorithm/copy_n.h>
#include <__algorithm/max.h>
#include <__algorithm/min.h>
#include <__algorithm/unwrap_iter.h>
#include <__config>
#include <__format/enable_insertable.h>
#include <__format/format_to_n_result.h>
#include <__format/formatter.h> // for __char_type TODO FMT Move the concept?
#include <__iterator/back_insert_iterator.h>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/wrap_iter.h>
#include <__utility/move.h>
#include <concepts>
#include <cstddef>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

namespace __format {

/// A "buffer" that handles writing to the proper iterator.
///
/// This helper is used together with the @ref back_insert_iterator to offer
/// type-erasure for the formatting functions. This reduces the number to
/// template instantiations.
template <__formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __output_buffer {
public:
  using value_type = _CharT;

  template <class _Tp>
  _LIBCPP_HIDE_FROM_ABI explicit __output_buffer(_CharT* __ptr,
                                                 size_t __capacity, _Tp* __obj)
      : __ptr_(__ptr), __capacity_(__capacity),
        __flush_([](_CharT* __p, size_t __size, void* __o) {
          static_cast<_Tp*>(__o)->flush(__p, __size);
        }),
        __obj_(__obj) {}

  _LIBCPP_HIDE_FROM_ABI void reset(_CharT* __ptr, size_t __capacity) {
    __ptr_ = __ptr;
    __capacity_ = __capacity;
  }

  _LIBCPP_HIDE_FROM_ABI auto make_output_iterator() {
    return back_insert_iterator{*this};
  }

  // TODO FMT It would be nice to have an overload taking a
  // basic_string_view<_CharT> and append it directly.
  _LIBCPP_HIDE_FROM_ABI void push_back(_CharT __c) {
    __ptr_[__size_++] = __c;

    // Profiling showed flushing after adding is more efficient than flushing
    // when entering the function.
    if (__size_ == __capacity_)
      flush();
  }

  _LIBCPP_HIDE_FROM_ABI void flush() {
    __flush_(__ptr_, __size_, __obj_);
    __size_ = 0;
  }

private:
  _CharT* __ptr_;
  size_t __capacity_;
  size_t __size_{0};
  void (*__flush_)(_CharT*, size_t, void*);
  void* __obj_;
};

/// A storage using an internal buffer.
///
/// This storage is used when writing a single element to the output iterator
/// is expensive.
template <__formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __internal_storage {
public:
  _LIBCPP_HIDE_FROM_ABI _CharT* begin() { return __buffer_; }

  static constexpr size_t __buffer_size = 256 / sizeof(_CharT);

private:
  _CharT __buffer_[__buffer_size];
};

/// A storage writing directly to the storage.
///
/// This requires the storage to be a contiguous buffer of \a _CharT.
/// Since the output is directly written to the underlying storage this class
/// is just an empty class.
template <__formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __direct_storage {};

template <class _OutIt, class _CharT>
concept __enable_direct_output = __formatter::__char_type<_CharT> &&
    (same_as<_OutIt, _CharT*>
#ifndef _LIBCPP_ENABLE_DEBUG_MODE
     || same_as<_OutIt, __wrap_iter<_CharT*>>
#endif
    );

/// Write policy for directly writing to the underlying output.
template <class _OutIt, __formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __writer_direct {
public:
  _LIBCPP_HIDE_FROM_ABI explicit __writer_direct(_OutIt __out_it)
      : __out_it_(__out_it) {}

  _LIBCPP_HIDE_FROM_ABI auto out() { return __out_it_; }

  _LIBCPP_HIDE_FROM_ABI void flush(_CharT*, size_t __size) {
    // _OutIt can be a __wrap_iter<CharT*>. Therefore the original iterator
    // is adjusted.
    __out_it_ += __size;
  }

private:
  _OutIt __out_it_;
};

/// Write policy for copying the buffer to the output.
template <class _OutIt, __formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __writer_iterator {
public:
  _LIBCPP_HIDE_FROM_ABI explicit __writer_iterator(_OutIt __out_it)
      : __out_it_{_VSTD::move(__out_it)} {}

  _LIBCPP_HIDE_FROM_ABI auto out() { return __out_it_; }

  _LIBCPP_HIDE_FROM_ABI void flush(_CharT* __ptr, size_t __size) {
    __out_it_ = _VSTD::copy_n(__ptr, __size, _VSTD::move(__out_it_));
  }

private:
  _OutIt __out_it_;
};

/// Concept to see whether a \a _Container is insertable.
///
/// The concept is used to validate whether multiple calls to a
/// \ref back_insert_iterator can be replace by a call to \c _Container::insert.
///
/// \note a \a _Container needs to opt-in to the concept by specializing
/// \ref __enable_insertable.
template <class _Container>
concept __insertable =
    __enable_insertable<_Container> && __formatter::__char_type<typename _Container::value_type> &&
    requires(_Container& __t, add_pointer_t<typename _Container::value_type> __first,
             add_pointer_t<typename _Container::value_type> __last) { __t.insert(__t.end(), __first, __last); };

/// Extract the container type of a \ref back_insert_iterator.
template <class _It>
struct _LIBCPP_TEMPLATE_VIS __back_insert_iterator_container {
  using type = void;
};

template <__insertable _Container>
struct _LIBCPP_TEMPLATE_VIS __back_insert_iterator_container<back_insert_iterator<_Container>> {
  using type = _Container;
};

/// Write policy for inserting the buffer in a container.
template <class _Container>
class _LIBCPP_TEMPLATE_VIS __writer_container {
public:
  using _CharT = typename _Container::value_type;

  _LIBCPP_HIDE_FROM_ABI explicit __writer_container(back_insert_iterator<_Container> __out_it)
      : __container_{__out_it.__get_container()} {}

  _LIBCPP_HIDE_FROM_ABI auto out() { return back_inserter(*__container_); }

  _LIBCPP_HIDE_FROM_ABI void flush(_CharT* __ptr, size_t __size) {
    __container_->insert(__container_->end(), __ptr, __ptr + __size);
  }

private:
  _Container* __container_;
};

/// Selects the type of the writer used for the output iterator.
template <class _OutIt, class _CharT>
class _LIBCPP_TEMPLATE_VIS __writer_selector {
  using _Container = typename __back_insert_iterator_container<_OutIt>::type;

public:
  using type = conditional_t<!same_as<_Container, void>, __writer_container<_Container>,
                             conditional_t<__enable_direct_output<_OutIt, _CharT>, __writer_direct<_OutIt, _CharT>,
                                           __writer_iterator<_OutIt, _CharT>>>;
};

/// The generic formatting buffer.
template <class _OutIt, __formatter::__char_type _CharT>
requires(output_iterator<_OutIt, const _CharT&>) class _LIBCPP_TEMPLATE_VIS
    __format_buffer {
  using _Storage =
      conditional_t<__enable_direct_output<_OutIt, _CharT>,
                    __direct_storage<_CharT>, __internal_storage<_CharT>>;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __format_buffer(_OutIt __out_it)
    requires(same_as<_Storage, __internal_storage<_CharT>>)
  : __output_(__storage_.begin(), __storage_.__buffer_size, this), __writer_(_VSTD::move(__out_it)) {}

  _LIBCPP_HIDE_FROM_ABI explicit __format_buffer(_OutIt __out_it) requires(
      same_as<_Storage, __direct_storage<_CharT>>)
      : __output_(_VSTD::__unwrap_iter(__out_it), size_t(-1), this),
        __writer_(_VSTD::move(__out_it)) {}

  _LIBCPP_HIDE_FROM_ABI auto make_output_iterator() {
    return __output_.make_output_iterator();
  }

  _LIBCPP_HIDE_FROM_ABI void flush(_CharT* __ptr, size_t __size) {
    __writer_.flush(__ptr, __size);
  }

  _LIBCPP_HIDE_FROM_ABI _OutIt out() && {
    __output_.flush();
    return _VSTD::move(__writer_).out();
  }

private:
  _LIBCPP_NO_UNIQUE_ADDRESS _Storage __storage_;
  __output_buffer<_CharT> __output_;
  typename __writer_selector<_OutIt, _CharT>::type __writer_;
};

/// A buffer that counts the number of insertions.
///
/// Since \ref formatted_size only needs to know the size, the output itself is
/// discarded.
template <__formatter::__char_type _CharT>
class _LIBCPP_TEMPLATE_VIS __formatted_size_buffer {
public:
  _LIBCPP_HIDE_FROM_ABI auto make_output_iterator() { return __output_.make_output_iterator(); }

  _LIBCPP_HIDE_FROM_ABI void flush(const _CharT*, size_t __size) { __size_ += __size; }

  _LIBCPP_HIDE_FROM_ABI size_t result() && {
    __output_.flush();
    return __size_;
  }

private:
  __internal_storage<_CharT> __storage_;
  __output_buffer<_CharT> __output_{__storage_.begin(), __storage_.__buffer_size, this};
  size_t __size_{0};
};

/// The base of a buffer that counts and limits the number of insertions.
template <class _OutIt, __formatter::__char_type _CharT, bool>
  requires(output_iterator<_OutIt, const _CharT&>)
struct _LIBCPP_TEMPLATE_VIS __format_to_n_buffer_base {
  using _Size = iter_difference_t<_OutIt>;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __format_to_n_buffer_base(_OutIt __out_it, _Size __n)
      : __writer_(_VSTD::move(__out_it)), __n_(_VSTD::max(_Size(0), __n)) {}

  _LIBCPP_HIDE_FROM_ABI void flush(_CharT* __ptr, size_t __size) {
    if (_Size(__size_) <= __n_)
      __writer_.flush(__ptr, _VSTD::min(_Size(__size), __n_ - __size_));
    __size_ += __size;
  }

protected:
  __internal_storage<_CharT> __storage_;
  __output_buffer<_CharT> __output_{__storage_.begin(), __storage_.__buffer_size, this};
  typename __writer_selector<_OutIt, _CharT>::type __writer_;

  _Size __n_;
  _Size __size_{0};
};

/// The base of a buffer that counts and limits the number of insertions.
///
/// This version is used when \c __enable_direct_output<_OutIt, _CharT> == true.
///
/// This class limits the size available the the direct writer so it will not
/// exceed the maximum number of code units.
template <class _OutIt, __formatter::__char_type _CharT>
  requires(output_iterator<_OutIt, const _CharT&>)
class _LIBCPP_TEMPLATE_VIS __format_to_n_buffer_base<_OutIt, _CharT, true> {
  using _Size = iter_difference_t<_OutIt>;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __format_to_n_buffer_base(_OutIt __out_it, _Size __n)
      : __output_(_VSTD::__unwrap_iter(__out_it), __n, this), __writer_(_VSTD::move(__out_it)) {
    if (__n <= 0) [[unlikely]]
      __output_.reset(__storage_.begin(), __storage_.__buffer_size);
  }

  _LIBCPP_HIDE_FROM_ABI void flush(_CharT* __ptr, size_t __size) {
    // A flush to the direct writer happens in two occasions:
    // - The format function has written the maximum number of allowed code
    //   units. At this point it's no longer valid to write to this writer. So
    //   switch to the internal storage. This internal storage doesn't need to
    //   be written anywhere so the flush for that storage writes no output.
    // - The format_to_n function is finished. In this case there's no need to
    //   switch the buffer, but for simplicity the buffers are still switched.
    // When the __n <= 0 the constructor already switched the buffers.
    if (__size_ == 0 && __ptr != __storage_.begin()) {
      __writer_.flush(__ptr, __size);
      __output_.reset(__storage_.begin(), __storage_.__buffer_size);
    }

    __size_ += __size;
  }

protected:
  __internal_storage<_CharT> __storage_;
  __output_buffer<_CharT> __output_;
  __writer_direct<_OutIt, _CharT> __writer_;

  _Size __size_{0};
};

/// The buffer that counts and limits the number of insertions.
template <class _OutIt, __formatter::__char_type _CharT>
  requires(output_iterator<_OutIt, const _CharT&>)
struct _LIBCPP_TEMPLATE_VIS __format_to_n_buffer final
    : public __format_to_n_buffer_base< _OutIt, _CharT, __enable_direct_output<_OutIt, _CharT>> {
  using _Base = __format_to_n_buffer_base<_OutIt, _CharT, __enable_direct_output<_OutIt, _CharT>>;
  using _Size = iter_difference_t<_OutIt>;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __format_to_n_buffer(_OutIt __out_it, _Size __n) : _Base(_VSTD::move(__out_it), __n) {}
  _LIBCPP_HIDE_FROM_ABI auto make_output_iterator() { return this->__output_.make_output_iterator(); }

  _LIBCPP_HIDE_FROM_ABI format_to_n_result<_OutIt> result() && {
    this->__output_.flush();
    return {_VSTD::move(this->__writer_).out(), this->__size_};
  }
};
} // namespace __format

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_BUFFER_H
