// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_ITERATOR_TRAITS_H
#define _LIBCPP___ITERATOR_ITERATOR_TRAITS_H

#include <__config>
#include <__iterator/incrementable_traits.h>
#include <__iterator/readable_traits.h>
#include <concepts>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_RANGES)

template <class _Tp>
using __with_reference = _Tp&;

template <class _Tp>
concept __referenceable = requires {
  typename __with_reference<_Tp>;
};

template <class _Tp>
concept __dereferenceable = requires(_Tp& __t) {
  { *__t } -> __referenceable; // not required to be equality-preserving
};

// [iterator.traits]
template<__dereferenceable _Tp>
using iter_reference_t = decltype(*declval<_Tp&>());

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

template <class _Iter>
struct _LIBCPP_TEMPLATE_VIS iterator_traits;

struct _LIBCPP_TEMPLATE_VIS input_iterator_tag {};
struct _LIBCPP_TEMPLATE_VIS output_iterator_tag {};
struct _LIBCPP_TEMPLATE_VIS forward_iterator_tag       : public input_iterator_tag {};
struct _LIBCPP_TEMPLATE_VIS bidirectional_iterator_tag : public forward_iterator_tag {};
struct _LIBCPP_TEMPLATE_VIS random_access_iterator_tag : public bidirectional_iterator_tag {};
#if _LIBCPP_STD_VER > 17
struct _LIBCPP_TEMPLATE_VIS contiguous_iterator_tag    : public random_access_iterator_tag {};
#endif

template <class _Iter>
struct __iter_traits_cache {
  using type = _If<
    __is_primary_template<iterator_traits<_Iter> >::value,
    _Iter,
    iterator_traits<_Iter>
  >;
};
template <class _Iter>
using _ITER_TRAITS = typename __iter_traits_cache<_Iter>::type;

struct __iter_concept_concept_test {
  template <class _Iter>
  using _Apply = typename _ITER_TRAITS<_Iter>::iterator_concept;
};
struct __iter_concept_category_test {
  template <class _Iter>
  using _Apply = typename _ITER_TRAITS<_Iter>::iterator_category;
};
struct __iter_concept_random_fallback {
  template <class _Iter>
  using _Apply = _EnableIf<
                          __is_primary_template<iterator_traits<_Iter> >::value,
                          random_access_iterator_tag
                        >;
};

template <class _Iter, class _Tester> struct __test_iter_concept
    : _IsValidExpansion<_Tester::template _Apply, _Iter>,
      _Tester
{
};

template <class _Iter>
struct __iter_concept_cache {
  using type = _Or<
    __test_iter_concept<_Iter, __iter_concept_concept_test>,
    __test_iter_concept<_Iter, __iter_concept_category_test>,
    __test_iter_concept<_Iter, __iter_concept_random_fallback>
  >;
};

template <class _Iter>
using _ITER_CONCEPT = typename __iter_concept_cache<_Iter>::type::template _Apply<_Iter>;


template <class _Tp>
struct __has_iterator_typedefs
{
private:
    struct __two {char __lx; char __lxx;};
    template <class _Up> static __two __test(...);
    template <class _Up> static char __test(typename __void_t<typename _Up::iterator_category>::type* = 0,
                                            typename __void_t<typename _Up::difference_type>::type* = 0,
                                            typename __void_t<typename _Up::value_type>::type* = 0,
                                            typename __void_t<typename _Up::reference>::type* = 0,
                                            typename __void_t<typename _Up::pointer>::type* = 0);
public:
    static const bool value = sizeof(__test<_Tp>(0,0,0,0,0)) == 1;
};


template <class _Tp>
struct __has_iterator_category
{
private:
    struct __two {char __lx; char __lxx;};
    template <class _Up> static __two __test(...);
    template <class _Up> static char __test(typename _Up::iterator_category* = nullptr);
public:
    static const bool value = sizeof(__test<_Tp>(nullptr)) == 1;
};

template <class _Tp>
struct __has_iterator_concept
{
private:
    struct __two {char __lx; char __lxx;};
    template <class _Up> static __two __test(...);
    template <class _Up> static char __test(typename _Up::iterator_concept* = nullptr);
public:
    static const bool value = sizeof(__test<_Tp>(nullptr)) == 1;
};

#if !defined(_LIBCPP_HAS_NO_RANGES)

