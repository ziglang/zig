// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_PARALLEL_BACKEND_SERIAL_H
#define _PSTL_PARALLEL_BACKEND_SERIAL_H

#include <__config>
#include <__memory/allocator.h>
#include <__pstl/internal/execution_impl.h>
#include <__utility/forward.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

namespace __pstl
{
namespace __serial_backend
{

template <typename _Tp>
class __buffer
{
    std::allocator<_Tp> __allocator_;
    _Tp* __ptr_;
    const std::size_t __buf_size_;
    __buffer(const __buffer&) = delete;
    void
    operator=(const __buffer&) = delete;

  public:
    _LIBCPP_HIDE_FROM_ABI
    __buffer(std::size_t __n) : __allocator_(), __ptr_(__allocator_.allocate(__n)), __buf_size_(__n) {}

    _LIBCPP_HIDE_FROM_ABI operator bool() const { return __ptr_ != nullptr; }
    _LIBCPP_HIDE_FROM_ABI _Tp*
    get() const
    {
        return __ptr_;
    }
    _LIBCPP_HIDE_FROM_ABI ~__buffer() { __allocator_.deallocate(__ptr_, __buf_size_); }
};

template <class _ExecutionPolicy, class _Value, class _Index, typename _RealBody, typename _Reduction>
_LIBCPP_HIDE_FROM_ABI _Value
__parallel_reduce(__pstl::__internal::__serial_backend_tag, _ExecutionPolicy&&, _Index __first, _Index __last,
                  const _Value& __identity, const _RealBody& __real_body, const _Reduction&)
{
    if (__first == __last)
    {
        return __identity;
    }
    else
    {
        return __real_body(__first, __last, __identity);
    }
}

template <class _ExecutionPolicy, typename _Index, typename _Tp, typename _Rp, typename _Cp, typename _Sp, typename _Ap>
_LIBCPP_HIDE_FROM_ABI void
__parallel_strict_scan(__pstl::__internal::__serial_backend_tag, _ExecutionPolicy&&, _Index __n, _Tp __initial,
                       _Rp __reduce, _Cp __combine, _Sp __scan, _Ap __apex)
{
    _Tp __sum = __initial;
    if (__n)
        __sum = __combine(__sum, __reduce(_Index(0), __n));
    __apex(__sum);
    if (__n)
        __scan(_Index(0), __n, __initial);
}

template <class _ExecutionPolicy, class _Index, class _UnaryOp, class _Tp, class _BinaryOp, class _Reduce, class _Scan>
_LIBCPP_HIDE_FROM_ABI _Tp
__parallel_transform_scan(__pstl::__internal::__serial_backend_tag, _ExecutionPolicy&&, _Index __n, _UnaryOp,
                          _Tp __init, _BinaryOp, _Reduce, _Scan __scan)
{
    return __scan(_Index(0), __n, __init);
}

template <class _ExecutionPolicy, typename _RandomAccessIterator, typename _Compare, typename _LeafSort>
_LIBCPP_HIDE_FROM_ABI void
__parallel_stable_sort(__pstl::__internal::__serial_backend_tag, _ExecutionPolicy&&, _RandomAccessIterator __first,
                       _RandomAccessIterator __last, _Compare __comp, _LeafSort __leaf_sort, std::size_t = 0)
{
    __leaf_sort(__first, __last, __comp);
}

template <class _ExecutionPolicy, typename _F1, typename _F2>
_LIBCPP_HIDE_FROM_ABI void
__parallel_invoke(__pstl::__internal::__serial_backend_tag, _ExecutionPolicy&&, _F1&& __f1, _F2&& __f2)
{
    std::forward<_F1>(__f1)();
    std::forward<_F2>(__f2)();
}

} // namespace __serial_backend
} // namespace __pstl

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif /* _PSTL_PARALLEL_BACKEND_SERIAL_H */
