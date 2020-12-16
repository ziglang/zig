// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MEMORY_ALLOCATOR_TRAITS_H
#define _LIBCPP___MEMORY_ALLOCATOR_TRAITS_H

#include <__config>
#include <__memory/base.h>
#include <__memory/pointer_traits.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp, class = void>
struct __has_pointer_type : false_type {};

template <class _Tp>
struct __has_pointer_type<_Tp,
          typename __void_t<typename _Tp::pointer>::type> : true_type {};

namespace __pointer_type_imp
{

template <class _Tp, class _Dp, bool = __has_pointer_type<_Dp>::value>
struct __pointer_type
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Dp::pointer type;
};

template <class _Tp, class _Dp>
struct __pointer_type<_Tp, _Dp, false>
{
    typedef _LIBCPP_NODEBUG_TYPE _Tp* type;
};

}  // __pointer_type_imp

template <class _Tp, class _Dp>
struct __pointer_type
{
    typedef _LIBCPP_NODEBUG_TYPE typename __pointer_type_imp::__pointer_type<_Tp, typename remove_reference<_Dp>::type>::type type;
};

template <class _Tp, class = void>
struct __has_const_pointer : false_type {};

template <class _Tp>
struct __has_const_pointer<_Tp,
            typename __void_t<typename _Tp::const_pointer>::type> : true_type {};

template <class _Tp, class _Ptr, class _Alloc, bool = __has_const_pointer<_Alloc>::value>
struct __const_pointer
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::const_pointer type;
};

template <class _Tp, class _Ptr, class _Alloc>
struct __const_pointer<_Tp, _Ptr, _Alloc, false>
{
#ifndef _LIBCPP_CXX03_LANG
    typedef _LIBCPP_NODEBUG_TYPE typename pointer_traits<_Ptr>::template rebind<const _Tp> type;
#else
    typedef typename pointer_traits<_Ptr>::template rebind<const _Tp>::other type;
#endif
};

template <class _Tp, class = void>
struct __has_void_pointer : false_type {};

template <class _Tp>
struct __has_void_pointer<_Tp,
               typename __void_t<typename _Tp::void_pointer>::type> : true_type {};

template <class _Ptr, class _Alloc, bool = __has_void_pointer<_Alloc>::value>
struct __void_pointer
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::void_pointer type;
};

template <class _Ptr, class _Alloc>
struct __void_pointer<_Ptr, _Alloc, false>
{
#ifndef _LIBCPP_CXX03_LANG
    typedef _LIBCPP_NODEBUG_TYPE typename pointer_traits<_Ptr>::template rebind<void> type;
#else
    typedef _LIBCPP_NODEBUG_TYPE typename pointer_traits<_Ptr>::template rebind<void>::other type;
#endif
};

template <class _Tp, class = void>
struct __has_const_void_pointer : false_type {};

template <class _Tp>
struct __has_const_void_pointer<_Tp,
            typename __void_t<typename _Tp::const_void_pointer>::type> : true_type {};

template <class _Ptr, class _Alloc, bool = __has_const_void_pointer<_Alloc>::value>
struct __const_void_pointer
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::const_void_pointer type;
};

template <class _Ptr, class _Alloc>
struct __const_void_pointer<_Ptr, _Alloc, false>
{
#ifndef _LIBCPP_CXX03_LANG
    typedef _LIBCPP_NODEBUG_TYPE typename pointer_traits<_Ptr>::template rebind<const void> type;
#else
    typedef _LIBCPP_NODEBUG_TYPE typename pointer_traits<_Ptr>::template rebind<const void>::other type;
#endif
};

template <class _Tp, class = void>
struct __has_size_type : false_type {};

template <class _Tp>
struct __has_size_type<_Tp,
               typename __void_t<typename _Tp::size_type>::type> : true_type {};

template <class _Alloc, class _DiffType, bool = __has_size_type<_Alloc>::value>
struct __size_type
{
    typedef _LIBCPP_NODEBUG_TYPE typename make_unsigned<_DiffType>::type type;
};