// The `cpp17-*-iterator` exposition-only concepts are easily confused with the Cpp17*Iterator tables,
// so they've been banished to a namespace that makes it obvious they have a niche use-case.
namespace __iterator_traits_detail {
template<class _Ip>
concept __cpp17_iterator =
  requires(_Ip __i) {
    {   *__i } -> __referenceable;
    {  ++__i } -> same_as<_Ip&>;
    { *__i++ } -> __referenceable;
  } &&
  copyable<_Ip>;

template<class _Ip>
concept __cpp17_input_iterator =
  __cpp17_iterator<_Ip> &&
  equality_comparable<_Ip> &&
  requires(_Ip __i) {
    typename incrementable_traits<_Ip>::difference_type;
    typename indirectly_readable_traits<_Ip>::value_type;
    typename common_reference_t<iter_reference_t<_Ip>&&,
                                typename indirectly_readable_traits<_Ip>::value_type&>;
    typename common_reference_t<decltype(*__i++)&&,
                                typename indirectly_readable_traits<_Ip>::value_type&>;
    requires signed_integral<typename incrementable_traits<_Ip>::difference_type>;
  };

template<class _Ip>
concept __cpp17_forward_iterator =
  __cpp17_input_iterator<_Ip> &&
  constructible_from<_Ip> &&
  is_lvalue_reference_v<iter_reference_t<_Ip>> &&
  same_as<remove_cvref_t<iter_reference_t<_Ip>>,
          typename indirectly_readable_traits<_Ip>::value_type> &&
  requires(_Ip __i) {
    {  __i++ } -> convertible_to<_Ip const&>;
    { *__i++ } -> same_as<iter_reference_t<_Ip>>;
  };

template<class _Ip>
concept __cpp17_bidirectional_iterator =
  __cpp17_forward_iterator<_Ip> &&
  requires(_Ip __i) {
    {  --__i } -> same_as<_Ip&>;
    {  __i-- } -> convertible_to<_Ip const&>;
    { *__i-- } -> same_as<iter_reference_t<_Ip>>;
  };

template<class _Ip>
concept __cpp17_random_access_iterator =
  __cpp17_bidirectional_iterator<_Ip> &&
  totally_ordered<_Ip> &&
  requires(_Ip __i, typename incrementable_traits<_Ip>::difference_type __n) {
    { __i += __n } -> same_as<_Ip&>;
    { __i -= __n } -> same_as<_Ip&>;
    { __i +  __n } -> same_as<_Ip>;
    { __n +  __i } -> same_as<_Ip>;
    { __i -  __n } -> same_as<_Ip>;
    { __i -  __i } -> same_as<decltype(__n)>;
    {  __i[__n]  } -> convertible_to<iter_reference_t<_Ip>>;
  };
} // namespace __iterator_traits_detail

template<class _Ip>
concept __has_member_reference = requires { typename _Ip::reference; };

template<class _Ip>
concept __has_member_pointer = requires { typename _Ip::pointer; };

template<class _Ip>
concept __has_member_iterator_category = requires { typename _Ip::iterator_category; };

template<class _Ip>
concept __specifies_members = requires {
    typename _Ip::value_type;
    typename _Ip::difference_type;
    requires __has_member_reference<_Ip>;
    requires __has_member_iterator_category<_Ip>;
  };

template<class>
struct __iterator_traits_member_pointer_or_void {
  using type = void;
};

template<__has_member_pointer _Tp>
struct __iterator_traits_member_pointer_or_void<_Tp> {
  using type = typename _Tp::pointer;
};

template<class _Tp>
concept __cpp17_iterator_missing_members =
  !__specifies_members<_Tp> &&
  __iterator_traits_detail::__cpp17_iterator<_Tp>;

template<class _Tp>
concept __cpp17_input_iterator_missing_members =
  __cpp17_iterator_missing_members<_Tp> &&
  __iterator_traits_detail::__cpp17_input_iterator<_Tp>;

// Otherwise, `pointer` names `void`.
template<class>
struct __iterator_traits_member_pointer_or_arrow_or_void { using type = void; };

// [iterator.traits]/3.2.1
// If the qualified-id `I::pointer` is valid and denotes a type, `pointer` names that type.
template<__has_member_pointer _Ip>
struct __iterator_traits_member_pointer_or_arrow_or_void<_Ip> { using type = typename _Ip::pointer; };

// Otherwise, if `decltype(declval<I&>().operator->())` is well-formed, then `pointer` names that
// type.
template<class _Ip>
  requires requires(_Ip& __i) { __i.operator->(); } && (!__has_member_pointer<_Ip>)
struct __iterator_traits_member_pointer_or_arrow_or_void<_Ip> {
  using type = decltype(declval<_Ip&>().operator->());
};

// Otherwise, `reference` names `iter-reference-t<I>`.
template<class _Ip>
struct __iterator_traits_member_reference { using type = iter_reference_t<_Ip>; };

// [iterator.traits]/3.2.2
// If the qualified-id `I::reference` is valid and denotes a type, `reference` names that type.
template<__has_member_reference _Ip>
struct __iterator_traits_member_reference<_Ip> { using type = typename _Ip::reference; };

