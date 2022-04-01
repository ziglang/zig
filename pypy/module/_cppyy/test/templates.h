#ifndef CPPYY_TEST_TEMPLATES_H
#define CPPYY_TEST_TEMPLATES_H

#include <stdexcept>
#include <string>
#include <sstream>
#include <vector>

#if defined(_MSC_VER)
        #define INLINE __inline
#elif defined(__GNUC__)
    #if defined(__STRICT_ANSI__)
         #define INLINE __inline__
    #else
         #define INLINE inline
    #endif
#else
    #define INLINE
#endif

#ifndef __MSC_VER
#include <cxxabi.h>
INLINE std::string demangle_it(const char* name, const char* errmsg) {
    int status;
    std::string res = abi::__cxa_demangle(name, 0, 0, &status);
    if (status != 0) throw std::runtime_error(errmsg);
    return res;
}
#else
INLINE std::string demangle_it(const char* name, const char*) {
    return name;        // typeinfo's name() is already demangled
}
#endif


//===========================================================================
class MyTemplatedMethodClass {         // template methods
public:
    template<class A> long get_size(A&);
    template<class A> long get_size(const A&);

    long get_size();
    template<class B> long get_size();

    long get_char_size();
    long get_int_size();
    long get_long_size();
    long get_float_size();
    long get_double_size();

    long get_self_size();

private:
    double m_data[3];
};

template<class A>
long MyTemplatedMethodClass::get_size(A&) {
    return sizeof(A);
}

template<class A>
long MyTemplatedMethodClass::get_size(const A&) {
    return sizeof(A)+1;
}

template<class B>
INLINE long MyTemplatedMethodClass::get_size() {
    return sizeof(B);
}

// 
typedef MyTemplatedMethodClass MyTMCTypedef_t;

// explicit instantiation
template long MyTemplatedMethodClass::get_size<char>();
template long MyTemplatedMethodClass::get_size<int>();

// "lying" specialization
template<>
INLINE long MyTemplatedMethodClass::get_size<long>() {
    return 42;
}


//===========================================================================
// global templated functions
template<typename T>
long global_get_size() {
    return sizeof(T);
}

template <typename T>
int global_some_foo(T) {
    return 42;
}

template <typename T>
int global_some_bar(T) {
    return 13;
}

template <typename F>
struct SomeResult {
    F m_retval;
};

template <class I, typename O = float>
SomeResult<O> global_get_some_result(const I& carrier) {
    SomeResult<O> r{};
    r.m_retval = O(carrier[0]);
    return r;
}


//===========================================================================
// variadic functions
INLINE bool isSomeInt(int) { return true; }
INLINE bool isSomeInt(double) { return false; }
template <typename ...Args>
INLINE bool isSomeInt(Args...) { return false; }

namespace AttrTesting {

struct Obj1 { int var1; };
struct Obj2 { int var2; };

template <typename T>
constexpr auto has_var1(T t) -> decltype(t.var1, true) { return true; }

template <typename ...Args>
constexpr bool has_var1(Args...) { return false; }

template <typename T>
constexpr bool call_has_var1(T&& t) { return AttrTesting::has_var1(std::forward<T>(t)); }

template <int N, typename... T>
struct select_template_arg {};

template <typename T0, typename... T>
struct select_template_arg<0, T0, T...> {
    typedef T0 type;
};

template <int N, typename T0, typename... T>
struct select_template_arg<N, T0, T...> {
    typedef typename select_template_arg<N-1, T...>::type argument;
};

} // AttrTesting


namespace SomeNS {

template <typename T>
int some_foo(T) {
    return 42;
}

template <int T>
int some_bar() {
    return T;
}

INLINE std::string tuplify(std::ostringstream& out) {
    out << "NULL)";
    return out.str();
}

template<typename T, typename... Args>
std::string tuplify(std::ostringstream& out, T value, Args... args)
{
    out << value << ", ";
    return tuplify(out, args...);
}

} // namespace SomeNS


//===========================================================================
// using of static data
// TODO: this should live here instead of in test_templates.test08
/*
template <typename T> struct BaseClassWithStatic {
    static T const ref_value;
};

template <typename T>
T const BaseClassWithStatic<T>::ref_value = 42;

template <typename T>
struct DerivedClassUsingStatic : public BaseClassWithStatic<T> {
    using BaseClassWithStatic<T>::ref_value;

    explicit DerivedClassUsingStatic(T x) : BaseClassWithStatic<T>() {
        m_value = x > ref_value ? ref_value : x;
    }

    T m_value;
};
*/


