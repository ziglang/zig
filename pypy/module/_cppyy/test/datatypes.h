#ifndef CPPYY_TEST_DATATYPES_H
#define CPPYY_TEST_DATATYPES_H

#ifdef _WIN32
typedef __int64          Long64_t;
typedef unsigned __int64 ULong64_t;
#else
typedef long long          Long64_t;
typedef unsigned long long ULong64_t;
#endif
#include <cstddef>
#include <cstdint>
#include <complex>
#include <functional>
#include <memory>
#include <vector>
#include <wchar.h>
#include <sys/types.h>

const int N = 5;


//===========================================================================
struct CppyyTestPod {
   int    m_int;
   double m_double;
};


//===========================================================================
enum EFruit {kApple=78, kBanana=29, kCitrus=34};
extern std::vector<EFruit> vecFruits;


//===========================================================================
enum class NamedClassEnum { E1 = 42 };

namespace EnumSpace {
    enum E {E1 = 1, E2};
    class EnumClass {
    public:
        enum    {E1 = -1};
        enum EE {E2 = -1};
    };

    typedef enum { AA = 1, BB, CC, DD } letter_code;

    enum class NamedClassEnum { E1 = -42 };
}


//===========================================================================
class FourVector {
public:
    FourVector(double x, double y, double z, double t) :
        m_cc_called(false), m_x(x), m_y(y), m_z(z), m_t(t) {}
    FourVector(const FourVector& s) :
        m_cc_called(true), m_x(s.m_x), m_y(s.m_y), m_z(s.m_z), m_t(s.m_t) {}

    double operator[](int i) {
        if (i == 0) return m_x;
        if (i == 1) return m_y;
        if (i == 2) return m_z;
        if (i == 3) return m_t;
        return -1;
    }

    bool operator==(const FourVector& o) {
        return (m_x == o.m_x && m_y == o.m_y &&
                m_z == o.m_z && m_t == o.m_t);
    }

public:
    bool m_cc_called;

private:
    double m_x, m_y, m_z, m_t;
};


//===========================================================================
typedef std::complex<double> complex_t; // maps to Py_complex
typedef std::complex<int> icomplex_t;   // no equivalent

class CppyyTestData {
public:
    CppyyTestData();
    ~CppyyTestData();

// special cases
    enum EWhat { kNothing=6, kSomething=111, kLots=42 };

// helper
    void destroy_arrays();

// getters
    bool                 get_bool();
    char                 get_char();
    signed char          get_schar();
    unsigned char        get_uchar();
    wchar_t              get_wchar();
    char16_t             get_char16();
    char32_t             get_char32();
#if __cplusplus > 201402L
    std::byte            get_byte();
#endif
    int8_t               get_int8();
    uint8_t              get_uint8();
    short                get_short();
    unsigned short       get_ushort();
    int                  get_int();
    unsigned int         get_uint();
    long                 get_long();
    unsigned long        get_ulong();
    long long            get_llong();
    unsigned long long   get_ullong();
    Long64_t             get_long64();
    ULong64_t            get_ulong64();
    float                get_float();
    double               get_double();
    long double          get_ldouble();
    long double          get_ldouble_def(long double ld = 1);
    complex_t            get_complex();
    icomplex_t           get_icomplex();
    EWhat                get_enum();
    void*                get_voidp();

    bool*           get_bool_array();
    bool*           get_bool_array2();
    signed char*    get_schar_array();
    signed char*    get_schar_array2();
    unsigned char*  get_uchar_array();
    unsigned char*  get_uchar_array2();
#if __cplusplus > 201402L
    std::byte*      get_byte_array();
    std::byte*      get_byte_array2();
#endif
    short*          get_short_array();
    short*          get_short_array2();
    unsigned short* get_ushort_array();
    unsigned short* get_ushort_array2();
    int*            get_int_array();
    int*            get_int_array2();
    unsigned int*   get_uint_array();
    unsigned int*   get_uint_array2();
    long*           get_long_array();
    long*           get_long_array2();
    unsigned long*  get_ulong_array();
    unsigned long*  get_ulong_array2();