template <class _Alloc, class _DiffType>
struct __size_type<_Alloc, _DiffType, true>
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::size_type type;
};

template <class _Tp, class = void>
struct __has_propagate_on_container_copy_assignment : false_type {};

template <class _Tp>
struct __has_propagate_on_container_copy_assignment<_Tp,
    typename __void_t<typename _Tp::propagate_on_container_copy_assignment>::type>
        : true_type {};

template <class _Alloc, bool = __has_propagate_on_container_copy_assignment<_Alloc>::value>
struct __propagate_on_container_copy_assignment
{
    typedef _LIBCPP_NODEBUG_TYPE false_type type;
};

template <class _Alloc>
struct __propagate_on_container_copy_assignment<_Alloc, true>
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::propagate_on_container_copy_assignment type;
};

template <class _Tp, class = void>
struct __has_propagate_on_container_move_assignment : false_type {};

template <class _Tp>
struct __has_propagate_on_container_move_assignment<_Tp,
           typename __void_t<typename _Tp::propagate_on_container_move_assignment>::type>
               : true_type {};

template <class _Alloc, bool = __has_propagate_on_container_move_assignment<_Alloc>::value>
struct __propagate_on_container_move_assignment
{
    typedef false_type type;
};

template <class _Alloc>
struct __propagate_on_container_move_assignment<_Alloc, true>
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::propagate_on_container_move_assignment type;
};

template <class _Tp, class = void>
struct __has_propagate_on_container_swap : false_type {};

template <class _Tp>
struct __has_propagate_on_container_swap<_Tp,
           typename __void_t<typename _Tp::propagate_on_container_swap>::type>
               : true_type {};

template <class _Alloc, bool = __has_propagate_on_container_swap<_Alloc>::value>
struct __propagate_on_container_swap
{
    typedef false_type type;
};

template <class _Alloc>
struct __propagate_on_container_swap<_Alloc, true>
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::propagate_on_container_swap type;
};

template <class _Tp, class = void>
struct __has_is_always_equal : false_type {};

template <class _Tp>
struct __has_is_always_equal<_Tp,
           typename __void_t<typename _Tp::is_always_equal>::type>
               : true_type {};

template <class _Alloc, bool = __has_is_always_equal<_Alloc>::value>
struct __is_always_equal
{
    typedef _LIBCPP_NODEBUG_TYPE typename _VSTD::is_empty<_Alloc>::type type;
};

template <class _Alloc>
struct __is_always_equal<_Alloc, true>
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::is_always_equal type;
};

template <class _Tp, class _Up, bool = __has_rebind<_Tp, _Up>::value>
struct __has_rebind_other
{
private:
    struct __two {char __lx; char __lxx;};
    template <class _Xp> static __two __test(...);
    _LIBCPP_SUPPRESS_DEPRECATED_PUSH
    template <class _Xp> static char __test(typename _Xp::template rebind<_Up>::other* = 0);
    _LIBCPP_SUPPRESS_DEPRECATED_POP
public:
    static const bool value = sizeof(__test<_Tp>(0)) == 1;
};

template <class _Tp, class _Up>
struct __has_rebind_other<_Tp, _Up, false>
{
    static const bool value = false;
};

template <class _Tp, class _Up, bool = __has_rebind_other<_Tp, _Up>::value>
struct __allocator_traits_rebind
{
    _LIBCPP_SUPPRESS_DEPRECATED_PUSH
    typedef _LIBCPP_NODEBUG_TYPE typename _Tp::template rebind<_Up>::other type;
    _LIBCPP_SUPPRESS_DEPRECATED_POP
};

template <template <class, class...> class _Alloc, class _Tp, class ..._Args, class _Up>
struct __allocator_traits_rebind<_Alloc<_Tp, _Args...>, _Up, true>
{
    _LIBCPP_SUPPRESS_DEPRECATED_PUSH
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc<_Tp, _Args...>::template rebind<_Up>::other type;
    _LIBCPP_SUPPRESS_DEPRECATED_POP
};

