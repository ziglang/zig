// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_FUNCTION_H
#define _LIBCPP___FUNCTIONAL_FUNCTION_H

#include <__assert>
#include <__config>
#include <__cstddef/nullptr_t.h>
#include <__exception/exception.h>
#include <__functional/binary_function.h>
#include <__functional/invoke.h>
#include <__functional/unary_function.h>
#include <__memory/addressof.h>
#include <__type_traits/aligned_storage.h>
#include <__type_traits/decay.h>
#include <__type_traits/is_core_convertible.h>
#include <__type_traits/is_scalar.h>
#include <__type_traits/is_trivially_constructible.h>
#include <__type_traits/is_trivially_destructible.h>
#include <__type_traits/is_void.h>
#include <__type_traits/strip_signature.h>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <__utility/swap.h>
#include <tuple>
#include <typeinfo>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_STD

// bad_function_call

_LIBCPP_DIAGNOSTIC_PUSH
#  if !_LIBCPP_AVAILABILITY_HAS_BAD_FUNCTION_CALL_KEY_FUNCTION
_LIBCPP_CLANG_DIAGNOSTIC_IGNORED("-Wweak-vtables")
#  endif
class _LIBCPP_EXPORTED_FROM_ABI bad_function_call : public exception {
public:
  _LIBCPP_HIDE_FROM_ABI bad_function_call() _NOEXCEPT                                    = default;
  _LIBCPP_HIDE_FROM_ABI bad_function_call(const bad_function_call&) _NOEXCEPT            = default;
  _LIBCPP_HIDE_FROM_ABI bad_function_call& operator=(const bad_function_call&) _NOEXCEPT = default;
// Note that when a key function is not used, every translation unit that uses
// bad_function_call will end up containing a weak definition of the vtable and
// typeinfo.
#  if _LIBCPP_AVAILABILITY_HAS_BAD_FUNCTION_CALL_KEY_FUNCTION
  ~bad_function_call() _NOEXCEPT override;
#  else
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~bad_function_call() _NOEXCEPT override {}
#  endif

#  if _LIBCPP_AVAILABILITY_HAS_BAD_FUNCTION_CALL_GOOD_WHAT_MESSAGE
  const char* what() const _NOEXCEPT override;
#  endif
};
_LIBCPP_DIAGNOSTIC_POP

[[__noreturn__]] inline _LIBCPP_HIDE_FROM_ABI void __throw_bad_function_call() {
#  if _LIBCPP_HAS_EXCEPTIONS
  throw bad_function_call();
#  else
  _LIBCPP_VERBOSE_ABORT("bad_function_call was thrown in -fno-exceptions mode");
#  endif
}

template <class _Fp>
class function; // undefined

namespace __function {

template <class _Rp>
struct __maybe_derive_from_unary_function {};

template <class _Rp, class _A1>
struct __maybe_derive_from_unary_function<_Rp(_A1)> : public __unary_function<_A1, _Rp> {};

template <class _Rp>
struct __maybe_derive_from_binary_function {};

template <class _Rp, class _A1, class _A2>
struct __maybe_derive_from_binary_function<_Rp(_A1, _A2)> : public __binary_function<_A1, _A2, _Rp> {};

template <class _Fp>
_LIBCPP_HIDE_FROM_ABI bool __not_null(_Fp const&) {
  return true;
}

template <class _Fp>
_LIBCPP_HIDE_FROM_ABI bool __not_null(_Fp* __ptr) {
  return __ptr;
}

template <class _Ret, class _Class>
_LIBCPP_HIDE_FROM_ABI bool __not_null(_Ret _Class::*__ptr) {
  return __ptr;
}

template <class _Fp>
_LIBCPP_HIDE_FROM_ABI bool __not_null(function<_Fp> const& __f) {
  return !!__f;
}

#  if __has_extension(blocks)
template <class _Rp, class... _Args>
_LIBCPP_HIDE_FROM_ABI bool __not_null(_Rp (^__p)(_Args...)) {
  return __p;
}
#  endif

} // namespace __function