    float*      get_float_array();
    float*      get_float_array2();
    double*     get_double_array();
    double*     get_double_array2();
    complex_t*  get_complex_array();
    complex_t*  get_complex_array2();

    CppyyTestPod get_pod_val();                 // for m_pod
    CppyyTestPod* get_pod_val_ptr();
    CppyyTestPod& get_pod_val_ref();
    CppyyTestPod*& get_pod_ptrref();

    CppyyTestPod* get_pod_ptr();                // for m_ppod

// getters const-ref
    const bool&               get_bool_cr();
    const char&               get_char_cr();
    const signed char&        get_schar_cr();
    const unsigned char&      get_uchar_cr();
    const wchar_t&            get_wchar_cr();
    const char16_t&           get_char16_cr();
    const char32_t&           get_char32_cr();
#if __cplusplus > 201402L
    const std::byte&          get_byte_cr();
#endif
    const int8_t&             get_int8_cr();
    const uint8_t&            get_uint8_cr();
    const short&              get_short_cr();
    const unsigned short&     get_ushort_cr();
    const int&                get_int_cr();
    const unsigned int&       get_uint_cr();
    const long&               get_long_cr();
    const unsigned long&      get_ulong_cr();
    const long long&          get_llong_cr();
    const unsigned long long& get_ullong_cr();
    const Long64_t&           get_long64_cr();
    const ULong64_t&          get_ulong64_cr();
    const float&              get_float_cr();
    const double&             get_double_cr();
    const long double&        get_ldouble_cr();
    const complex_t&          get_complex_cr();
    const icomplex_t&         get_icomplex_cr();
    const EWhat&              get_enum_cr();

// getters ref
    bool&               get_bool_r();
    char&               get_char_r();
    signed char&        get_schar_r();
    unsigned char&      get_uchar_r();
    wchar_t&            get_wchar_r();
    char16_t&           get_char16_r();
    char32_t&           get_char32_r();
#if __cplusplus > 201402L
    std::byte&          get_byte_r();
#endif
    int8_t&             get_int8_r();
    uint8_t&            get_uint8_r();
    short&              get_short_r();
    unsigned short&     get_ushort_r();
    int&                get_int_r();
    unsigned int&       get_uint_r();
    long&               get_long_r();
    unsigned long&      get_ulong_r();
    long long&          get_llong_r();
    unsigned long long& get_ullong_r();
    Long64_t&           get_long64_r();
    ULong64_t&          get_ulong64_r();
    float&              get_float_r();
    double&             get_double_r();
    long double&        get_ldouble_r();
    complex_t&          get_complex_r();
    icomplex_t&         get_icomplex_r();
    EWhat&              get_enum_r();

// setters
    void set_bool(bool);
    void set_char(char);
    void set_schar(signed char);
    void set_uchar(unsigned char);
    void set_wchar(wchar_t);
    void set_char16(char16_t);
    void set_char32(char32_t);
#if __cplusplus > 201402L
    void set_byte(std::byte);
#endif
    void set_int8(int8_t);
    void set_uint8(uint8_t);
    void set_short(short);
    void set_ushort(unsigned short);
    void set_int(int);
    void set_uint(unsigned int);
    void set_long(long);
    void set_ulong(unsigned long);
    void set_llong(long long);
    void set_ullong(unsigned long long);
    void set_long64(Long64_t);
    void set_ulong64(ULong64_t);
    void set_float(float);
    void set_double(double);
    void set_ldouble(long double);
    void set_complex(complex_t);
    void set_icomplex(icomplex_t);
    void set_enum(EWhat);
    void set_voidp(void*);

    void set_pod_val(CppyyTestPod);             // for m_pod
    void set_pod_ptr_in(CppyyTestPod*);
    void set_pod_ptr_out(CppyyTestPod*);
    void set_pod_ref(const CppyyTestPod&);
    void set_pod_ptrptr_in(CppyyTestPod**);
    void set_pod_void_ptrptr_in(void**);
    void set_pod_ptrptr_out(CppyyTestPod**);
    void set_pod_void_ptrptr_out(void**);