// [iterator.traits]/3.2.3.4
// input_iterator_tag
template<class _Ip>
struct __deduce_iterator_category {
  using type = input_iterator_tag;
};

// [iterator.traits]/3.2.3.1
// `random_access_iterator_tag` if `I` satisfies `cpp17-random-access-iterator`, or otherwise
template<__iterator_traits_detail::__cpp17_random_access_iterator _Ip>
struct __deduce_iterator_category<_Ip> {
  using type = random_access_iterator_tag;
};

// [iterator.traits]/3.2.3.2
// `bidirectional_iterator_tag` if `I` satisfies `cpp17-bidirectional-iterator`, or otherwise
template<__iterator_traits_detail::__cpp17_bidirectional_iterator _Ip>
struct __deduce_iterator_category<_Ip> {
  using type = bidirectional_iterator_tag;
};

// [iterator.traits]/3.2.3.3
// `forward_iterator_tag` if `I` satisfies `cpp17-forward-iterator`, or otherwise
template<__iterator_traits_detail::__cpp17_forward_iterator _Ip>
struct __deduce_iterator_category<_Ip> {
  using type = forward_iterator_tag;
};

template<class _Ip>
struct __iterator_traits_iterator_category : __deduce_iterator_category<_Ip> {};

// [iterator.traits]/3.2.3
// If the qualified-id `I::iterator-category` is valid and denotes a type, `iterator-category` names
// that type.
template<__has_member_iterator_category _Ip>
struct __iterator_traits_iterator_category<_Ip> {
  using type = typename _Ip::iterator_category;
};

// otherwise, it names void.
template<class>
struct __iterator_traits_difference_type { using type = void; };

// If the qualified-id `incrementable_traits<I>::difference_type` is valid and denotes a type, then
// `difference_type` names that type;
template<class _Ip>
requires requires { typename incrementable_traits<_Ip>::difference_type; }
struct __iterator_traits_difference_type<_Ip> {
  using type = typename incrementable_traits<_Ip>::difference_type;
};

// [iterator.traits]/3.4
// Otherwise, `iterator_traits<I>` has no members by any of the above names.
template<class>
struct __iterator_traits {};

// [iterator.traits]/3.1
// If `I` has valid ([temp.deduct]) member types `difference-type`, `value-type`, `reference`, and
// `iterator-category`, then `iterator-traits<I>` has the following publicly accessible members:
template<__specifies_members _Ip>
struct __iterator_traits<_Ip> {
  using iterator_category  = typename _Ip::iterator_category;
  using value_type         = typename _Ip::value_type;
  using difference_type    = typename _Ip::difference_type;
  using pointer            = typename __iterator_traits_member_pointer_or_void<_Ip>::type;
  using reference          = typename _Ip::reference;
};

// [iterator.traits]/3.2
// Otherwise, if `I` satisfies the exposition-only concept `cpp17-input-iterator`,
// `iterator-traits<I>` has the following publicly accessible members:
template<__cpp17_input_iterator_missing_members _Ip>
struct __iterator_traits<_Ip> {
  using iterator_category = typename __iterator_traits_iterator_category<_Ip>::type;
  using value_type        = typename indirectly_readable_traits<_Ip>::value_type;
  using difference_type   = typename incrementable_traits<_Ip>::difference_type;
  using pointer           = typename __iterator_traits_member_pointer_or_arrow_or_void<_Ip>::type;
  using reference         = typename __iterator_traits_member_reference<_Ip>::type;
};

// Otherwise, if `I` satisfies the exposition-only concept `cpp17-iterator`, then
// `iterator_traits<I>` has the following publicly accessible members:
template<__cpp17_iterator_missing_members _Ip>
struct __iterator_traits<_Ip> {
  using iterator_category = output_iterator_tag;
  using value_type        = void;
  using difference_type   = typename __iterator_traits_difference_type<_Ip>::type;
  using pointer           = void;
  using reference         = void;
};

template<class _Ip>
struct iterator_traits : __iterator_traits<_Ip> {
  using __primary_template = iterator_traits;
};

#else // !defined(_LIBCPP_HAS_NO_RANGES)

template <class _Iter, bool> struct __iterator_traits {};

template <class _Iter, bool> struct __iterator_traits_impl {};

template <class _Iter>
struct __iterator_traits_impl<_Iter, true>
{
    typedef typename _Iter::difference_type   difference_type;
    typedef typename _Iter::value_type        value_type;
    typedef typename _Iter::pointer           pointer;
    typedef typename _Iter::reference         reference;
    typedef typename _Iter::iterator_category iterator_category;
};