template <template <class, class...> class _Alloc, class _Tp, class ..._Args, class _Up>
struct __allocator_traits_rebind<_Alloc<_Tp, _Args...>, _Up, false>
{
    typedef _LIBCPP_NODEBUG_TYPE _Alloc<_Up, _Args...> type;
};

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Alloc, class _SizeType, class _ConstVoidPtr>
auto
__has_allocate_hint_test(_Alloc&& __a, _SizeType&& __sz, _ConstVoidPtr&& __p)
    -> decltype((void)__a.allocate(__sz, __p), true_type());
_LIBCPP_SUPPRESS_DEPRECATED_POP

template <class _Alloc, class _SizeType, class _ConstVoidPtr>
auto
__has_allocate_hint_test(const _Alloc& __a, _SizeType&& __sz, _ConstVoidPtr&& __p)
    -> false_type;

template <class _Alloc, class _SizeType, class _ConstVoidPtr>
struct __has_allocate_hint
    : decltype(_VSTD::__has_allocate_hint_test(declval<_Alloc>(),
                                               declval<_SizeType>(),
                                               declval<_ConstVoidPtr>()))
{
};

#else  // _LIBCPP_CXX03_LANG

template <class _Alloc, class _SizeType, class _ConstVoidPtr>
struct __has_allocate_hint
    : true_type
{
};

#endif  // _LIBCPP_CXX03_LANG

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Alloc, class ..._Args,
    class = decltype(_VSTD::declval<_Alloc>().construct(_VSTD::declval<_Args>()...))>
static true_type __test_has_construct(int);
_LIBCPP_SUPPRESS_DEPRECATED_POP

template <class _Alloc, class...>
static false_type __test_has_construct(...);

template <class _Alloc, class ..._Args>
struct __has_construct : decltype(__test_has_construct<_Alloc, _Args...>(0)) {};

#if !defined(_LIBCPP_CXX03_LANG)

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Alloc, class _Pointer>
auto
__has_destroy_test(_Alloc&& __a, _Pointer&& __p)
    -> decltype(__a.destroy(__p), true_type());
_LIBCPP_SUPPRESS_DEPRECATED_POP

template <class _Alloc, class _Pointer>
auto
__has_destroy_test(const _Alloc& __a, _Pointer&& __p)
    -> false_type;

template <class _Alloc, class _Pointer>
struct __has_destroy
    : decltype(_VSTD::__has_destroy_test(declval<_Alloc>(),
                                         declval<_Pointer>()))
{
};

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Alloc>
auto
__has_max_size_test(_Alloc&& __a)
    -> decltype(__a.max_size(), true_type());
_LIBCPP_SUPPRESS_DEPRECATED_POP

template <class _Alloc>
auto
__has_max_size_test(const volatile _Alloc& __a)
    -> false_type;

template <class _Alloc>
struct __has_max_size
    : decltype(_VSTD::__has_max_size_test(declval<_Alloc&>()))
{
};

template <class _Alloc>
auto
__has_select_on_container_copy_construction_test(_Alloc&& __a)
    -> decltype(__a.select_on_container_copy_construction(), true_type());

template <class _Alloc>
auto
__has_select_on_container_copy_construction_test(const volatile _Alloc& __a)
    -> false_type;

template <class _Alloc>
struct __has_select_on_container_copy_construction
    : decltype(_VSTD::__has_select_on_container_copy_construction_test(declval<_Alloc&>()))
{
};

#else  // _LIBCPP_CXX03_LANG

template <class _Alloc, class _Pointer, class = void>
struct __has_destroy : false_type {};

template <class _Alloc, class _Pointer>
struct __has_destroy<_Alloc, _Pointer, typename __void_t<
    decltype(_VSTD::declval<_Alloc>().destroy(_VSTD::declval<_Pointer>()))
>::type> : true_type {};

template <class _Alloc>
struct __has_max_size
    : true_type
{
};

template <class _Alloc>
struct __has_select_on_container_copy_construction
    : false_type
{
};

