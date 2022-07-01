// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_WEAK_RESULT_TYPE_H
#define _LIBCPP___FUNCTIONAL_WEAK_RESULT_TYPE_H

#include <__config>
#include <__functional/binary_function.h>
#include <__functional/unary_function.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
struct __has_result_type
{
private:
    struct __two {char __lx; char __lxx;};
    template <class _Up> static __two __test(...);
    template <class _Up> static char __test(typename _Up::result_type* = 0);
public:
    static const bool value = sizeof(__test<_Tp>(0)) == 1;
};

// __weak_result_type

template <class _Tp>
struct __derives_from_unary_function
{
private:
    struct __two {char __lx; char __lxx;};
    static __two __test(...);
    template <class _Ap, class _Rp>
        static unary_function<_Ap, _Rp>
        __test(const volatile unary_function<_Ap, _Rp>*);
public:
    static const bool value = !is_same<decltype(__test((_Tp*)0)), __two>::value;
    typedef decltype(__test((_Tp*)0)) type;
};

template <class _Tp>
struct __derives_from_binary_function
{
private:
    struct __two {char __lx; char __lxx;};
    static __two __test(...);
    template <class _A1, class _A2, class _Rp>
        static binary_function<_A1, _A2, _Rp>
        __test(const volatile binary_function<_A1, _A2, _Rp>*);
public:
    static const bool value = !is_same<decltype(__test((_Tp*)0)), __two>::value;
    typedef decltype(__test((_Tp*)0)) type;
};

template <class _Tp, bool = __derives_from_unary_function<_Tp>::value>
struct __maybe_derive_from_unary_function  // bool is true
    : public __derives_from_unary_function<_Tp>::type
{
};

template <class _Tp>
struct __maybe_derive_from_unary_function<_Tp, false>
{
};

template <class _Tp, bool = __derives_from_binary_function<_Tp>::value>
struct __maybe_derive_from_binary_function  // bool is true
    : public __derives_from_binary_function<_Tp>::type
{
};

template <class _Tp>
struct __maybe_derive_from_binary_function<_Tp, false>
{
};

template <class _Tp, bool = __has_result_type<_Tp>::value>
struct __weak_result_type_imp // bool is true
    : public __maybe_derive_from_unary_function<_Tp>,
      public __maybe_derive_from_binary_function<_Tp>
{
    typedef _LIBCPP_NODEBUG typename _Tp::result_type result_type;
};

template <class _Tp>
struct __weak_result_type_imp<_Tp, false>
    : public __maybe_derive_from_unary_function<_Tp>,
      public __maybe_derive_from_binary_function<_Tp>
{
};

template <class _Tp>
struct __weak_result_type
    : public __weak_result_type_imp<_Tp>
{
};

// 0 argument case

template <class _Rp>
struct __weak_result_type<_Rp ()>
{
    typedef _LIBCPP_NODEBUG _Rp result_type;
};

template <class _Rp>
struct __weak_result_type<_Rp (&)()>
{
    typedef _LIBCPP_NODEBUG _Rp result_type;
};

template <class _Rp>
struct __weak_result_type<_Rp (*)()>
{
    typedef _LIBCPP_NODEBUG _Rp result_type;
};

// 1 argument case

template <class _Rp, class _A1>
struct __weak_result_type<_Rp (_A1)>
    : public unary_function<_A1, _Rp>
{
};

template <class _Rp, class _A1>
struct __weak_result_type<_Rp (&)(_A1)>
    : public unary_function<_A1, _Rp>
{
};

template <class _Rp, class _A1>
struct __weak_result_type<_Rp (*)(_A1)>
    : public unary_function<_A1, _Rp>
{
};

template <class _Rp, class _Cp>
struct __weak_result_type<_Rp (_Cp::*)()>
    : public unary_function<_Cp*, _Rp>
{
};

template <class _Rp, class _Cp>
struct __weak_result_type<_Rp (_Cp::*)() const>
    : public unary_function<const _Cp*, _Rp>
{
};

template <class _Rp, class _Cp>
struct __weak_result_type<_Rp (_Cp::*)() volatile>
    : public unary_function<volatile _Cp*, _Rp>
{
};

template <class _Rp, class _Cp>
struct __weak_result_type<_Rp (_Cp::*)() const volatile>
    : public unary_function<const volatile _Cp*, _Rp>
{
};

// 2 argument case

template <class _Rp, class _A1, class _A2>
struct __weak_result_type<_Rp (_A1, _A2)>
    : public binary_function<_A1, _A2, _Rp>
{
};

template <class _Rp, class _A1, class _A2>
struct __weak_result_type<_Rp (*)(_A1, _A2)>
    : public binary_function<_A1, _A2, _Rp>
{
};

