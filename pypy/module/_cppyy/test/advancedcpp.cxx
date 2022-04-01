#include "advancedcpp.h"

#include <stdexcept>


// for testing of default arguments
#define IMPLEMENT_DEFAULTERS(type, tname)                                    \
tname##_defaulter::tname##_defaulter(type a, type b, type c) {               \
    m_a = a; m_b = b; m_c = c;                                               \
}                                                                            \
type tname##_defaulter_func(int idx, type a, type b, type c) {               \
    if (idx == 0) return a;                                                  \
    if (idx == 1) return b;                                                  \
    if (idx == 2) return c;                                                  \
    return (type)idx;                                                        \
}
IMPLEMENT_DEFAULTERS(short, short)
IMPLEMENT_DEFAULTERS(unsigned short, ushort)
IMPLEMENT_DEFAULTERS(int, int)
IMPLEMENT_DEFAULTERS(unsigned, uint)
IMPLEMENT_DEFAULTERS(long, long)
IMPLEMENT_DEFAULTERS(unsigned long, ulong)
IMPLEMENT_DEFAULTERS(long long, llong)
IMPLEMENT_DEFAULTERS(unsigned long long, ullong)
IMPLEMENT_DEFAULTERS(float, float)
IMPLEMENT_DEFAULTERS(double, double)

std::string string_defaulter_func(int idx, const std::string& name1, std::string name2) {
    if (idx == 0) return name1;
    if (idx == 1) return name2;
    return "mies";
}


// for esoteric inheritance testing
a_class* create_c1() { return new c_class_1; }
a_class* create_c2() { return new c_class_2; }

int get_a( a_class& a ) { return a.m_a; }
int get_b( b_class& b ) { return b.m_b; }
int get_c( c_class& c ) { return c.m_c; }
int get_d( d_class& d ) { return d.m_d; }


// for namespace testing
int a_ns::g_a                         = 11;
int a_ns::b_class::s_b                = 22;
int a_ns::b_class::c_class::s_c       = 33;
int a_ns::d_ns::g_d                   = 44;
int a_ns::d_ns::e_class::s_e          = 55;
int a_ns::d_ns::e_class::f_class::s_f = 66;

int a_ns::get_g_a() { return g_a; }
int a_ns::d_ns::get_g_d() { return g_d; }


// for template testing
template class T1<int>;
template class T2<T1<int> >;
template class T3<int, double>;
template class T3<T1<int>, T2<T1<int> > >;
template class a_ns::T4<int>;
template class a_ns::T4<a_ns::T4<T3<int, double> > >;


// helpers for checking pass-by-ref
void set_int_through_ref(int& i, int val)             { i = val; }
int pass_int_through_const_ref(const int& i)          { return i; }
void set_long_through_ref(long& l, long val)          { l = val; }
long pass_long_through_const_ref(const long& l)       { return l; }
void set_double_through_ref(double& d, double val)    { d = val; }
double pass_double_through_const_ref(const double& d) { return d; }


// for math conversions testing
bool operator==(const some_comparable& c1, const some_comparable& c2 )
{
   return &c1 != &c2;              // the opposite of a pointer comparison
}

bool operator!=( const some_comparable& c1, const some_comparable& c2 )
{
   return &c1 == &c2;              // the opposite of a pointer comparison
}


// a couple of globals for access testing
double my_global_double = 12.;
double my_global_array[500];
static double sd = 1234.;
double* my_global_ptr = &sd;
const char my_global_string2[] = "zus jet teun";
some_int_holder my_global_int_holders[5] = {
    some_int_holder(13), some_int_holder(42), some_int_holder(88),
    some_int_holder(-1), some_int_holder(17) };

// for life-line and identity testing
int some_class_with_data::some_data::s_num_data = 0;


// for testing multiple inheritance
multi1::~multi1() {}
multi2::~multi2() {}
multi::~multi() {}


// for testing calls to overloaded new
int new_overloader::s_instances = 0;

void* new_overloader::operator new(std::size_t size) {
    ++s_instances;
    return ::operator new(size);
}

void* new_overloader::operator new(std::size_t, void* p) throw() {
    // no ++s_instances, as no memory is allocated
    return p;
}

void new_overloader::operator delete(void* p, std::size_t) {
    if (p == 0) return;
    --s_instances;
    ::operator delete(p);
}


// overload order testing
int overload_one_way::gime() const { return 1; }
std::string overload_one_way::gime() { return "aap"; }

std::string overload_the_other_way::gime() { return "aap"; }
int overload_the_other_way::gime() const { return 1; }


// exception handling testing
void Thrower::throw_anything() {
    throw 1;
}

void Thrower::throw_exception() {
    throw std::runtime_error("C++ function failed");
}
