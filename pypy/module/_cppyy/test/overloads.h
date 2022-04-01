#include <string>
#include <vector>

class a_overload {
public:
    a_overload();
    int i1, i2;
};

namespace ns_a_overload {
    class a_overload {
    public:
        a_overload();
        int i1, i2;
    };

    class b_overload {
    public:
        int f(const std::vector<int>* v);
    };
}

namespace ns_b_overload {
    class a_overload {
    public:
        a_overload();
        int i1, i2;
    };
}

class b_overload {
public:
    b_overload();
    int i1, i2;
};

class c_overload {
public:
    c_overload();
    int get_int(a_overload* a);
    int get_int(ns_a_overload::a_overload* a);
    int get_int(ns_b_overload::a_overload* a);
    int get_int(short* p);
    int get_int(b_overload* b);
    int get_int(int* p);
};

class d_overload {
public:
    d_overload();
//   int get_int(void* p) { return *(int*)p; }
    int get_int(int* p);
    int get_int(b_overload* b);
    int get_int(short* p);
    int get_int(ns_b_overload::a_overload* a);
    int get_int(ns_a_overload::a_overload* a);
    int get_int(a_overload* a);
};


class aa_ol {};
class bb_ol;
class cc_ol {};
class dd_ol;

class more_overloads {
public:
    more_overloads();
    std::string call(const aa_ol&);
    std::string call(const bb_ol&, void* n=0);
    std::string call(const cc_ol&);
    std::string call(const dd_ol&);

    std::string call_unknown(const dd_ol&);

    std::string call(double);
    std::string call(int);
    std::string call1(int);
    std::string call1(double);
};

class more_overloads2 {
public:
    more_overloads2();
    std::string call(const bb_ol&);
    std::string call(const bb_ol*);

    std::string call(const dd_ol*, int);
    std::string call(const dd_ol&, int);
};

template<typename T>
double calc_mean(long n, const T* a) {
    double sum = 0., sumw = 0.;
    const T* end = a+n;
    while (a != end) {
        sum += *a++;
        sumw += 1;
    }

    return sum/sumw;
}

double calc_mean(long n, const float* a);
double calc_mean(long n, const double* a);
double calc_mean(long n, const int* a);
double calc_mean(long n, const short* a);
double calc_mean(long n, const long* a);
