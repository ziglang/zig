#include "templates.h"


// template methods
long MyTemplatedMethodClass::get_size() { return -1; }

long MyTemplatedMethodClass::get_char_size()   { return (long)sizeof(char); }
long MyTemplatedMethodClass::get_int_size()    { return (long)sizeof(int); }
long MyTemplatedMethodClass::get_long_size()   { return (long)42; /* "lying" */ }
long MyTemplatedMethodClass::get_float_size()  { return (long)sizeof(float); }
long MyTemplatedMethodClass::get_double_size() { return (long)sizeof(double); }
long MyTemplatedMethodClass::get_self_size()   { return (long)sizeof(MyTemplatedMethodClass); }


// variadic templates
#ifdef WIN32
__declspec(dllexport)
#endif
std::string some_variadic::gTypeName = "";


// template with empty body
namespace T_WithEmptyBody {

#ifdef WIN32
__declspec(dllexport)
#endif
std::string side_effect = "not set";

template<typename T>
void some_empty() {
    side_effect = "side effect";
}

template void some_empty<int>();

} // namespace T_WithRValue


// The following is hidden from the Cling interpreter, but available to the
// linker; it allows for testing whether a function return is picked up from
// the compiled instantation or from the interpreter.

namespace FailedTypeDeducer {

template<class T>
class A {
public:
    T result() { return T{42}; }
};

template class A<int>;

template class B<int>;

} // namespace FailedTypeDeducer
