#include "overloads.h"


a_overload::a_overload() { i1 = 42; i2 = -1; }

ns_a_overload::a_overload::a_overload() { i1 = 88; i2 = -34; }
int ns_a_overload::b_overload::f(const std::vector<int>* v) { return (*v)[0]; }

ns_b_overload::a_overload::a_overload() { i1 = -33; i2 = 89; }

b_overload::b_overload() { i1 = -2; i2 = 13; }

c_overload::c_overload() {}
int c_overload::get_int(a_overload* a)                { return a->i1; }
int c_overload::get_int(ns_a_overload::a_overload* a) { return a->i1; }
int c_overload::get_int(ns_b_overload::a_overload* a) { return a->i1; }
int c_overload::get_int(short* p)                     { return *p; }
int c_overload::get_int(b_overload* b)                { return b->i2; }
int c_overload::get_int(int* p)                       { return *p; }

d_overload::d_overload() {}
int d_overload::get_int(int* p)                       { return *p; }
int d_overload::get_int(b_overload* b)                { return b->i2; }
int d_overload::get_int(short* p)                     { return *p; }
int d_overload::get_int(ns_b_overload::a_overload* a) { return a->i1; }
int d_overload::get_int(ns_a_overload::a_overload* a) { return a->i1; }
int d_overload::get_int(a_overload* a)                { return a->i1; }


more_overloads::more_overloads() {}
std::string more_overloads::call(const aa_ol&) { return "aa_ol"; }
std::string more_overloads::call(const bb_ol&, void* n) { n = 0; return "bb_ol"; }
std::string more_overloads::call(const cc_ol&) { return "cc_ol"; }
std::string more_overloads::call(const dd_ol&) { return "dd_ol"; }

std::string more_overloads::call_unknown(const dd_ol&) { return "dd_ol"; }

std::string more_overloads::call(double)  { return "double"; }
std::string more_overloads::call(int)     { return "int"; }
std::string more_overloads::call1(int)    { return "int"; }
std::string more_overloads::call1(double) { return "double"; }


more_overloads2::more_overloads2() {}
std::string more_overloads2::call(const bb_ol&) { return "bb_olref"; }
std::string more_overloads2::call(const bb_ol*) { return "bb_olptr"; }

std::string more_overloads2::call(const dd_ol*, int) { return "dd_olptr"; }
std::string more_overloads2::call(const dd_ol&, int) { return "dd_olref"; }


double calc_mean(long n, const float* a)     { return calc_mean<float>(n, a); }
double calc_mean(long n, const double* a)    { return calc_mean<double>(n, a); }
double calc_mean(long n, const int* a)       { return calc_mean<int>(n, a); }
double calc_mean(long n, const short* a)     { return calc_mean<short>(n, a); }
double calc_mean(long n, const long* a)      { return calc_mean<long>(n, a); }
