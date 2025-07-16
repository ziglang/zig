// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_VECTOR
#define _LIBCPP_VECTOR

// clang-format off

/*
    vector synopsis

namespace std
{

template <class T, class Allocator = allocator<T> >
class vector
{
public:
    typedef T                                        value_type;
    typedef Allocator                                allocator_type;
    typedef typename allocator_type::reference       reference;
    typedef typename allocator_type::const_reference const_reference;
    typedef implementation-defined                   iterator;
    typedef implementation-defined                   const_iterator;
    typedef typename allocator_type::size_type       size_type;
    typedef typename allocator_type::difference_type difference_type;
    typedef typename allocator_type::pointer         pointer;
    typedef typename allocator_type::const_pointer   const_pointer;
    typedef std::reverse_iterator<iterator>          reverse_iterator;
    typedef std::reverse_iterator<const_iterator>    const_reverse_iterator;

    vector()
        noexcept(is_nothrow_default_constructible<allocator_type>::value);
    explicit vector(const allocator_type&);
    explicit vector(size_type n);
    explicit vector(size_type n, const allocator_type&); // C++14
    vector(size_type n, const value_type& value, const allocator_type& = allocator_type());
    template <class InputIterator>
        vector(InputIterator first, InputIterator last, const allocator_type& = allocator_type());
    template<container-compatible-range<T> R>
      constexpr vector(from_range_t, R&& rg, const Allocator& = Allocator()); // C++23
    vector(const vector& x);
    vector(vector&& x)
        noexcept(is_nothrow_move_constructible<allocator_type>::value);
    vector(initializer_list<value_type> il);
    vector(initializer_list<value_type> il, const allocator_type& a);
    ~vector();
    vector& operator=(const vector& x);
    vector& operator=(vector&& x)
        noexcept(
             allocator_type::propagate_on_container_move_assignment::value ||
             allocator_type::is_always_equal::value); // C++17
    vector& operator=(initializer_list<value_type> il);
    template <class InputIterator>
        void assign(InputIterator first, InputIterator last);
    template<container-compatible-range<T> R>
      constexpr void assign_range(R&& rg); // C++23
    void assign(size_type n, const value_type& u);
    void assign(initializer_list<value_type> il);

    allocator_type get_allocator() const noexcept;

    iterator               begin() noexcept;
    const_iterator         begin()   const noexcept;
    iterator               end() noexcept;
    const_iterator         end()     const noexcept;

    reverse_iterator       rbegin() noexcept;
    const_reverse_iterator rbegin()  const noexcept;
    reverse_iterator       rend() noexcept;
    const_reverse_iterator rend()    const noexcept;

    const_iterator         cbegin()  const noexcept;
    const_iterator         cend()    const noexcept;
    const_reverse_iterator crbegin() const noexcept;
    const_reverse_iterator crend()   const noexcept;

    size_type size() const noexcept;
    size_type max_size() const noexcept;
    size_type capacity() const noexcept;
    bool empty() const noexcept;
    void reserve(size_type n);
    void shrink_to_fit() noexcept;

    reference       operator[](size_type n);
    const_reference operator[](size_type n) const;
    reference       at(size_type n);
    const_reference at(size_type n) const;

    reference       front();
    const_reference front() const;
    reference       back();
    const_reference back() const;

    value_type*       data() noexcept;
    const value_type* data() const noexcept;

    void push_back(const value_type& x);
    void push_back(value_type&& x);
    template <class... Args>
        reference emplace_back(Args&&... args); // reference in C++17
    template<container-compatible-range<T> R>
      constexpr void append_range(R&& rg); // C++23
    void pop_back();

    template <class... Args> iterator emplace(const_iterator position, Args&&... args);
    iterator insert(const_iterator position, const value_type& x);
    iterator insert(const_iterator position, value_type&& x);
    iterator insert(const_iterator position, size_type n, const value_type& x);
    template <class InputIterator>
        iterator insert(const_iterator position, InputIterator first, InputIterator last);
    template<container-compatible-range<T> R>
      constexpr iterator insert_range(const_iterator position, R&& rg); // C++23
    iterator insert(const_iterator position, initializer_list<value_type> il);

    iterator erase(const_iterator position);
    iterator erase(const_iterator first, const_iterator last);

    void clear() noexcept;

    void resize(size_type sz);
    void resize(size_type sz, const value_type& c);

    void swap(vector&)
        noexcept(allocator_traits<allocator_type>::propagate_on_container_swap::value ||
                 allocator_traits<allocator_type>::is_always_equal::value);  // C++17

    bool __invariants() const;
};

template <class Allocator = allocator<T> >
class vector<bool, Allocator>
{
public:
    typedef bool                                     value_type;
    typedef Allocator                                allocator_type;
    typedef implementation-defined                   iterator;
    typedef implementation-defined                   const_iterator;
    typedef typename allocator_type::size_type       size_type;
    typedef typename allocator_type::difference_type difference_type;
    typedef iterator                                 pointer;
    typedef const_iterator                           const_pointer;
    typedef std::reverse_iterator<iterator>          reverse_iterator;
    typedef std::reverse_iterator<const_iterator>    const_reverse_iterator;

    class reference
    {
    public:
        reference(const reference&) noexcept;
        operator bool() const noexcept;
        reference& operator=(bool x) noexcept;
        reference& operator=(const reference& x) noexcept;
        iterator operator&() const noexcept;
        void flip() noexcept;
    };

    class const_reference
    {
    public:
        const_reference(const reference&) noexcept;
        operator bool() const noexcept;
        const_iterator operator&() const noexcept;
    };

    vector()
        noexcept(is_nothrow_default_constructible<allocator_type>::value);
    explicit vector(const allocator_type&) noexcept;
    explicit vector(size_type n, const allocator_type& a = allocator_type()); // C++14
    vector(size_type n, const value_type& value, const allocator_type& = allocator_type());
    template <class InputIterator>
        vector(InputIterator first, InputIterator last, const allocator_type& = allocator_type());
    template<container-compatible-range<bool> R>
      constexpr vector(from_range_t, R&& rg, const Allocator& = Allocator());
    vector(const vector& x);
    vector(vector&& x) noexcept;
    vector(initializer_list<value_type> il);
    vector(initializer_list<value_type> il, const allocator_type& a);
    ~vector();
    vector& operator=(const vector& x);
    vector& operator=(vector&& x)
        noexcept(
             allocator_type::propagate_on_container_move_assignment::value ||
             allocator_type::is_always_equal::value); // C++17
    vector& operator=(initializer_list<value_type> il);
    template <class InputIterator>
        void assign(InputIterator first, InputIterator last);
    template<container-compatible-range<T> R>
      constexpr void assign_range(R&& rg); // C++23
    void assign(size_type n, const value_type& u);
    void assign(initializer_list<value_type> il);

    allocator_type get_allocator() const noexcept;

    iterator               begin() noexcept;
    const_iterator         begin()   const noexcept;
    iterator               end() noexcept;
    const_iterator         end()     const noexcept;

    reverse_iterator       rbegin() noexcept;
    const_reverse_iterator rbegin()  const noexcept;
    reverse_iterator       rend() noexcept;
    const_reverse_iterator rend()    const noexcept;

    const_iterator         cbegin()  const noexcept;
    const_iterator         cend()    const noexcept;
    const_reverse_iterator crbegin() const noexcept;
    const_reverse_iterator crend()   const noexcept;

    size_type size() const noexcept;
    size_type max_size() const noexcept;
    size_type capacity() const noexcept;
    bool empty() const noexcept;
    void reserve(size_type n);
    void shrink_to_fit() noexcept;

    reference       operator[](size_type n);
    const_reference operator[](size_type n) const;
    reference       at(size_type n);
    const_reference at(size_type n) const;

    reference       front();
    const_reference front() const;
    reference       back();
    const_reference back() const;

    void push_back(const value_type& x);
    template <class... Args> reference emplace_back(Args&&... args);  // C++14; reference in C++17
    template<container-compatible-range<T> R>
      constexpr void append_range(R&& rg); // C++23
    void pop_back();

    template <class... Args> iterator emplace(const_iterator position, Args&&... args);  // C++14
    iterator insert(const_iterator position, const value_type& x);
    iterator insert(const_iterator position, size_type n, const value_type& x);
    template <class InputIterator>
        iterator insert(const_iterator position, InputIterator first, InputIterator last);
    template<container-compatible-range<T> R>
      constexpr iterator insert_range(const_iterator position, R&& rg); // C++23
    iterator insert(const_iterator position, initializer_list<value_type> il);

    iterator erase(const_iterator position);
    iterator erase(const_iterator first, const_iterator last);

    void clear() noexcept;

    void resize(size_type sz);
    void resize(size_type sz, value_type x);

    void swap(vector&)
        noexcept(allocator_traits<allocator_type>::propagate_on_container_swap::value ||
                 allocator_traits<allocator_type>::is_always_equal::value);  // C++17
    void flip() noexcept;

    bool __invariants() const;
};

template <class InputIterator, class Allocator = allocator<typename iterator_traits<InputIterator>::value_type>>
   vector(InputIterator, InputIterator, Allocator = Allocator())
   -> vector<typename iterator_traits<InputIterator>::value_type, Allocator>; // C++17

template<ranges::input_range R, class Allocator = allocator<ranges::range_value_t<R>>>
  vector(from_range_t, R&&, Allocator = Allocator())
    -> vector<ranges::range_value_t<R>, Allocator>; // C++23

template <class Allocator> struct hash<std::vector<bool, Allocator>>;

template <class T, class Allocator> bool operator==(const vector<T,Allocator>& x, const vector<T,Allocator>& y);   // constexpr since C++20
template <class T, class Allocator> bool operator!=(const vector<T,Allocator>& x, const vector<T,Allocator>& y);   // removed in C++20
template <class T, class Allocator> bool operator< (const vector<T,Allocator>& x, const vector<T,Allocator>& y);   // removed in C++20
template <class T, class Allocator> bool operator> (const vector<T,Allocator>& x, const vector<T,Allocator>& y);   // removed in C++20
template <class T, class Allocator> bool operator>=(const vector<T,Allocator>& x, const vector<T,Allocator>& y);   // removed in C++20
template <class T, class Allocator> bool operator<=(const vector<T,Allocator>& x, const vector<T,Allocator>& y);   // removed in C++20
template <class T, class Allocator> constexpr
  constexpr synth-three-way-result<T> operator<=>(const vector<T, Allocator>& x,
                                                  const vector<T, Allocator>& y);                                  // since C++20

template <class T, class Allocator>
void swap(vector<T,Allocator>& x, vector<T,Allocator>& y)
    noexcept(noexcept(x.swap(y)));

template <class T, class Allocator, class U>
typename vector<T, Allocator>::size_type
erase(vector<T, Allocator>& c, const U& value);       // since C++20
template <class T, class Allocator, class Predicate>
typename vector<T, Allocator>::size_type
erase_if(vector<T, Allocator>& c, Predicate pred);    // since C++20


template<class T>
 inline constexpr bool is-vector-bool-reference = see below;        // exposition only, since C++23

template<class T, class charT> requires is-vector-bool-reference<T> // Since C++23
 struct formatter<T, charT>;

}  // std

*/