//===========================================================================
// templated callable
class TemplatedCallable {
public:
    template <class I , class O = double>
    O operator() (const I& in) const { return O(in); }
};


//===========================================================================
// templated typedefs
namespace TemplatedTypedefs {

template<typename TYPE_IN, typename TYPE_OUT, size_t _vsize = 4>
struct BaseWithEnumAndTypedefs {
    enum { vsize = _vsize };
    typedef TYPE_IN in_type;
    typedef TYPE_OUT out_type;
};

template <typename TYPE_IN, typename TYPE_OUT, size_t _vsize = 4>
struct DerivedWithUsing : public BaseWithEnumAndTypedefs<TYPE_IN, TYPE_OUT, _vsize>
{
    typedef BaseWithEnumAndTypedefs<TYPE_IN, TYPE_OUT, _vsize> base_type;
    using base_type::vsize;
    using typename base_type::in_type;
    typedef typename base_type::in_type in_type_tt;
    using typename base_type::out_type;
};

struct SomeDummy {};

} // namespace TemplatedTypedefs


//===========================================================================
// hiding templated methods
namespace TemplateHiding {

struct Base {
    template<class T>
    int callme(T t = T(1)) { return 2*t; }
};

struct Derived : public Base {
    int callme(int t = 2) { return t; }
};

} // namespace TemplateHiding


//===========================================================================
// 'using' of templates
template<typename T> using DA_vector = std::vector<T>;

#if __cplusplus > 201402L
namespace using_problem {

template <typename T, size_t SZ>
struct vector {
    vector() : m_val(SZ) {}
    T m_val;
};

template <typename T, size_t ... sizes>
struct matryoshka {
    typedef T type;
};

template <typename T, size_t SZ, size_t ... sizes>
struct matryoshka<T, SZ, sizes ... > {
    typedef vector<typename matryoshka<T, sizes ...>::type, SZ> type;
};

template <typename T, size_t ... sizes>
using make_vector = typename matryoshka<T, sizes ...>::type;
    typedef make_vector<int, 2, 3> iiv_t;
};
#endif

namespace using_problem {

template<typename T>
class Base {
public:
    template<typename R>
    R get1(T t) { return t + R{5}; }
    T get2() { return T{5}; }
    template<typename R>
    R get3(T t) { return t + R{5}; }
    T get3() { return T{5}; }
};

template<typename T>
class Derived : public Base<T> {
public:
    typedef Base<T> _Mybase;
    using _Mybase::get1;
    using _Mybase::get2;
    using _Mybase::get3;
};

} // namespace using_problem


//===========================================================================
// template with r-value
namespace T_WithRValue {

template<typename T>
bool is_valid(T&& new_value) {
    return new_value != T{};
}

} // namespace T_WithRValue


//===========================================================================
// variadic templates
namespace some_variadic {

#ifdef _WIN32
#ifdef __CLING__
extern __declspec(dllimport) std::string gTypeName;
#else
extern __declspec(dllexport) std::string gTypeName;
#endif
#else
extern std::string gTypeName;
#endif

template <typename ... Args>
class A {
public:
    A() {
        gTypeName = demangle_it(typeid(A<Args...>).name(), "A::A");
    }
    A(const A&) = default;
    A(A&&) = default;
    A& operator=(const A&) = default;
    A& operator=(A&&) = default;

    template <typename ... FArgs>
    void a(FArgs&&... args) {
        gTypeName = demangle_it(typeid(&A<Args...>::a<FArgs...>).name(), "A::a-2");
    }

    template <typename T, typename ... FArgs>
    T a_T(FArgs&&... args) {
        gTypeName = demangle_it(typeid(&A<Args...>::a_T<T, FArgs...>).name(), "A::a_T-2");
        return T{};
    }

    template <typename ... FArgs>
    static void sa(FArgs&&... args) {
        gTypeName = demangle_it(typeid(A<Args...>).name(), "A::sa-1");
        gTypeName += "::";
        gTypeName += demangle_it(typeid(A<Args...>::sa<FArgs...>).name(), "A::sa-2");
    }