template <class _Iter>
struct __iterator_traits<_Iter, true>
    :  __iterator_traits_impl
      <
        _Iter,
        is_convertible<typename _Iter::iterator_category, input_iterator_tag>::value ||
        is_convertible<typename _Iter::iterator_category, output_iterator_tag>::value
      >
{};

// iterator_traits<Iterator> will only have the nested types if Iterator::iterator_category
//    exists.  Else iterator_traits<Iterator> will be an empty class.  This is a
//    conforming extension which allows some programs to compile and behave as
//    the client expects instead of failing at compile time.

template <class _Iter>
struct _LIBCPP_TEMPLATE_VIS iterator_traits
    : __iterator_traits<_Iter, __has_iterator_typedefs<_Iter>::value> {

  using __primary_template = iterator_traits;
};
#endif // !defined(_LIBCPP_HAS_NO_RANGES)

template<class _Tp>
#if !defined(_LIBCPP_HAS_NO_RANGES)
requires is_object_v<_Tp>
#endif
struct _LIBCPP_TEMPLATE_VIS iterator_traits<_Tp*>
{
    typedef ptrdiff_t difference_type;
    typedef typename remove_cv<_Tp>::type value_type;
    typedef _Tp* pointer;
    typedef _Tp& reference;
    typedef random_access_iterator_tag iterator_category;
#if _LIBCPP_STD_VER > 17
    typedef contiguous_iterator_tag    iterator_concept;
#endif
};

template <class _Tp, class _Up, bool = __has_iterator_category<iterator_traits<_Tp> >::value>
struct __has_iterator_category_convertible_to
    : is_convertible<typename iterator_traits<_Tp>::iterator_category, _Up>
{};

template <class _Tp, class _Up>
struct __has_iterator_category_convertible_to<_Tp, _Up, false> : false_type {};

template <class _Tp, class _Up, bool = __has_iterator_concept<_Tp>::value>
struct __has_iterator_concept_convertible_to
    : is_convertible<typename _Tp::iterator_concept, _Up>
{};

template <class _Tp, class _Up>
struct __has_iterator_concept_convertible_to<_Tp, _Up, false> : false_type {};

template <class _Tp>
struct __is_cpp17_input_iterator : public __has_iterator_category_convertible_to<_Tp, input_iterator_tag> {};

template <class _Tp>
struct __is_cpp17_forward_iterator : public __has_iterator_category_convertible_to<_Tp, forward_iterator_tag> {};

template <class _Tp>
struct __is_cpp17_bidirectional_iterator : public __has_iterator_category_convertible_to<_Tp, bidirectional_iterator_tag> {};

template <class _Tp>
struct __is_cpp17_random_access_iterator : public __has_iterator_category_convertible_to<_Tp, random_access_iterator_tag> {};

// __is_cpp17_contiguous_iterator determines if an iterator is known by
// libc++ to be contiguous, either because it advertises itself as such
// (in C++20) or because it is a pointer type or a known trivial wrapper
// around a (possibly fancy) pointer type, such as __wrap_iter<T*>.
// Such iterators receive special "contiguous" optimizations in
// std::copy and std::sort.
//
#if _LIBCPP_STD_VER > 17
template <class _Tp>
struct __is_cpp17_contiguous_iterator : _Or<
    __has_iterator_category_convertible_to<_Tp, contiguous_iterator_tag>,
    __has_iterator_concept_convertible_to<_Tp, contiguous_iterator_tag>
> {};
#else
template <class _Tp>
struct __is_cpp17_contiguous_iterator : false_type {};
#endif

// Any native pointer which is an iterator is also a contiguous iterator.
template <class _Up>
struct __is_cpp17_contiguous_iterator<_Up*> : true_type {};


template <class _Tp>
struct __is_exactly_cpp17_input_iterator
    : public integral_constant<bool,
         __has_iterator_category_convertible_to<_Tp, input_iterator_tag>::value &&
        !__has_iterator_category_convertible_to<_Tp, forward_iterator_tag>::value> {};

#ifndef _LIBCPP_HAS_NO_DEDUCTION_GUIDES
template<class _InputIterator>
using __iter_value_type = typename iterator_traits<_InputIterator>::value_type;

template<class _InputIterator>
using __iter_key_type = remove_const_t<typename iterator_traits<_InputIterator>::value_type::first_type>;

template<class _InputIterator>
using __iter_mapped_type = typename iterator_traits<_InputIterator>::value_type::second_type;

template<class _InputIterator>
using __iter_to_alloc_type = pair<
    add_const_t<typename iterator_traits<_InputIterator>::value_type::first_type>,
    typename iterator_traits<_InputIterator>::value_type::second_type>;
#endif // _LIBCPP_HAS_NO_DEDUCTION_GUIDES

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ITERATOR_ITERATOR_TRAITS_H