#endif  // _LIBCPP_CXX03_LANG

template <class _Alloc, class _Ptr, bool = __has_difference_type<_Alloc>::value>
struct __alloc_traits_difference_type
{
    typedef _LIBCPP_NODEBUG_TYPE typename pointer_traits<_Ptr>::difference_type type;
};

template <class _Alloc, class _Ptr>
struct __alloc_traits_difference_type<_Alloc, _Ptr, true>
{
    typedef _LIBCPP_NODEBUG_TYPE typename _Alloc::difference_type type;
};

template <class _Tp>
struct __is_default_allocator : false_type {};

template <class _Tp>
struct __is_default_allocator<_VSTD::allocator<_Tp> > : true_type {};



template <class _Alloc,
    bool = __has_construct<_Alloc, typename _Alloc::value_type*,  typename _Alloc::value_type&&>::value && !__is_default_allocator<_Alloc>::value
    >
struct __is_cpp17_move_insertable;
template <class _Alloc>
struct __is_cpp17_move_insertable<_Alloc, true> : true_type {};
template <class _Alloc>
struct __is_cpp17_move_insertable<_Alloc, false> : is_move_constructible<typename _Alloc::value_type> {};

template <class _Alloc,
    bool = __has_construct<_Alloc, typename _Alloc::value_type*, const typename _Alloc::value_type&>::value && !__is_default_allocator<_Alloc>::value
    >
struct __is_cpp17_copy_insertable;
template <class _Alloc>
struct __is_cpp17_copy_insertable<_Alloc, true> : __is_cpp17_move_insertable<_Alloc> {};
template <class _Alloc>
struct __is_cpp17_copy_insertable<_Alloc, false> : integral_constant<bool,
    is_copy_constructible<typename _Alloc::value_type>::value &&
    __is_cpp17_move_insertable<_Alloc>::value>
  {};



template <class _Alloc>
struct _LIBCPP_TEMPLATE_VIS allocator_traits
{
    typedef _Alloc                              allocator_type;
    typedef typename allocator_type::value_type value_type;

    typedef typename __pointer_type<value_type, allocator_type>::type pointer;
    typedef typename __const_pointer<value_type, pointer, allocator_type>::type const_pointer;
    typedef typename __void_pointer<pointer, allocator_type>::type void_pointer;
    typedef typename __const_void_pointer<pointer, allocator_type>::type const_void_pointer;

    typedef typename __alloc_traits_difference_type<allocator_type, pointer>::type difference_type;
    typedef typename __size_type<allocator_type, difference_type>::type size_type;

    typedef typename __propagate_on_container_copy_assignment<allocator_type>::type
                     propagate_on_container_copy_assignment;
    typedef typename __propagate_on_container_move_assignment<allocator_type>::type
                     propagate_on_container_move_assignment;
    typedef typename __propagate_on_container_swap<allocator_type>::type
                     propagate_on_container_swap;
    typedef typename __is_always_equal<allocator_type>::type
                     is_always_equal;

#ifndef _LIBCPP_CXX03_LANG
    template <class _Tp> using rebind_alloc =
                  typename __allocator_traits_rebind<allocator_type, _Tp>::type;
    template <class _Tp> using rebind_traits = allocator_traits<rebind_alloc<_Tp> >;
#else  // _LIBCPP_CXX03_LANG
    template <class _Tp> struct rebind_alloc
        {typedef typename __allocator_traits_rebind<allocator_type, _Tp>::type other;};
    template <class _Tp> struct rebind_traits
        {typedef allocator_traits<typename rebind_alloc<_Tp>::other> other;};
#endif  // _LIBCPP_CXX03_LANG

    _LIBCPP_NODISCARD_AFTER_CXX17 _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static pointer allocate(allocator_type& __a, size_type __n)
        {return __a.allocate(__n);}
    _LIBCPP_NODISCARD_AFTER_CXX17 _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static pointer allocate(allocator_type& __a, size_type __n, const_void_pointer __hint)
        {return __allocate(__a, __n, __hint,
            __has_allocate_hint<allocator_type, size_type, const_void_pointer>());}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static void deallocate(allocator_type& __a, pointer __p, size_type __n) _NOEXCEPT
        {__a.deallocate(__p, __n);}