    void set_pod_ptr(CppyyTestPod*);            // for m_ppod

// setters const-ref
    void set_bool_cr(const bool&);
    void set_char_cr(const char&);
    void set_schar_cr(const signed char&);
    void set_uchar_cr(const unsigned char&);
    void set_wchar_cr(const wchar_t&);
    void set_char16_cr(const char16_t&);
    void set_char32_cr(const char32_t&);
#if __cplusplus > 201402L
    void set_byte_cr(const std::byte&);
#endif
    void set_int8_cr(const int8_t&);
    void set_uint8_cr(const uint8_t&);
    void set_short_cr(const short&);
    void set_ushort_cr(const unsigned short&);
    void set_int_cr(const int&);
    void set_uint_cr(const unsigned int&);
    void set_long_cr(const long&);
    void set_ulong_cr(const unsigned long&);
    void set_llong_cr(const long long&);
    void set_ullong_cr(const unsigned long long&);
    void set_long64_cr(const Long64_t&);
    void set_ulong64_cr(const ULong64_t&);
    void set_float_cr(const float&);
    void set_double_cr(const double&);
    void set_ldouble_cr(const long double&);
    void set_complex_cr(const complex_t&);
    void set_icomplex_cr(const icomplex_t&);
    void set_enum_cr(const EWhat&);

// setters ref
    void set_bool_r(bool&);
    void set_char_r(char&);
    void set_wchar_r(wchar_t&);
    void set_char16_r(char16_t&);
    void set_char32_r(char32_t&);
    void set_schar_r(signed char&);
    void set_uchar_r(unsigned char&);
#if __cplusplus > 201402L
    void set_byte_r(std::byte&);
#endif
    void set_short_r(short&);
    void set_ushort_r(unsigned short&);
    void set_int_r(int&);
    void set_uint_r(unsigned int&);
    void set_long_r(long&);
    void set_ulong_r(unsigned long&);
    void set_llong_r(long long&);
    void set_ullong_r(unsigned long long&);
    void set_float_r(float&);
    void set_double_r(double&);
    void set_ldouble_r(long double&);

// setters ptr
    void set_bool_p(bool*);
    void set_char_p(char*);
    void set_wchar_p(wchar_t*);
    void set_char16_p(char16_t*);
    void set_char32_p(char32_t*);
    void set_schar_p(signed char*);
    void set_uchar_p(unsigned char*);
#if __cplusplus > 201402L
    void set_byte_p(std::byte*);
#endif
    void set_short_p(short*);
    void set_ushort_p(unsigned short*);
    void set_int_p(int*);
    void set_uint_p(unsigned int*);
    void set_long_p(long*);
    void set_ulong_p(unsigned long*);
    void set_llong_p(long long*);
    void set_ullong_p(unsigned long long*);
    void set_float_p(float*);
    void set_double_p(double*);
    void set_ldouble_p(long double*);

// setters ptrptr
    void set_bool_ppa(bool**);
    void set_char_ppa(char**);
    void set_wchar_ppa(wchar_t**);
    void set_char16_ppa(char16_t**);
    void set_char32_ppa(char32_t**);
    void set_schar_ppa(signed char**);
    void set_uchar_ppa(unsigned char**);
#if __cplusplus > 201402L
    void set_byte_ppa(std::byte**);
#endif
    void set_short_ppa(short**);
    void set_ushort_ppa(unsigned short**);
    void set_int_ppa(int**);
    void set_uint_ppa(unsigned int**);
    void set_long_ppa(long**);
    void set_ulong_ppa(unsigned long**);
    void set_llong_ppa(long long**);
    void set_ullong_ppa(unsigned long long**);
    void set_float_ppa(float**);
    void set_double_ppa(double**);
    void set_ldouble_ppa(long double**);

    intptr_t set_char_ppm(char**);
    intptr_t set_cchar_ppm(const char**);
    intptr_t set_wchar_ppm(wchar_t**);
    intptr_t set_char16_ppm(char16_t**);
    intptr_t set_char32_ppm(char32_t**);
    intptr_t set_cwchar_ppm(const wchar_t**);
    intptr_t set_cchar16_ppm(const char16_t**);
    intptr_t set_cchar32_ppm(const char32_t**);
    intptr_t set_void_ppm(void**);