template <class _Rp, class _A1, class _A2>
struct __weak_result_type<_Rp (&)(_A1, _A2)>
    : public binary_function<_A1, _A2, _Rp>
{
};

template <class _Rp, class _Cp, class _A1>
struct __weak_result_type<_Rp (_Cp::*)(_A1)>
    : public binary_function<_Cp*, _A1, _Rp>
{
};

template <class _Rp, class _Cp, class _A1>
struct __weak_result_type<_Rp (_Cp::*)(_A1) const>
    : public binary_function<const _Cp*, _A1, _Rp>
{
};

template <class _Rp, class _Cp, class _A1>
struct __weak_result_type<_Rp (_Cp::*)(_A1) volatile>
    : public binary_function<volatile _Cp*, _A1, _Rp>
{
};

template <class _Rp, class _Cp, class _A1>
struct __weak_result_type<_Rp (_Cp::*)(_A1) const volatile>
    : public binary_function<const volatile _Cp*, _A1, _Rp>
{
};


#ifndef _LIBCPP_CXX03_LANG
// 3 or more arguments

template <class _Rp, class _A1, class _A2, class _A3, class ..._A4>
struct __weak_result_type<_Rp (_A1, _A2, _A3, _A4...)>
{
    typedef _Rp result_type;
};

template <class _Rp, class _A1, class _A2, class _A3, class ..._A4>
struct __weak_result_type<_Rp (&)(_A1, _A2, _A3, _A4...)>
{
    typedef _Rp result_type;
};

template <class _Rp, class _A1, class _A2, class _A3, class ..._A4>
struct __weak_result_type<_Rp (*)(_A1, _A2, _A3, _A4...)>
{
    typedef _Rp result_type;
};

template <class _Rp, class _Cp, class _A1, class _A2, class ..._A3>
struct __weak_result_type<_Rp (_Cp::*)(_A1, _A2, _A3...)>
{
    typedef _Rp result_type;
};

template <class _Rp, class _Cp, class _A1, class _A2, class ..._A3>
struct __weak_result_type<_Rp (_Cp::*)(_A1, _A2, _A3...) const>
{
    typedef _Rp result_type;
};

template <class _Rp, class _Cp, class _A1, class _A2, class ..._A3>
struct __weak_result_type<_Rp (_Cp::*)(_A1, _A2, _A3...) volatile>
{
    typedef _Rp result_type;
};

template <class _Rp, class _Cp, class _A1, class _A2, class ..._A3>
struct __weak_result_type<_Rp (_Cp::*)(_A1, _A2, _A3...) const volatile>
{
    typedef _Rp result_type;
};

template <class _Tp, class ..._Args>
struct __invoke_return
{
    typedef decltype(_VSTD::__invoke(declval<_Tp>(), declval<_Args>()...)) type;
};

#else // defined(_LIBCPP_CXX03_LANG)

template <class _Ret, class _T1, bool _IsFunc, bool _IsBase>
struct __enable_invoke_imp;

template <class _Ret, class _T1>
struct __enable_invoke_imp<_Ret, _T1, true, true> {
    typedef _Ret _Bullet1;
    typedef _Bullet1 type;
};

template <class _Ret, class _T1>
struct __enable_invoke_imp<_Ret, _T1, true, false>  {
    typedef _Ret _Bullet2;
    typedef _Bullet2 type;
};

template <class _Ret, class _T1>
struct __enable_invoke_imp<_Ret, _T1, false, true>  {
    typedef typename add_lvalue_reference<
                typename __apply_cv<_T1, _Ret>::type
            >::type _Bullet3;
    typedef _Bullet3 type;
};

template <class _Ret, class _T1>
struct __enable_invoke_imp<_Ret, _T1, false, false>  {
    typedef typename add_lvalue_reference<
                typename __apply_cv<decltype(*declval<_T1>()), _Ret>::type
            >::type _Bullet4;
    typedef _Bullet4 type;
};

template <class _Ret, class _T1>
struct __enable_invoke_imp<_Ret, _T1*, false, false>  {
    typedef typename add_lvalue_reference<
                typename __apply_cv<_T1, _Ret>::type
            >::type _Bullet4;
    typedef _Bullet4  type;
};

template <class _Fn, class _T1,
          class _Traits = __member_pointer_traits<_Fn>,
          class _Ret = typename _Traits::_ReturnType,
          class _Class = typename _Traits::_ClassType>
struct __enable_invoke : __enable_invoke_imp<
    _Ret, _T1,
    is_member_function_pointer<_Fn>::value,
    is_base_of<_Class, typename remove_reference<_T1>::type>::value>
{
};

__nat __invoke(__any, ...);

// first bullet

template <class _Fn, class _T1>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet1
__invoke(_Fn __f, _T1& __t1) {
    return (__t1.*__f)();
}