    template <typename T, typename ... FArgs>
    static T sa_T(FArgs&&... args) {
        gTypeName = demangle_it(typeid(A<Args...>).name(), "A::sa_T-1");
        gTypeName +=  "::";
        gTypeName += demangle_it(typeid(A<Args...>::sa_T<T, FArgs...>).name(), "A::sa_T-2");
        return T{};
    }
};

class B {
public:
    B() {
        gTypeName = demangle_it(typeid(B).name(), "B::B");
    }
    B(const B&) = default;
    B(B&&) = default;
    B& operator=(const B&) = default;
    B& operator=(B&&) = default;

    template <typename ... FArgs>
    void b(FArgs&&... args) {
        gTypeName = demangle_it(typeid(&B::b<FArgs...>).name(), "B::b-2");
    }

    template <typename T, typename ... FArgs>
    T b_T(FArgs&&... args) {
        gTypeName = demangle_it(typeid(&B::b_T<T, FArgs...>).name(), "B::b_T-2");
        return T{};
    }

    template <typename ... FArgs>
    static void sb(FArgs&&... args) {
        gTypeName = demangle_it(typeid(B).name(), "B::sb-1");
        gTypeName += "::";
        gTypeName +=  demangle_it(typeid(B::sb<FArgs...>).name(), "B::sb-2");
    }

    template <typename T, typename ... FArgs>
    static T sb_T(FArgs&&... args) {
        gTypeName = demangle_it(typeid(B).name(), "B::sb_T-1");
        gTypeName += "::";
        gTypeName += demangle_it(typeid(B::sb_T<T, FArgs...>).name(), "B::sb_T-2");
        return T{};
    }
};

template <typename ... Args>
void fn(Args&&... args) {
    gTypeName = demangle_it(typeid(fn<Args...>).name(), "fn");
}

template <typename T, typename ... Args>
T fn_T(Args&&... args) {
    gTypeName = demangle_it(typeid(fn<Args...>).name(), "fn_T");
    return T{};
}

} // namespace some_variadic


//===========================================================================
// template with empty body
namespace T_WithEmptyBody {

#ifdef _WIN32
#ifdef __CLING__
extern __declspec(dllimport) std::string side_effect;
#else
extern __declspec(dllexport) std::string side_effect;
#endif
#else
extern std::string side_effect;
#endif

template<typename T>
void some_empty();

} // namespace T_WithEmptyBody


//===========================================================================
// template with catch-all (void*, void**)overloads
namespace T_WithGreedyOverloads {

class SomeClass {
    double fD;
};

class WithGreedy1 {
public:
    template<class T>
    int get_size(T*) { return (int)sizeof(T); }
    int get_size(void*, bool force=false) { return -1; }
};

class WithGreedy2 {
public:
    template<class T>
    int get_size(T*) { return (int)sizeof(T); }
    int get_size(void**, bool force=false) { return -1; }
};

class DoesNotExist;

class WithGreedy3 {
public:
    template<class T>
    int get_size(T*) { return (int)sizeof(T); }
    int get_size(DoesNotExist*, bool force=false) { return -1; }
};

} // namespace T_WithGreedyOverloads


//===========================================================================
// template with overloaded non-templated and templated setitem
namespace TemplateWithSetItem {

template <typename T>
class MyVec {
private:
   std::vector<T> fData;

public:
   using size_type = typename std::vector<T>::size_type;

   MyVec(size_type count) : fData(count) {}

   T & operator[](size_type index) { return fData[index]; }

   // The definition of this templated operator causes the issue
   template <typename V>
   MyVec operator[](const MyVec<V> &conds) const { return MyVec(2); }
};

} // namespace TemplateWithSetItem


//===========================================================================
// type reduction examples on gmpxx-like template expressions
namespace TypeReduction {

template <typename T>
struct BinaryExpr;

template <typename T>
struct Expr {
    Expr() {}
    Expr(const BinaryExpr<T>&) {}
};

template <typename T>
struct BinaryExpr {
    BinaryExpr(const Expr<T>&, const Expr<T>&) {}
};

template<typename T>
BinaryExpr<T> operator+(const Expr<T>& e1, const Expr<T>& e2) {
    return BinaryExpr<T>(e1, e2);
}

} // namespace TypeReduction


//===========================================================================
// type deduction examples
namespace FailedTypeDeducer {

template<class T>
class B {
public:
    auto result() { return 5.; }
};

extern template class B<int>;

}

#endif // !CPPYY_TEST_TEMPLATES_H
