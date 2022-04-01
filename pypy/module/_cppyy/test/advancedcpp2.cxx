#include "advancedcpp2.h"


// for namespace testing
int a_ns::g_g                         =  77;
int a_ns::g_class::s_g                =  88;
int a_ns::g_class::h_class::s_h       =  99;
int a_ns::d_ns::g_i                   = 111;
int a_ns::d_ns::i_class::s_i          = 222;
int a_ns::d_ns::i_class::j_class::s_j = 333;

int a_ns::get_g_g() { return g_g; }
int a_ns::d_ns::get_g_i() { return g_i; }