    intptr_t freeit(void*);

// setters r-value
    void set_bool_rv(bool&&);
    void set_char_rv(char&&);
    void set_schar_rv(signed char&&);
    void set_uchar_rv(unsigned char&&);
    void set_wchar_rv(wchar_t&&);
    void set_char16_rv(char16_t&&);
    void set_char32_rv(char32_t&&);
#if __cplusplus > 201402L
    void set_byte_rv(std::byte&&);
#endif
    void set_int8_rv(int8_t&&);
    void set_uint8_rv(uint8_t&&);
    void set_short_rv(short&&);
    void set_ushort_rv(unsigned short&&);
    void set_int_rv(int&&);
    void set_uint_rv(unsigned int&&);
    void set_long_rv(long&&);
    void set_ulong_rv(unsigned long&&);
    void set_llong_rv(long long&&);
    void set_ullong_rv(unsigned long long&&);
    void set_long64_rv(Long64_t&&);
    void set_ulong64_rv(ULong64_t&&);
    void set_float_rv(float&&);
    void set_double_rv(double&&);
    void set_ldouble_rv(long double&&);
    void set_complex_rv(complex_t&&);
    void set_icomplex_rv(icomplex_t&&);
    void set_enum_rv(EWhat&&);

// passers
    unsigned char*  pass_array(unsigned char*);
    short*          pass_array(short*);
    unsigned short* pass_array(unsigned short*);
    int*            pass_array(int*);
    unsigned int*   pass_array(unsigned int*);
    long*           pass_array(long*);
    unsigned long*  pass_array(unsigned long*);
    float*          pass_array(float*);
    double*         pass_array(double*);
    complex_t*      pass_array(complex_t*);

    unsigned char*  pass_void_array_B(void* a) { return pass_array((unsigned char*)a); }
    short*          pass_void_array_h(void* a) { return pass_array((short*)a); }
    unsigned short* pass_void_array_H(void* a) { return pass_array((unsigned short*)a); }
    int*            pass_void_array_i(void* a) { return pass_array((int*)a); }
    unsigned int*   pass_void_array_I(void* a) { return pass_array((unsigned int*)a); }
    long*           pass_void_array_l(void* a) { return pass_array((long*)a); }
    unsigned long*  pass_void_array_L(void* a) { return pass_array((unsigned long*)a); }
    float*          pass_void_array_f(void* a) { return pass_array((float*)a); }
    double*         pass_void_array_d(void* a) { return pass_array((double*)a); }
    complex_t*      pass_void_array_Z(void* a) { return pass_array((complex_t*)a); }

// strings
    const char*     get_valid_string(const char* in);
    const char*     get_invalid_string();
    const wchar_t*  get_valid_wstring(const wchar_t* in);
    const wchar_t*  get_invalid_wstring();
    const char16_t* get_valid_string16(const char16_t* in);
    const char16_t* get_invalid_string16();
    const char32_t* get_valid_string32(const char32_t* in);
    const char32_t* get_invalid_string32();

public:
// basic types
    bool                 m_bool;
    char                 m_char;
    signed char          m_schar;
    unsigned char        m_uchar;
    wchar_t              m_wchar;
    char16_t             m_char16;
    char32_t             m_char32;
#if __cplusplus > 201402L
    std::byte            m_byte;
#endif
    int8_t               m_int8;
    uint8_t              m_uint8;
    short                m_short;
    unsigned short       m_ushort;
    int                  m_int;
    const int            m_const_int;   // special case: const testing
    unsigned int         m_uint;
    long                 m_long;
    unsigned long        m_ulong;
    long long            m_llong;
    unsigned long long   m_ullong;
    Long64_t             m_long64;
    ULong64_t            m_ulong64;
    float                m_float;
    double               m_double;
    long double          m_ldouble;
    complex_t            m_complex;
    icomplex_t           m_icomplex;
    EWhat                m_enum;
    void*                m_voidp;

// array types
    bool            m_bool_array[N];
    bool*           m_bool_array2;
    signed char     m_schar_array[N];
    signed char*    m_schar_array2;
    unsigned char   m_uchar_array[N];
    unsigned char*  m_uchar_array2;
#if __cplusplus > 201402L
    std::byte       m_byte_array[N];
    std::byte*      m_byte_array2;
#endif
    short           m_short_array[N];
    short*          m_short_array2;
    unsigned short  m_ushort_array[N];
    unsigned short* m_ushort_array2;
    int             m_int_array[N];
    int*            m_int_array2;
    unsigned int    m_uint_array[N];
    unsigned int*   m_uint_array2;
    long            m_long_array[N];
    long*           m_long_array2;
    unsigned long   m_ulong_array[N];
    unsigned long*  m_ulong_array2;

