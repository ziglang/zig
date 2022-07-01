//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_TRANSACTION_H
#define _LIBCPP___UTILITY_TRANSACTION_H

#include <__config>
#include <__utility/exchange.h>
#include <__utility/move.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// __transaction is a helper class for writing code with the strong exception guarantee.
//
// When writing code that can throw an exception, one can store rollback instructions in a
// transaction so that if an exception is thrown at any point during the lifetime of the
// transaction, it will be rolled back automatically. When the transaction is done, one
// must mark it as being complete so it isn't rolled back when the transaction is destroyed.
//
// Transactions are not default constructible, they can't be copied or assigned to, but
// they can be moved around for convenience.
//
// __transaction can help greatly simplify code that would normally be cluttered by
// `#if _LIBCPP_NO_EXCEPTIONS`. For example:
//
//    template <class Iterator, class Size, class OutputIterator>
//    Iterator uninitialized_copy_n(Iterator iter, Size n, OutputIterator out) {
//        typedef typename iterator_traits<Iterator>::value_type value_type;
//        __transaction transaction([start=out, &out] {
//            std::destroy(start, out);
//        });
//
//        for (; n > 0; ++iter, ++out, --n) {
//            ::new ((void*)std::addressof(*out)) value_type(*iter);
//        }
//        transaction.__complete();
//        return out;
//    }
//
template <class _Rollback>
struct __transaction {
    __transaction() = delete;

    _LIBCPP_HIDE_FROM_ABI
    _LIBCPP_CONSTEXPR_AFTER_CXX17 explicit __transaction(_Rollback __rollback)
        : __rollback_(_VSTD::move(__rollback))
        , __completed_(false)
    { }

    _LIBCPP_HIDE_FROM_ABI
    _LIBCPP_CONSTEXPR_AFTER_CXX17 __transaction(__transaction&& __other)
        _NOEXCEPT_(is_nothrow_move_constructible<_Rollback>::value)
        : __rollback_(_VSTD::move(__other.__rollback_))
        , __completed_(__other.__completed_)
    {
        __other.__completed_ = true;
    }

    __transaction(__transaction const&) = delete;
    __transaction& operator=(__transaction const&) = delete;
    __transaction& operator=(__transaction&&) = delete;

    _LIBCPP_HIDE_FROM_ABI
    _LIBCPP_CONSTEXPR_AFTER_CXX17 void __complete() _NOEXCEPT {
        __completed_ = true;
    }

    _LIBCPP_HIDE_FROM_ABI
    _LIBCPP_CONSTEXPR_AFTER_CXX17 ~__transaction() {
        if (!__completed_)
            __rollback_();
    }

private:
    _Rollback __rollback_;
    bool __completed_;
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___UTILITY_TRANSACTION_H