    template <class _Tp, class... _Args>
        _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
        static void construct(allocator_type& __a, _Tp* __p, _Args&&... __args)
            {__construct(__has_construct<allocator_type, _Tp*, _Args...>(),
                         __a, __p, _VSTD::forward<_Args>(__args)...);}

    template <class _Tp>
        _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
        static void destroy(allocator_type& __a, _Tp* __p)
            {__destroy(__has_destroy<allocator_type, _Tp*>(), __a, __p);}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static size_type max_size(const allocator_type& __a) _NOEXCEPT
        {return __max_size(__has_max_size<const allocator_type>(), __a);}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static allocator_type
        select_on_container_copy_construction(const allocator_type& __a)
            {return __select_on_container_copy_construction(
                __has_select_on_container_copy_construction<const allocator_type>(),
                __a);}

private:
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static pointer __allocate(allocator_type& __a, size_type __n,
        const_void_pointer __hint, true_type)
        {
            _LIBCPP_SUPPRESS_DEPRECATED_PUSH
            return __a.allocate(__n, __hint);
            _LIBCPP_SUPPRESS_DEPRECATED_POP
        }
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static pointer __allocate(allocator_type& __a, size_type __n,
        const_void_pointer, false_type)
        {return __a.allocate(__n);}

    template <class _Tp, class... _Args>
        _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
        static void __construct(true_type, allocator_type& __a, _Tp* __p, _Args&&... __args)
            {
                _LIBCPP_SUPPRESS_DEPRECATED_PUSH
                __a.construct(__p, _VSTD::forward<_Args>(__args)...);
                _LIBCPP_SUPPRESS_DEPRECATED_POP
            }

    template <class _Tp, class... _Args>
        _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
        static void __construct(false_type, allocator_type&, _Tp* __p, _Args&&... __args)
            {
#if _LIBCPP_STD_VER > 17
                _VSTD::construct_at(__p, _VSTD::forward<_Args>(__args)...);
#else
                ::new ((void*)__p) _Tp(_VSTD::forward<_Args>(__args)...);
#endif
            }

    template <class _Tp>
        _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
        static void __destroy(true_type, allocator_type& __a, _Tp* __p)
            {
                _LIBCPP_SUPPRESS_DEPRECATED_PUSH
                __a.destroy(__p);
                _LIBCPP_SUPPRESS_DEPRECATED_POP
            }
    template <class _Tp>
        _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
        static void __destroy(false_type, allocator_type&, _Tp* __p)
            {
#if _LIBCPP_STD_VER > 17
                _VSTD::destroy_at(__p);
#else
                __p->~_Tp();
#endif
            }

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static size_type __max_size(true_type, const allocator_type& __a) _NOEXCEPT
            {
                _LIBCPP_SUPPRESS_DEPRECATED_PUSH
                return __a.max_size();
                _LIBCPP_SUPPRESS_DEPRECATED_POP
            }

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static size_type __max_size(false_type, const allocator_type&) _NOEXCEPT
            {return numeric_limits<size_type>::max() / sizeof(value_type);}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static allocator_type
        __select_on_container_copy_construction(true_type, const allocator_type& __a)
            {return __a.select_on_container_copy_construction();}
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    static allocator_type
        __select_on_container_copy_construction(false_type, const allocator_type& __a)
            {return __a;}
};

template <class _Traits, class _Tp>
struct __rebind_alloc_helper
{
#ifndef _LIBCPP_CXX03_LANG
    typedef _LIBCPP_NODEBUG_TYPE typename _Traits::template rebind_alloc<_Tp>        type;
#else
    typedef typename _Traits::template rebind_alloc<_Tp>::other type;
#endif
};

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif  // _LIBCPP___MEMORY_ALLOCATOR_TRAITS_H