    float       m_float_array[N];
    float*      m_float_array2;
    double      m_double_array[N];
    double*     m_double_array2;
    complex_t   m_complex_array[N];
    complex_t*  m_complex_array2;
    icomplex_t  m_icomplex_array[N];
    icomplex_t* m_icomplex_array2;

// object types
    CppyyTestPod m_pod;
    CppyyTestPod* m_ppod;

public:
    static bool                    s_bool;
    static char                    s_char;
    static signed char             s_schar;
    static unsigned char           s_uchar;
    static wchar_t                 s_wchar;
    static char16_t                s_char16;
    static char32_t                s_char32;
#if __cplusplus > 201402L
    static std::byte               s_byte;
#endif
    static int8_t                  s_int8;
    static uint8_t                 s_uint8;
    static short                   s_short;
    static unsigned short          s_ushort;
    static int                     s_int;
    static unsigned int            s_uint;
    static long                    s_long;
    static unsigned long           s_ulong;
    static long long               s_llong;
    static unsigned long long      s_ullong;
    static Long64_t                s_long64;
    static ULong64_t               s_ulong64;
    static float                   s_float;
    static double                  s_double;
    static long double             s_ldouble;
    static complex_t               s_complex;
    static icomplex_t              s_icomplex;
    static EWhat                   s_enum;
    static void*                   s_voidp;
    static std::string             s_strv;
    static std::string*            s_strp;

private:
    bool m_owns_arrays;
};


//= global functions ========================================================
intptr_t get_pod_address(CppyyTestData& c);
intptr_t get_int_address(CppyyTestData& c);
intptr_t get_double_address(CppyyTestData& c);


//= global variables/pointers ===============================================
extern bool               g_bool;
extern char               g_char;
extern signed char        g_schar;
extern unsigned char      g_uchar;
extern wchar_t            g_wchar;
extern char16_t           g_char16;
extern char32_t           g_char32;
#if __cplusplus > 201402L
extern std::byte          g_byte;
#endif
extern int8_t             g_int8;
extern uint8_t            g_uint8;
extern short              g_short;
extern unsigned short     g_ushort;
extern int                g_int;
extern unsigned int       g_uint;
extern long               g_long;
extern unsigned long      g_ulong;
extern long long          g_llong;
extern unsigned long long g_ullong;
extern Long64_t           g_long64;
extern ULong64_t          g_ulong64;
extern float              g_float;
extern double             g_double;
extern long double        g_ldouble;
extern complex_t          g_complex;
extern icomplex_t         g_icomplex;
extern EFruit             g_enum;
extern void*              g_voidp;

static const bool               g_c_bool    = true;
static const char               g_c_char    = 'z';
static const signed char        g_c_schar   = 'y';
static const unsigned char      g_c_uchar   = 'x';
static const wchar_t            g_c_wchar   = L'U';
static const char16_t           g_c_char16  = u'\u6c34';
static const char32_t           g_c_char32  = U'\U0001f34c';
#if __cplusplus > 201402L
static const std::byte          g_c_byte    = (std::byte)'u';
#endif
static const int8_t             g_c_int8    =  -12;
static const uint8_t            g_c_uint8   =   12;
static const short              g_c_short   =  -99;
static const unsigned short     g_c_ushort  =   99u;
static const int                g_c_int     = -199;
static const unsigned int       g_c_uint    =  199u;
static const long               g_c_long    = -299;
static const unsigned long      g_c_ulong   =  299ul;
static const long long          g_c_llong   = -399ll;
static const unsigned long long g_c_ullong  =  399ull;
static const Long64_t           g_c_long64  = -499ll;
static const ULong64_t          g_c_ulong64 =  499ull;
static const float              g_c_float   = -599.f;
static const double             g_c_double  = -699.;
static const long double        g_c_ldouble = -799.l;
static const complex_t          g_c_complex = {1., 2.};
static const icomplex_t         g_c_icomplex = {3, 4};
static const EFruit             g_c_enum    = kApple;
static const void*              g_c_voidp   = nullptr;