namespace __function {

// __base provides an abstract interface for copyable functors.

template <class _Fp>
class __base;

template <class _Rp, class... _ArgTypes>
class __base<_Rp(_ArgTypes...)> {
public:
  __base(const __base&)            = delete;
  __base& operator=(const __base&) = delete;

  _LIBCPP_HIDE_FROM_ABI __base() {}
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL virtual ~__base() {}
  virtual __base* __clone() const             = 0;
  virtual void __clone(__base*) const         = 0;
  virtual void destroy() _NOEXCEPT            = 0;
  virtual void destroy_deallocate() _NOEXCEPT = 0;
  virtual _Rp operator()(_ArgTypes&&...)      = 0;
#  if _LIBCPP_HAS_RTTI
  virtual const void* target(const type_info&) const _NOEXCEPT = 0;
  virtual const std::type_info& target_type() const _NOEXCEPT  = 0;
#  endif // _LIBCPP_HAS_RTTI
};

// __func implements __base for a given functor type.

template <class _FD, class _FB>
class __func;

template <class _Fp, class _Rp, class... _ArgTypes>
class __func<_Fp, _Rp(_ArgTypes...)> : public __base<_Rp(_ArgTypes...)> {
  _Fp __func_;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __func(_Fp&& __f) : __func_(std::move(__f)) {}
  _LIBCPP_HIDE_FROM_ABI explicit __func(const _Fp& __f) : __func_(__f) {}

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL __base<_Rp(_ArgTypes...)>* __clone() const override { return new __func(__func_); }

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL void __clone(__base<_Rp(_ArgTypes...)>* __p) const override {
    ::new ((void*)__p) __func(__func_);
  }

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL void destroy() _NOEXCEPT override { __func_.~_Fp(); }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL void destroy_deallocate() _NOEXCEPT override { delete this; }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL _Rp operator()(_ArgTypes&&... __arg) override {
    return std::__invoke_r<_Rp>(__func_, std::forward<_ArgTypes>(__arg)...);
  }
#  if _LIBCPP_HAS_RTTI
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const void* target(const type_info& __ti) const _NOEXCEPT override {
    if (__ti == typeid(_Fp))
      return std::addressof(__func_);
    return nullptr;
  }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const std::type_info& target_type() const _NOEXCEPT override { return typeid(_Fp); }
#  endif // _LIBCPP_HAS_RTTI
};

// __value_func creates a value-type from a __func.

template <class _Fp>
class __value_func;

template <class _Rp, class... _ArgTypes>
class __value_func<_Rp(_ArgTypes...)> {
  _LIBCPP_SUPPRESS_DEPRECATED_PUSH
  typename aligned_storage<3 * sizeof(void*)>::type __buf_;
  _LIBCPP_SUPPRESS_DEPRECATED_POP

  typedef __base<_Rp(_ArgTypes...)> __func;
  __func* __f_;

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_NO_CFI static __func* __as_base(void* __p) { return reinterpret_cast<__func*>(__p); }

public:
  _LIBCPP_HIDE_FROM_ABI __value_func() _NOEXCEPT : __f_(nullptr) {}

  template <class _Fp, __enable_if_t<!is_same<__decay_t<_Fp>, __value_func>::value, int> = 0>
  _LIBCPP_HIDE_FROM_ABI explicit __value_func(_Fp&& __f) : __f_(nullptr) {
    typedef __function::__func<_Fp, _Rp(_ArgTypes...)> _Fun;

    if (__function::__not_null(__f)) {
      if (sizeof(_Fun) <= sizeof(__buf_) && is_nothrow_copy_constructible<_Fp>::value) {
        __f_ = ::new (std::addressof(__buf_)) _Fun(std::move(__f));
      } else {
        __f_ = new _Fun(std::move(__f));
      }
    }
  }

  _LIBCPP_HIDE_FROM_ABI __value_func(const __value_func& __f) {
    if (__f.__f_ == nullptr)
      __f_ = nullptr;
    else if ((void*)__f.__f_ == &__f.__buf_) {
      __f_ = __as_base(&__buf_);
      __f.__f_->__clone(__f_);
    } else
      __f_ = __f.__f_->__clone();
  }