template <class _Fn, class _T1, class _A0>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet1
__invoke(_Fn __f, _T1& __t1, _A0& __a0) {
    return (__t1.*__f)(__a0);
}

template <class _Fn, class _T1, class _A0, class _A1>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet1
__invoke(_Fn __f, _T1& __t1, _A0& __a0, _A1& __a1) {
    return (__t1.*__f)(__a0, __a1);
}

template <class _Fn, class _T1, class _A0, class _A1, class _A2>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet1
__invoke(_Fn __f, _T1& __t1, _A0& __a0, _A1& __a1, _A2& __a2) {
    return (__t1.*__f)(__a0, __a1, __a2);
}

template <class _Fn, class _T1>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet2
__invoke(_Fn __f, _T1& __t1) {
    return ((*__t1).*__f)();
}

template <class _Fn, class _T1, class _A0>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet2
__invoke(_Fn __f, _T1& __t1, _A0& __a0) {
    return ((*__t1).*__f)(__a0);
}

template <class _Fn, class _T1, class _A0, class _A1>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet2
__invoke(_Fn __f, _T1& __t1, _A0& __a0, _A1& __a1) {
    return ((*__t1).*__f)(__a0, __a1);
}

template <class _Fn, class _T1, class _A0, class _A1, class _A2>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet2
__invoke(_Fn __f, _T1& __t1, _A0& __a0, _A1& __a1, _A2& __a2) {
    return ((*__t1).*__f)(__a0, __a1, __a2);
}

template <class _Fn, class _T1>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet3
__invoke(_Fn __f, _T1& __t1) {
    return __t1.*__f;
}

template <class _Fn, class _T1>
inline _LIBCPP_INLINE_VISIBILITY
typename __enable_invoke<_Fn, _T1>::_Bullet4
__invoke(_Fn __f, _T1& __t1) {
    return (*__t1).*__f;
}

// fifth bullet

template <class _Fp>
inline _LIBCPP_INLINE_VISIBILITY
decltype(declval<_Fp&>()())
__invoke(_Fp& __f)
{
    return __f();
}

template <class _Fp, class _A0>
inline _LIBCPP_INLINE_VISIBILITY
decltype(declval<_Fp&>()(declval<_A0&>()))
__invoke(_Fp& __f, _A0& __a0)
{
    return __f(__a0);
}

template <class _Fp, class _A0, class _A1>
inline _LIBCPP_INLINE_VISIBILITY
decltype(declval<_Fp&>()(declval<_A0&>(), declval<_A1&>()))
__invoke(_Fp& __f, _A0& __a0, _A1& __a1)
{
    return __f(__a0, __a1);
}

template <class _Fp, class _A0, class _A1, class _A2>
inline _LIBCPP_INLINE_VISIBILITY
decltype(declval<_Fp&>()(declval<_A0&>(), declval<_A1&>(), declval<_A2&>()))
__invoke(_Fp& __f, _A0& __a0, _A1& __a1, _A2& __a2)
{
    return __f(__a0, __a1, __a2);
}

template <class _Fp, bool = __has_result_type<__weak_result_type<_Fp> >::value>
struct __invoke_return
{
    typedef typename __weak_result_type<_Fp>::result_type type;
};

template <class _Fp>
struct __invoke_return<_Fp, false>
{
    typedef decltype(_VSTD::__invoke(declval<_Fp&>())) type;
};

template <class _Tp, class _A0>
struct __invoke_return0
{
    typedef decltype(_VSTD::__invoke(declval<_Tp&>(), declval<_A0&>())) type;
};

template <class _Rp, class _Tp, class _A0>
struct __invoke_return0<_Rp _Tp::*, _A0>
{
    typedef typename __enable_invoke<_Rp _Tp::*, _A0>::type type;
};

template <class _Tp, class _A0, class _A1>
struct __invoke_return1
{
    typedef decltype(_VSTD::__invoke(declval<_Tp&>(), declval<_A0&>(),
                                                      declval<_A1&>())) type;
};

template <class _Rp, class _Class, class _A0, class _A1>
struct __invoke_return1<_Rp _Class::*, _A0, _A1> {
    typedef typename __enable_invoke<_Rp _Class::*, _A0>::type type;
};

template <class _Tp, class _A0, class _A1, class _A2>
struct __invoke_return2
{
    typedef decltype(_VSTD::__invoke(declval<_Tp&>(), declval<_A0&>(),
                                                      declval<_A1&>(),
                                                      declval<_A2&>())) type;
};

template <class _Ret, class _Class, class _A0, class _A1, class _A2>
struct __invoke_return2<_Ret _Class::*, _A0, _A1, _A2> {
    typedef typename __enable_invoke<_Ret _Class::*, _A0>::type type;
};

#endif // !defined(_LIBCPP_CXX03_LANG)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_WEAK_RESULT_TYPE_H