// clang-format on

#if __cplusplus < 201103L && defined(_LIBCPP_USE_FROZEN_CXX03_HEADERS)
#  include <__cxx03/vector>
#else
#  include <__config>

#  include <__vector/comparison.h>
#  include <__vector/swap.h>
#  include <__vector/vector.h>
#  include <__vector/vector_bool.h>

#  if _LIBCPP_STD_VER >= 17
#    include <__vector/pmr.h>
#  endif

#  if _LIBCPP_STD_VER >= 20
#    include <__vector/erase.h>
#  endif

#  if _LIBCPP_STD_VER >= 23
#    include <__vector/vector_bool_formatter.h>
#  endif

#  include <version>

// standard-mandated includes

// [iterator.range]
#  include <__iterator/access.h>
#  include <__iterator/data.h>
#  include <__iterator/empty.h>
#  include <__iterator/reverse_access.h>
#  include <__iterator/size.h>

// [vector.syn]
#  include <compare>
#  include <initializer_list>

// [vector.syn], [unord.hash]
#  include <__functional/hash.h>

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

#  if !defined(_LIBCPP_REMOVE_TRANSITIVE_INCLUDES) && _LIBCPP_STD_VER <= 20
#    include <algorithm>
#    include <array>
#    include <atomic>
#    include <cctype>
#    include <cerrno>
#    include <clocale>
#    include <concepts>
#    include <cstdint>
#    include <cstdlib>
#    include <iosfwd>
#    if _LIBCPP_HAS_LOCALIZATION
#      include <locale>
#    endif
#    include <optional>
#    include <string>
#    include <string_view>
#    include <tuple>
#    include <type_traits>
#    include <typeinfo>
#    include <utility>
#  endif
#endif // __cplusplus < 201103L && defined(_LIBCPP_USE_FROZEN_CXX03_HEADERS)

#endif // _LIBCPP_VECTOR