  _LIBCPP_HIDE_FROM_ABI __value_func(__value_func&& __f) _NOEXCEPT {
    if (__f.__f_ == nullptr)
      __f_ = nullptr;
    else if ((void*)__f.__f_ == &__f.__buf_) {
      __f_ = __as_base(&__buf_);
      __f.__f_->__clone(__f_);
    } else {
      __f_     = __f.__f_;
      __f.__f_ = nullptr;
    }
  }

  _LIBCPP_HIDE_FROM_ABI ~__value_func() {
    if ((void*)__f_ == &__buf_)
      __f_->destroy();
    else if (__f_)
      __f_->destroy_deallocate();
  }

  _LIBCPP_HIDE_FROM_ABI __value_func& operator=(__value_func&& __f) {
    *this = nullptr;
    if (__f.__f_ == nullptr)
      __f_ = nullptr;
    else if ((void*)__f.__f_ == &__f.__buf_) {
      __f_ = __as_base(&__buf_);
      __f.__f_->__clone(__f_);
    } else {
      __f_     = __f.__f_;
      __f.__f_ = nullptr;
    }
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI __value_func& operator=(nullptr_t) {
    __func* __f = __f_;
    __f_        = nullptr;
    if ((void*)__f == &__buf_)
      __f->destroy();
    else if (__f)
      __f->destroy_deallocate();
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI _Rp operator()(_ArgTypes&&... __args) const {
    if (__f_ == nullptr)
      std::__throw_bad_function_call();
    return (*__f_)(std::forward<_ArgTypes>(__args)...);
  }

  _LIBCPP_HIDE_FROM_ABI void swap(__value_func& __f) _NOEXCEPT {
    if (std::addressof(__f) == this)
      return;
    if ((void*)__f_ == &__buf_ && (void*)__f.__f_ == &__f.__buf_) {
      _LIBCPP_SUPPRESS_DEPRECATED_PUSH
      typename aligned_storage<sizeof(__buf_)>::type __tempbuf;
      _LIBCPP_SUPPRESS_DEPRECATED_POP
      __func* __t = __as_base(&__tempbuf);
      __f_->__clone(__t);
      __f_->destroy();
      __f_ = nullptr;
      __f.__f_->__clone(__as_base(&__buf_));
      __f.__f_->destroy();
      __f.__f_ = nullptr;
      __f_     = __as_base(&__buf_);
      __t->__clone(__as_base(&__f.__buf_));
      __t->destroy();
      __f.__f_ = __as_base(&__f.__buf_);
    } else if ((void*)__f_ == &__buf_) {
      __f_->__clone(__as_base(&__f.__buf_));
      __f_->destroy();
      __f_     = __f.__f_;
      __f.__f_ = __as_base(&__f.__buf_);
    } else if ((void*)__f.__f_ == &__f.__buf_) {
      __f.__f_->__clone(__as_base(&__buf_));
      __f.__f_->destroy();
      __f.__f_ = __f_;
      __f_     = __as_base(&__buf_);
    } else
      std::swap(__f_, __f.__f_);
  }

  _LIBCPP_HIDE_FROM_ABI explicit operator bool() const _NOEXCEPT { return __f_ != nullptr; }

#  if _LIBCPP_HAS_RTTI
  _LIBCPP_HIDE_FROM_ABI const std::type_info& target_type() const _NOEXCEPT {
    if (__f_ == nullptr)
      return typeid(void);
    return __f_->target_type();
  }

  template <typename _Tp>
  _LIBCPP_HIDE_FROM_ABI const _Tp* target() const _NOEXCEPT {
    if (__f_ == nullptr)
      return nullptr;
    return (const _Tp*)__f_->target(typeid(_Tp));
  }
#  endif // _LIBCPP_HAS_RTTI
};

// Storage for a functor object, to be used with __policy to manage copy and
// destruction.
union __policy_storage {
  mutable char __small[sizeof(void*) * 2];
  void* __large;
};

// True if _Fun can safely be held in __policy_storage.__small.
template <typename _Fun>
struct __use_small_storage
    : public integral_constant<
          bool,
          sizeof(_Fun) <= sizeof(__policy_storage)&& _LIBCPP_ALIGNOF(_Fun) <= _LIBCPP_ALIGNOF(__policy_storage) &&
              is_trivially_copy_constructible<_Fun>::value && is_trivially_destructible<_Fun>::value> {};

// Policy contains information about how to copy, destroy, and move the
// underlying functor. You can think of it as a vtable of sorts.
struct __policy {
  // Used to copy or destroy __large values. null for trivial objects.
  void* (*const __clone)(const void*);
  void (*const __destroy)(void*);

  // True if this is the null policy (no value).
  const bool __is_null;

  // The target type. May be null if RTTI is disabled.
  const std::type_info* const __type_info;

  // Returns a pointer to a static policy object suitable for the functor
  // type.
  template <typename _Fun>
  _LIBCPP_HIDE_FROM_ABI static const __policy* __create() {
    return __choose_policy<_Fun>(__use_small_storage<_Fun>());
  }

  _LIBCPP_HIDE_FROM_ABI static const __policy* __create_empty() {
    static constexpr __policy __policy = {
        nullptr,
        nullptr,
        true,
#  if _LIBCPP_HAS_RTTI
        &typeid(void)
#  else
        nullptr
#  endif
    };
    return &__policy;
  }

private:
  template <typename _Fun>
  _LIBCPP_HIDE_FROM_ABI static void* __large_clone(const void* __s) {
    const _Fun* __f = static_cast<const _Fun*>(__s);
    return new _Fun(*__f);
  }

  template <typename _Fun>
  _LIBCPP_HIDE_FROM_ABI static void __large_destroy(void* __s) {
    delete static_cast<_Fun*>(__s);
  }

  template <typename _Fun>
  _LIBCPP_HIDE_FROM_ABI static const __policy* __choose_policy(/* is_small = */ false_type) {
    static constexpr __policy __policy = {
        std::addressof(__large_clone<_Fun>),
        std::addressof(__large_destroy<_Fun>),
        false,
#  if _LIBCPP_HAS_RTTI
        &typeid(_Fun)
#  else
        nullptr
#  endif
    };
    return &__policy;
  }

  template <typename _Fun>
  _LIBCPP_HIDE_FROM_ABI static const __policy* __choose_policy(/* is_small = */ true_type) {
    static constexpr __policy __policy = {
        nullptr,
        nullptr,
        false,
#  if _LIBCPP_HAS_RTTI
        &typeid(_Fun)
#  else
        nullptr
#  endif
    };
    return &__policy;
  }
};

// Used to choose between perfect forwarding or pass-by-value. Pass-by-value is
// faster for types that can be passed in registers.
template <typename _Tp>
using __fast_forward _LIBCPP_NODEBUG = __conditional_t<is_scalar<_Tp>::value, _Tp, _Tp&&>;

// __policy_func uses a __policy to create a type-erased, copyable functor.

template <class _Fp>
class __policy_func;

template <class _Rp, class... _ArgTypes>
class __policy_func<_Rp(_ArgTypes...)> {
  // Inline storage for small objects.
  __policy_storage __buf_;

  using _ErasedFunc _LIBCPP_NODEBUG = _Rp(const __policy_storage*, __fast_forward<_ArgTypes>...);

  _ErasedFunc* __func_;

  // The policy that describes how to move / copy / destroy __buf_. Never
  // null, even if the function is empty.
  const __policy* __policy_;

  _LIBCPP_HIDE_FROM_ABI static _Rp __empty_func(const __policy_storage*, __fast_forward<_ArgTypes>...) {
    std::__throw_bad_function_call();
  }

  template <class _Fun>
  _LIBCPP_HIDE_FROM_ABI static _Rp __call_func(const __policy_storage* __buf, __fast_forward<_ArgTypes>... __args) {
    _Fun* __func = reinterpret_cast<_Fun*>(__use_small_storage<_Fun>::value ? &__buf->__small : __buf->__large);

    return std::__invoke_r<_Rp>(*__func, std::forward<_ArgTypes>(__args)...);
  }

public:
  _LIBCPP_HIDE_FROM_ABI __policy_func() : __func_(__empty_func), __policy_(__policy::__create_empty()) {}

  template <class _Fp, __enable_if_t<!is_same<__decay_t<_Fp>, __policy_func>::value, int> = 0>
  _LIBCPP_HIDE_FROM_ABI explicit __policy_func(_Fp&& __f) : __policy_(__policy::__create_empty()) {
    if (__function::__not_null(__f)) {
      __func_   = __call_func<_Fp>;
      __policy_ = __policy::__create<_Fp>();
      if (__use_small_storage<_Fp>()) {
        ::new ((void*)&__buf_.__small) _Fp(std::move(__f));
      } else {
        __buf_.__large = ::new _Fp(std::move(__f));
      }
    }
  }

  _LIBCPP_HIDE_FROM_ABI __policy_func(const __policy_func& __f)
      : __buf_(__f.__buf_), __func_(__f.__func_), __policy_(__f.__policy_) {
    if (__policy_->__clone)
      __buf_.__large = __policy_->__clone(__f.__buf_.__large);
  }

  _LIBCPP_HIDE_FROM_ABI __policy_func(__policy_func&& __f)
      : __buf_(__f.__buf_), __func_(__f.__func_), __policy_(__f.__policy_) {
    if (__policy_->__destroy) {
      __f.__policy_ = __policy::__create_empty();
      __f.__func_   = {};
    }
  }

  _LIBCPP_HIDE_FROM_ABI ~__policy_func() {
    if (__policy_->__destroy)
      __policy_->__destroy(__buf_.__large);
  }

  _LIBCPP_HIDE_FROM_ABI __policy_func& operator=(__policy_func&& __f) {
    *this         = nullptr;
    __buf_        = __f.__buf_;
    __func_       = __f.__func_;
    __policy_     = __f.__policy_;
    __f.__policy_ = __policy::__create_empty();
    __f.__func_   = {};
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI __policy_func& operator=(nullptr_t) {
    const __policy* __p = __policy_;
    __policy_           = __policy::__create_empty();
    __func_             = {};
    if (__p->__destroy)
      __p->__destroy(__buf_.__large);
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI _Rp operator()(_ArgTypes&&... __args) const {
    return __func_(std::addressof(__buf_), std::forward<_ArgTypes>(__args)...);
  }

  _LIBCPP_HIDE_FROM_ABI void swap(__policy_func& __f) {
    std::swap(__func_, __f.__func_);
    std::swap(__policy_, __f.__policy_);
    std::swap(__buf_, __f.__buf_);
  }

  _LIBCPP_HIDE_FROM_ABI explicit operator bool() const _NOEXCEPT { return !__policy_->__is_null; }

#  if _LIBCPP_HAS_RTTI
  _LIBCPP_HIDE_FROM_ABI const std::type_info& target_type() const _NOEXCEPT { return *__policy_->__type_info; }

  template <typename _Tp>
  _LIBCPP_HIDE_FROM_ABI const _Tp* target() const _NOEXCEPT {
    if (__policy_->__is_null || typeid(_Tp) != *__policy_->__type_info)
      return nullptr;
    if (__policy_->__clone) // Out of line storage.
      return reinterpret_cast<const _Tp*>(__buf_.__large);
    else
      return reinterpret_cast<const _Tp*>(&__buf_.__small);
  }
#  endif // _LIBCPP_HAS_RTTI
};

#  if _LIBCPP_HAS_BLOCKS_RUNTIME

extern "C" void* _Block_copy(const void*);
extern "C" void _Block_release(const void*);

template <class _Rp1, class... _ArgTypes1, class _Rp, class... _ArgTypes>
class __func<_Rp1 (^)(_ArgTypes1...), _Rp(_ArgTypes...)> : public __base<_Rp(_ArgTypes...)> {
  typedef _Rp1 (^__block_type)(_ArgTypes1...);
  __block_type __f_;

public:
  _LIBCPP_HIDE_FROM_ABI explicit __func(__block_type const& __f)
#    if __has_feature(objc_arc)
      : __f_(__f)
#    else
      : __f_(reinterpret_cast<__block_type>(__f ? _Block_copy(__f) : nullptr))
#    endif
  {
  }

  // [TODO] add && to save on a retain

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL virtual __base<_Rp(_ArgTypes...)>* __clone() const {
    _LIBCPP_ASSERT_INTERNAL(
        false,
        "Block pointers are just pointers, so they should always fit into "
        "std::function's small buffer optimization. This function should "
        "never be invoked.");
    return nullptr;
  }

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL virtual void __clone(__base<_Rp(_ArgTypes...)>* __p) const {
    ::new ((void*)__p) __func(__f_);
  }

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL virtual void destroy() _NOEXCEPT {
#    if !__has_feature(objc_arc)
    if (__f_)
      _Block_release(__f_);
#    endif
    __f_ = 0;
  }

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL virtual void destroy_deallocate() _NOEXCEPT {
    _LIBCPP_ASSERT_INTERNAL(
        false,
        "Block pointers are just pointers, so they should always fit into "
        "std::function's small buffer optimization. This function should "
        "never be invoked.");
  }

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL virtual _Rp operator()(_ArgTypes&&... __arg) {
    return std::__invoke(__f_, std::forward<_ArgTypes>(__arg)...);
  }

#    if _LIBCPP_HAS_RTTI
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL virtual const void* target(type_info const& __ti) const _NOEXCEPT {
    if (__ti == typeid(__func::__block_type))
      return &__f_;
    return (const void*)nullptr;
  }

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL virtual const std::type_info& target_type() const _NOEXCEPT {
    return typeid(__func::__block_type);
  }
#    endif // _LIBCPP_HAS_RTTI
};

#  endif // _LIBCPP_HAS_BLOCKS_RUNTIME

} // namespace __function

template <class _Rp, class... _ArgTypes>
class function<_Rp(_ArgTypes...)>
    : public __function::__maybe_derive_from_unary_function<_Rp(_ArgTypes...)>,
      public __function::__maybe_derive_from_binary_function<_Rp(_ArgTypes...)> {
#  ifndef _LIBCPP_ABI_OPTIMIZED_FUNCTION
  typedef __function::__value_func<_Rp(_ArgTypes...)> __func;
#  else
  typedef __function::__policy_func<_Rp(_ArgTypes...)> __func;
#  endif

  __func __f_;

  template <class _Fp,
            bool = _And<_IsNotSame<__remove_cvref_t<_Fp>, function>, __is_invocable<_Fp, _ArgTypes...> >::value>
  struct __callable;
  template <class _Fp>
  struct __callable<_Fp, true> {
    static const bool value =
        is_void<_Rp>::value || __is_core_convertible<__invoke_result_t<_Fp, _ArgTypes...>, _Rp>::value;
  };
  template <class _Fp>
  struct __callable<_Fp, false> {
    static const bool value = false;
  };

  template <class _Fp>
  using _EnableIfLValueCallable _LIBCPP_NODEBUG = __enable_if_t<__callable<_Fp&>::value>;

public:
  typedef _Rp result_type;

  // construct/copy/destroy:
  _LIBCPP_HIDE_FROM_ABI function() _NOEXCEPT {}
  _LIBCPP_HIDE_FROM_ABI function(nullptr_t) _NOEXCEPT {}
  _LIBCPP_HIDE_FROM_ABI function(const function&);
  _LIBCPP_HIDE_FROM_ABI function(function&&) _NOEXCEPT;
  template <class _Fp, class = _EnableIfLValueCallable<_Fp>>
  _LIBCPP_HIDE_FROM_ABI function(_Fp);

#  if _LIBCPP_STD_VER <= 14
  template <class _Alloc>
  _LIBCPP_HIDE_FROM_ABI function(allocator_arg_t, const _Alloc&) _NOEXCEPT {}
  template <class _Alloc>
  _LIBCPP_HIDE_FROM_ABI function(allocator_arg_t, const _Alloc&, nullptr_t) _NOEXCEPT {}
  template <class _Alloc>
  _LIBCPP_HIDE_FROM_ABI function(allocator_arg_t, const _Alloc&, const function&);
  template <class _Alloc>
  _LIBCPP_HIDE_FROM_ABI function(allocator_arg_t, const _Alloc&, function&&);
  template <class _Fp, class _Alloc, class = _EnableIfLValueCallable<_Fp>>
  _LIBCPP_HIDE_FROM_ABI function(allocator_arg_t, const _Alloc& __a, _Fp __f);
#  endif

  _LIBCPP_HIDE_FROM_ABI function& operator=(const function&);
  _LIBCPP_HIDE_FROM_ABI function& operator=(function&&) _NOEXCEPT;
  _LIBCPP_HIDE_FROM_ABI function& operator=(nullptr_t) _NOEXCEPT;
  template <class _Fp, class = _EnableIfLValueCallable<__decay_t<_Fp>>>
  _LIBCPP_HIDE_FROM_ABI function& operator=(_Fp&&);

  _LIBCPP_HIDE_FROM_ABI ~function();

  // function modifiers:
  _LIBCPP_HIDE_FROM_ABI void swap(function&) _NOEXCEPT;

#  if _LIBCPP_STD_VER <= 14
  template <class _Fp, class _Alloc>
  _LIBCPP_HIDE_FROM_ABI void assign(_Fp&& __f, const _Alloc& __a) {
    function(allocator_arg, __a, std::forward<_Fp>(__f)).swap(*this);
  }
#  endif

  // function capacity:
  _LIBCPP_HIDE_FROM_ABI explicit operator bool() const _NOEXCEPT { return static_cast<bool>(__f_); }

  // deleted overloads close possible hole in the type system
  template <class _R2, class... _ArgTypes2>
  bool operator==(const function<_R2(_ArgTypes2...)>&) const = delete;
#  if _LIBCPP_STD_VER <= 17
  template <class _R2, class... _ArgTypes2>
  bool operator!=(const function<_R2(_ArgTypes2...)>&) const = delete;
#  endif

public:
  // function invocation:
  _LIBCPP_HIDE_FROM_ABI _Rp operator()(_ArgTypes...) const;

#  if _LIBCPP_HAS_RTTI
  // function target access:
  _LIBCPP_HIDE_FROM_ABI const std::type_info& target_type() const _NOEXCEPT;
  template <typename _Tp>
  _LIBCPP_HIDE_FROM_ABI _Tp* target() _NOEXCEPT;
  template <typename _Tp>
  _LIBCPP_HIDE_FROM_ABI const _Tp* target() const _NOEXCEPT;
#  endif // _LIBCPP_HAS_RTTI
};

#  if _LIBCPP_STD_VER >= 17
template <class _Rp, class... _Ap>
function(_Rp (*)(_Ap...)) -> function<_Rp(_Ap...)>;

template <class _Fp, class _Stripped = typename __strip_signature<decltype(&_Fp::operator())>::type>
function(_Fp) -> function<_Stripped>;
#  endif // _LIBCPP_STD_VER >= 17

template <class _Rp, class... _ArgTypes>
function<_Rp(_ArgTypes...)>::function(const function& __f) : __f_(__f.__f_) {}

#  if _LIBCPP_STD_VER <= 14
template <class _Rp, class... _ArgTypes>
template <class _Alloc>
function<_Rp(_ArgTypes...)>::function(allocator_arg_t, const _Alloc&, const function& __f) : __f_(__f.__f_) {}
#  endif

template <class _Rp, class... _ArgTypes>
function<_Rp(_ArgTypes...)>::function(function&& __f) _NOEXCEPT : __f_(std::move(__f.__f_)) {}

#  if _LIBCPP_STD_VER <= 14
template <class _Rp, class... _ArgTypes>
template <class _Alloc>
function<_Rp(_ArgTypes...)>::function(allocator_arg_t, const _Alloc&, function&& __f) : __f_(std::move(__f.__f_)) {}
#  endif

template <class _Rp, class... _ArgTypes>
template <class _Fp, class>
function<_Rp(_ArgTypes...)>::function(_Fp __f) : __f_(std::move(__f)) {}

#  if _LIBCPP_STD_VER <= 14
template <class _Rp, class... _ArgTypes>
template <class _Fp, class _Alloc, class>
function<_Rp(_ArgTypes...)>::function(allocator_arg_t, const _Alloc&, _Fp __f) : __f_(std::move(__f)) {}
#  endif

template <class _Rp, class... _ArgTypes>
function<_Rp(_ArgTypes...)>& function<_Rp(_ArgTypes...)>::operator=(const function& __f) {
  function(__f).swap(*this);
  return *this;
}

template <class _Rp, class... _ArgTypes>
function<_Rp(_ArgTypes...)>& function<_Rp(_ArgTypes...)>::operator=(function&& __f) _NOEXCEPT {
  __f_ = std::move(__f.__f_);
  return *this;
}

template <class _Rp, class... _ArgTypes>
function<_Rp(_ArgTypes...)>& function<_Rp(_ArgTypes...)>::operator=(nullptr_t) _NOEXCEPT {
  __f_ = nullptr;
  return *this;
}

template <class _Rp, class... _ArgTypes>
template <class _Fp, class>
function<_Rp(_ArgTypes...)>& function<_Rp(_ArgTypes...)>::operator=(_Fp&& __f) {
  function(std::forward<_Fp>(__f)).swap(*this);
  return *this;
}

template <class _Rp, class... _ArgTypes>
function<_Rp(_ArgTypes...)>::~function() {}

template <class _Rp, class... _ArgTypes>
void function<_Rp(_ArgTypes...)>::swap(function& __f) _NOEXCEPT {
  __f_.swap(__f.__f_);
}

template <class _Rp, class... _ArgTypes>
_Rp function<_Rp(_ArgTypes...)>::operator()(_ArgTypes... __arg) const {
  return __f_(std::forward<_ArgTypes>(__arg)...);
}

#  if _LIBCPP_HAS_RTTI

template <class _Rp, class... _ArgTypes>
const std::type_info& function<_Rp(_ArgTypes...)>::target_type() const _NOEXCEPT {
  return __f_.target_type();
}

template <class _Rp, class... _ArgTypes>
template <typename _Tp>
_Tp* function<_Rp(_ArgTypes...)>::target() _NOEXCEPT {
  return (_Tp*)(__f_.template target<_Tp>());
}

template <class _Rp, class... _ArgTypes>
template <typename _Tp>
const _Tp* function<_Rp(_ArgTypes...)>::target() const _NOEXCEPT {
  return __f_.template target<_Tp>();
}

#  endif // _LIBCPP_HAS_RTTI

template <class _Rp, class... _ArgTypes>
inline _LIBCPP_HIDE_FROM_ABI bool operator==(const function<_Rp(_ArgTypes...)>& __f, nullptr_t) _NOEXCEPT {
  return !__f;
}

#  if _LIBCPP_STD_VER <= 17

template <class _Rp, class... _ArgTypes>
inline _LIBCPP_HIDE_FROM_ABI bool operator==(nullptr_t, const function<_Rp(_ArgTypes...)>& __f) _NOEXCEPT {
  return !__f;
}

template <class _Rp, class... _ArgTypes>
inline _LIBCPP_HIDE_FROM_ABI bool operator!=(const function<_Rp(_ArgTypes...)>& __f, nullptr_t) _NOEXCEPT {
  return (bool)__f;
}

template <class _Rp, class... _ArgTypes>
inline _LIBCPP_HIDE_FROM_ABI bool operator!=(nullptr_t, const function<_Rp(_ArgTypes...)>& __f) _NOEXCEPT {
  return (bool)__f;
}

#  endif // _LIBCPP_STD_VER <= 17

template <class _Rp, class... _ArgTypes>
inline _LIBCPP_HIDE_FROM_ABI void swap(function<_Rp(_ArgTypes...)>& __x, function<_Rp(_ArgTypes...)>& __y) _NOEXCEPT {
  return __x.swap(__y);
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_CXX03_LANG

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FUNCTIONAL_FUNCTION_H