//= global accessors ========================================================
void set_global_int(int i);
int get_global_int();

extern CppyyTestPod* g_pod;
bool is_global_pod(CppyyTestPod* t);
void set_global_pod(CppyyTestPod* t);
CppyyTestPod* get_global_pod();
CppyyTestPod* get_null_pod();

extern std::string g_some_global_string;
std::string get_some_global_string();
extern std::string g_some_global_string2;
std::string get_some_global_string2();

extern const char16_t* g_some_global_string16;
extern const char32_t* g_some_global_string32;

namespace SomeStaticDataNS {
    extern std::string s_some_static_string;
    std::string get_some_static_string();
    extern std::string s_some_static_string2;
    std::string get_some_static_string2();
}

struct StorableData {
    StorableData(double d) : fData(d) {}
    double fData;
};

extern StorableData gData;


//= special case of "byte" arrays ===========================================
int64_t sum_uc_data(unsigned char* data, int size);
#if __cplusplus > 201402L
int64_t sum_byte_data(std::byte* data, int size);
#endif


//= function pointer passing ================================================
int sum_of_int1(int i1, int i2);
int sum_of_int2(int i1, int i2);
extern int (*sum_of_int_ptr)(int, int);
int call_sum_of_int(int i1, int i2);

double sum_of_double(double d1, double d2);
double call_double_double(double (*d)(double, double), double d1, double d2);

struct sum_of_int_struct {
    int (*sum_of_int_ptr)(int, int);
};

//= callable passing ========================================================
int call_int_int(int (*)(int, int), int, int);
void call_void(void (*f)(int), int i);
int call_refi(void (*fcn)(int&));
int call_refl(void (*fcn)(long&));
int call_refd(void (*fcn)(double&));

class StoreCallable {
    double (*fF)(double, double);
public:
    StoreCallable(double (*)(double, double));
    void set_callable(double (*)(double, double));
    double operator()(double, double);
};


//= callable through std::function ==========================================
double call_double_double_sf(const std::function<double(double, double)>&, double d1, double d2);

int call_int_int_sf(const std::function<int(int, int)>&, int, int);
void call_void_sf(const std::function<void(int)>&, int i);
int call_refi_sf(const std::function<void(int&)>&);
int call_refl_sf(const std::function<void(long&)>&);
int call_refd_sf(const std::function<void(double&)>&);

class StoreCallable_sf {
    std::function<double(double, double)> fF;
public:
    StoreCallable_sf(const std::function<double(double, double)>&);
    void set_callable(const std::function<double(double, double)>&);
    double operator()(double, double);
};


//= array of struct variants ================================================
namespace ArrayOfStruct {

struct Foo {
    int fVal;
};

struct Bar1 {
    Bar1() : fArr(new Foo[2]) { fArr[0].fVal = 42; fArr[1].fVal = 13; }
    Bar1(const Bar1&) = delete;
    Bar1& operator=(const Bar1&) = delete;
    ~Bar1() { delete[] fArr; }
    Foo* fArr;
};

struct Bar2 {
    Bar2(int num_foo) : fArr(std::unique_ptr<Foo[]>{new Foo[num_foo]}) {
        for (int i = 0; i < num_foo; ++i) fArr[i].fVal = 2*i;
    }
    std::unique_ptr<Foo[]> fArr;
};

} // namespace ArrayOfStruct


//= array of C strings passing ==============================================
namespace ArrayOfCStrings {
    std::vector<std::string> takes_array_of_cstrings(const char* args[], int len);
}


//= aggregate testing ======================================================
namespace AggregateTest {

struct Aggregate1 {
   static int sInt;
};

struct Aggregate2 {
   static int sInt;
   int fInt = 42;
};

}

#endif // !CPPYY_TEST_DATATYPES_H
