#include "capi.h"

// include all headers from datatype.cxx and example01.cxx here,
//  allowing those .cxx files to be placed in the "dummy" namespace
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <cwchar>

#include <complex>
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <sstream>
#include <utility>
#include <vector>

#include <sys/types.h>

#pragma GCC diagnostic ignored "-Winvalid-offsetof"

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


// union for argument passing
struct CPPYY_G__value {
  union {
    double d;
    long    i; /* used to be int */
    char ch;
    short sh;
    int in;
    float fl;
    unsigned char uch;
    unsigned short ush;
    unsigned int uin;
    unsigned long ulo;
    long long ll;
    unsigned long long ull;
    long double ld;
  } obj;
  long ref;
  int type;
};


// gInterpreter
namespace dummy {
    class TInterpreter {
    public:
        int ProcessLine(const char* line) {
            if (strcmp(line, "__cplusplus;") == 0)
                return 0;
            return -1;
        }
    };

    TInterpreter gInterpreter;
} // namespace dummy


// add example01.cxx code
int globalAddOneToInt(int a);

namespace dummy {
#include "example01.cxx"
#include "datatypes.cxx"
}

int globalAddOneToInt(int a) {
   return dummy::globalAddOneToInt(a);
}

/* pseudo-reflection data ------------------------------------------------- */
namespace {

typedef std::map<std::string, cppyy_scope_t>  Handles_t;
static Handles_t s_handles;

enum EMethodType { kNormal=0, kConstructor=1, kStatic=2 };

struct Cppyy_PseudoMethodInfo {
    Cppyy_PseudoMethodInfo(const std::string& name,
                           const std::vector<std::string>& argtypes,
                           const std::string& returntype,
                           EMethodType mtype = kNormal) :
        m_name(name), m_argtypes(argtypes), m_returntype(returntype), m_type(mtype) {}
    std::string m_name;
    std::vector<std::string> m_argtypes;
    std::vector<std::string> m_argdefaults;
    std::string m_returntype;
    EMethodType m_type;
};

struct Cppyy_PseudoDatambrInfo {
    Cppyy_PseudoDatambrInfo(const std::string& name,
                            const std::string& type,
                            ptrdiff_t offset, bool isstatic) :
        m_name(name), m_type(type), m_offset(offset), m_isstatic(isstatic) {}
    std::string m_name;
    std::string m_type;
    ptrdiff_t m_offset;
    bool m_isstatic;
};

struct Cppyy_PseudoClassInfo {
    Cppyy_PseudoClassInfo() {}
    Cppyy_PseudoClassInfo(const std::vector<Cppyy_PseudoMethodInfo*>& methods,
                          const std::vector<Cppyy_PseudoDatambrInfo>& data) :
        m_methods(methods), m_datambrs(data) {}
    std::vector<Cppyy_PseudoMethodInfo*> m_methods;
    std::vector<Cppyy_PseudoDatambrInfo> m_datambrs;
};

typedef std::map<cppyy_scope_t, Cppyy_PseudoClassInfo> Scopes_t;
static Scopes_t s_scopes;

static std::map<std::string, Cppyy_PseudoMethodInfo*> s_methods;
struct CleanPseudoMethods {
    ~CleanPseudoMethods() { for (auto& x : s_methods) delete x.second; }
} _clean;

int Pseudo_kNothing   = 6;
int Pseudo_kSomething = 111;
int Pseudo_kLots      = 42;

#define PUBLIC_CPPYY_DATA(dmname, dmtype)                                     \
    data.push_back(Cppyy_PseudoDatambrInfo("m_"#dmname, #dmtype,              \
        offsetof(dummy::CppyyTestData, m_##dmname), false));                  \
    /* <type> get_<type>() */                                                 \
    argtypes.clear();                                                         \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "get_"#dmname, argtypes, #dmtype));                  \
    s_methods["CppyyTestData::get_"#dmname] = methods.back();                 \
    /* <type>& get_<type>_r() */                                              \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "get_"#dmname"_r", argtypes, #dmtype"&"));           \
    s_methods["CppyyTestData::get_"#dmname"_r"] = methods.back();             \
    /* const <type>& get_<type>_cr() */                                       \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "get_"#dmname"_cr", argtypes, "const "#dmtype"&"));  \
    s_methods["CppyyTestData::get_"#dmname"_cr"] = methods.back();            \
    /* void set_<type>(<type>) */                                             \
    argtypes.push_back(#dmtype);                                              \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "set_"#dmname, argtypes, "void"));                   \
    s_methods["CppyyTestData::set_"#dmname] = methods.back();                 \
    argtypes.clear();                                                         \
    /* void set_<type>(const <type>&) */                                      \
    argtypes.push_back("const "#dmtype"&");                                   \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "set_"#dmname"_cr", argtypes, "void"));              \
    s_methods["CppyyTestData::set_"#dmname"_cr"] = methods.back()

#define PUBLIC_CPPYY_DATA2(dmname, dmtype)                                    \
    PUBLIC_CPPYY_DATA(dmname, dmtype);                                        \
    data.push_back(Cppyy_PseudoDatambrInfo("m_"#dmname"_array", #dmtype"[5]", \
        offsetof(dummy::CppyyTestData, m_##dmname##_array), false));          \
    data.push_back(Cppyy_PseudoDatambrInfo("m_"#dmname"_array2", #dmtype"*",  \
        offsetof(dummy::CppyyTestData, m_##dmname##_array2), false));         \
    argtypes.clear();                                                         \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "get_"#dmname"_array", argtypes, #dmtype"*"));       \
    s_methods["CppyyTestData::get_"#dmname"_array"] = methods.back();         \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "get_"#dmname"_array2", argtypes, #dmtype"*"));      \
    s_methods["CppyyTestData::get_"#dmname"_array2"] = methods.back()

#define PUBLIC_CPPYY_DATA3(dmname, dmtype, key)                               \
    PUBLIC_CPPYY_DATA2(dmname, dmtype);                                       \
    argtypes.push_back(#dmtype"*");                                           \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "pass_array", argtypes, #dmtype"*"));                \
    s_methods["CppyyTestData::pass_array_"#dmname] = methods.back();          \
    argtypes.clear(); argtypes.push_back("void*");                            \
    methods.push_back(new Cppyy_PseudoMethodInfo(                             \
                         "pass_void_array_"#key, argtypes, #dmtype"*"));      \
    s_methods["CppyyTestData::pass_void_array_"#key] = methods.back()

#define PUBLIC_CPPYY_STATIC_DATA(dmname, dmtype)                              \
    data.push_back(Cppyy_PseudoDatambrInfo("s_"#dmname, #dmtype,              \
        (ptrdiff_t)&dummy::CppyyTestData::s_##dmname, true))


struct Cppyy_InitPseudoReflectionInfo {
    Cppyy_InitPseudoReflectionInfo() {
        static cppyy_scope_t s_scope_id  = 0;

        { // namespace ''
        s_handles[""] = (cppyy_scope_t)++s_scope_id;

        std::vector<Cppyy_PseudoDatambrInfo> data;
        data.push_back(Cppyy_PseudoDatambrInfo("N", "int", (ptrdiff_t)&dummy::N, true));
        data.push_back(Cppyy_PseudoDatambrInfo(
            "gInterpreter", "TInterpreter", (ptrdiff_t)&dummy::gInterpreter, true));

        Cppyy_PseudoClassInfo info(std::vector<Cppyy_PseudoMethodInfo*>(), data);
        s_scopes[(cppyy_scope_t)s_scope_id] = info;
        }

        { // namespace std
        s_handles["std"] = (cppyy_scope_t)++s_scope_id;
        }

        { // class TInterpreter
        s_handles["TInterpreter"] = (cppyy_scope_t)++s_scope_id;

        std::vector<Cppyy_PseudoMethodInfo*> methods;

        std::vector<std::string> argtypes;
        argtypes.push_back("const char*");
        methods.push_back(new Cppyy_PseudoMethodInfo("ProcessLine", argtypes, "int"));
        s_methods["TInterpreter::ProcessLine_cchar*"] = methods.back();

        Cppyy_PseudoClassInfo info(methods, std::vector<Cppyy_PseudoDatambrInfo>());
        s_scopes[(cppyy_scope_t)s_scope_id] = info;
        }

        { // class example01 --
        s_handles["example01"] = (cppyy_scope_t)++s_scope_id;

        std::vector<Cppyy_PseudoMethodInfo*> methods;

        // static double staticAddToDouble(double a)
        std::vector<std::string> argtypes;
        argtypes.push_back("double");
        methods.push_back(new Cppyy_PseudoMethodInfo("staticAddToDouble", argtypes, "double", kStatic));
        s_methods["static_example01::staticAddToDouble_double"] = methods.back();

        // static int staticAddOneToInt(int a)
        // static int staticAddOneToInt(int a, int b)
        argtypes.clear();
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("staticAddOneToInt", argtypes, "int", kStatic));
        s_methods["static_example01::staticAddOneToInt_int"] = methods.back();
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("staticAddOneToInt", argtypes, "int", kStatic));
        s_methods["static_example01::staticAddOneToInt_int_int"] = methods.back();

        // static int staticAtoi(const char* str)
        argtypes.clear();
        argtypes.push_back("const char*");
        methods.push_back(new Cppyy_PseudoMethodInfo("staticAtoi", argtypes, "int", kStatic));
        s_methods["static_example01::staticAtoi_cchar*"] = methods.back();

        // static char* staticStrcpy(const char* strin)
        methods.push_back(new Cppyy_PseudoMethodInfo("staticStrcpy", argtypes, "char*", kStatic));
        s_methods["static_example01::staticStrcpy_cchar*"] = methods.back();

        // static void staticSetPayload(payload* p, double d)
        // static payload* staticCyclePayload(payload* p, double d)
        // static payload staticCopyCyclePayload(payload* p, double d)
        argtypes.clear();
        argtypes.push_back("payload*");
        argtypes.push_back("double");
        methods.push_back(new Cppyy_PseudoMethodInfo("staticSetPayload", argtypes, "void", kStatic));
        s_methods["static_example01::staticSetPayload_payload*_double"] = methods.back();
        methods.push_back(new Cppyy_PseudoMethodInfo("staticCyclePayload", argtypes, "payload*", kStatic));
        s_methods["static_example01::staticCyclePayload_payload*_double"] = methods.back();
        methods.push_back(new Cppyy_PseudoMethodInfo("staticCopyCyclePayload", argtypes, "payload", kStatic));
        s_methods["static_example01::staticCopyCyclePayload_payload*_double"] = methods.back();

        // static int getCount()
        // static void setCount(int)
        argtypes.clear();
        methods.push_back(new Cppyy_PseudoMethodInfo("getCount", argtypes, "int", kStatic));
        s_methods["static_example01::getCount"] = methods.back();
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("setCount", argtypes, "void", kStatic));
        s_methods["static_example01::setCount_int"] = methods.back();

        // example01()
        // example01(int a)
        argtypes.clear();
        methods.push_back(new Cppyy_PseudoMethodInfo("example01", argtypes, "constructor", kConstructor));
        s_methods["example01::example01"] = methods.back();
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("example01", argtypes, "constructor", kConstructor));
        s_methods["example01::example01_int"] = methods.back();

        // int addDataToInt(int a)
        argtypes.clear();
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("addDataToInt", argtypes, "int"));
        s_methods["example01::addDataToInt_int"] = methods.back();

        // int addDataToIntConstRef(const int& a)
        argtypes.clear();
        argtypes.push_back("const int&");
        methods.push_back(new Cppyy_PseudoMethodInfo("addDataToIntConstRef", argtypes, "int"));
        s_methods["example01::addDataToIntConstRef_cint&"] = methods.back();

        // int overloadedAddDataToInt(int a, int b)
        argtypes.clear();
        argtypes.push_back("int");
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("overloadedAddDataToInt", argtypes, "int"));
        s_methods["example01::overloadedAddDataToInt_int_int"] = methods.back();

        // int overloadedAddDataToInt(int a)
        // int overloadedAddDataToInt(int a, int b, int c)
        argtypes.clear();
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("overloadedAddDataToInt", argtypes, "int"));
        s_methods["example01::overloadedAddDataToInt_int"] = methods.back();
        argtypes.push_back("int");
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("overloadedAddDataToInt", argtypes, "int"));
        s_methods["example01::overloadedAddDataToInt_int_int_int"] = methods.back();

        // double addDataToDouble(double a)
        argtypes.clear();
        argtypes.push_back("double");
        methods.push_back(new Cppyy_PseudoMethodInfo("addDataToDouble", argtypes, "double"));
        s_methods["example01::addDataToDouble_double"] = methods.back();

        // int addDataToAtoi(const char* str)
        // char* addToStringValue(const char* str)
        argtypes.clear();
        argtypes.push_back("const char*");
        methods.push_back(new Cppyy_PseudoMethodInfo("addDataToAtoi", argtypes, "int"));
        s_methods["example01::addDataToAtoi_cchar*"] = methods.back();
        methods.push_back(new Cppyy_PseudoMethodInfo("addToStringValue", argtypes, "char*"));
        s_methods["example01::addToStringValue_cchar*"] = methods.back();

        // void setPayload(payload* p)
        // payload* cyclePayload(payload* p)
        // payload copyCyclePayload(payload* p)
        argtypes.clear();
        argtypes.push_back("payload*");
        methods.push_back(new Cppyy_PseudoMethodInfo("setPayload", argtypes, "void"));
        s_methods["example01::setPayload_payload*"] = methods.back();
        methods.push_back(new Cppyy_PseudoMethodInfo("cyclePayload", argtypes, "payload*"));
        s_methods["example01::cyclePayload_payload*"] = methods.back();
        methods.push_back(new Cppyy_PseudoMethodInfo("copyCyclePayload", argtypes, "payload"));
        s_methods["example01::copyCyclePayload_payload*"] = methods.back();

        Cppyy_PseudoClassInfo info(methods, std::vector<Cppyy_PseudoDatambrInfo>());
        s_scopes[(cppyy_scope_t)s_scope_id] = info;
        } // -- class example01

        //====================================================================

        { // class complex<double> --
        s_handles["complex_t"] = (cppyy_scope_t)++s_scope_id;
        s_handles["std::complex<double>"] = s_handles["complex_t"];

        std::vector<Cppyy_PseudoMethodInfo*> methods;

        std::vector<std::string> argtypes;

        // double real()
        argtypes.clear();
        methods.push_back(new Cppyy_PseudoMethodInfo("real", argtypes, "double"));
        s_methods["std::complex<double>::real"] = methods.back();

        // double imag()
        argtypes.clear();
        methods.push_back(new Cppyy_PseudoMethodInfo("imag", argtypes, "double"));
        s_methods["std::complex<double>::imag"] = methods.back();

        // complex<double>(double r, double i)
        argtypes.clear();
        argtypes.push_back("double");
        argtypes.push_back("double");
        methods.push_back(new Cppyy_PseudoMethodInfo("complex<double>", argtypes, "constructor", kConstructor));
        s_methods["std::complex<double>::complex<double>_double_double"] = methods.back();

        Cppyy_PseudoClassInfo info(methods, std::vector<Cppyy_PseudoDatambrInfo>());
        s_scopes[(cppyy_scope_t)s_scope_id] = info;
        }

        { // class complex<int> --
        s_handles["icomplex_t"] = (cppyy_scope_t)++s_scope_id;
        s_handles["std::complex<int>"] = s_handles["icomplex_t"];

        std::vector<Cppyy_PseudoMethodInfo*> methods;

        std::vector<std::string> argtypes;

        // int real()
        argtypes.clear();
        methods.push_back(new Cppyy_PseudoMethodInfo("real", argtypes, "int"));
        s_methods["std::complex<int>::real"] = methods.back();

        // int imag()
        argtypes.clear();
        methods.push_back(new Cppyy_PseudoMethodInfo("imag", argtypes, "int"));
        s_methods["std::complex<int>::imag"] = methods.back();

        // complex<int>(int r, int i)
        argtypes.clear();
        argtypes.push_back("int");
        argtypes.push_back("int");
        methods.push_back(new Cppyy_PseudoMethodInfo("complex<int>", argtypes, "constructor", kConstructor));
        s_methods["std::complex<int>::complex<int>_int_int"] = methods.back();

        Cppyy_PseudoClassInfo info(methods, std::vector<Cppyy_PseudoDatambrInfo>());
        s_scopes[(cppyy_scope_t)s_scope_id] = info;
        }

        { // class payload --
        s_handles["payload"] = (cppyy_scope_t)++s_scope_id;

        std::vector<Cppyy_PseudoMethodInfo*> methods;

        // payload(double d = 0.)
        std::vector<std::string> argtypes;
        argtypes.push_back("double");
        methods.push_back(new Cppyy_PseudoMethodInfo("payload", argtypes, "constructor", kConstructor));
        s_methods["payload::payload_double"] = methods.back();

        // double getData()
        argtypes.clear();
        methods.push_back(new Cppyy_PseudoMethodInfo("getData", argtypes, "double"));
        s_methods["payload::getData"] = methods.back();

        // void setData(double d)
        argtypes.clear();
        argtypes.push_back("double");
        methods.push_back(new Cppyy_PseudoMethodInfo("setData", argtypes, "void"));
        s_methods["payload::setData_double"] = methods.back();

        Cppyy_PseudoClassInfo info(methods, std::vector<Cppyy_PseudoDatambrInfo>());
        s_scopes[(cppyy_scope_t)s_scope_id] = info;
        } // -- class payload

        //====================================================================

        { // class CppyyTestData --
        s_handles["CppyyTestData"] = (cppyy_scope_t)++s_scope_id;

        std::vector<Cppyy_PseudoMethodInfo*> methods;

        // CppyyTestData()
        std::vector<std::string> argtypes;
        methods.push_back(new Cppyy_PseudoMethodInfo("CppyyTestData", argtypes, "constructor", kConstructor));
        s_methods["CppyyTestData::CppyyTestData"] = methods.back();

        methods.push_back(new Cppyy_PseudoMethodInfo("destroy_arrays", argtypes, "void"));
        s_methods["CppyyTestData::destroy_arrays"] = methods.back();

        std::vector<Cppyy_PseudoDatambrInfo> data;
        PUBLIC_CPPYY_DATA2(bool,          bool);
        PUBLIC_CPPYY_DATA (char,          char);
        PUBLIC_CPPYY_DATA2(schar,         signed char);
        PUBLIC_CPPYY_DATA2(uchar,         unsigned char);
        PUBLIC_CPPYY_DATA (wchar,         wchar_t);
        PUBLIC_CPPYY_DATA (char16,        char16_t);
        PUBLIC_CPPYY_DATA (char32,        char32_t);
        PUBLIC_CPPYY_DATA (int8,          int8_t);
        PUBLIC_CPPYY_DATA (uint8,         uint8_t);
        PUBLIC_CPPYY_DATA3(short,         short,              h);
        PUBLIC_CPPYY_DATA3(ushort,        unsigned short,     H);
        PUBLIC_CPPYY_DATA3(int,           int,                i);
        PUBLIC_CPPYY_DATA (const_int,     const int);
        PUBLIC_CPPYY_DATA3(uint,          unsigned int,       I);
        PUBLIC_CPPYY_DATA3(long,          long,               l);
        PUBLIC_CPPYY_DATA3(ulong,         unsigned long,      L);
        PUBLIC_CPPYY_DATA (llong,         long long);
        PUBLIC_CPPYY_DATA (ullong,        unsigned long long);
        PUBLIC_CPPYY_DATA (long64,        Long64_t);
        PUBLIC_CPPYY_DATA (ulong64,       ULong64_t);
        PUBLIC_CPPYY_DATA3(float,         float,              f);
        PUBLIC_CPPYY_DATA3(double,        double,             d);
        PUBLIC_CPPYY_DATA (ldouble,       long double);
        PUBLIC_CPPYY_DATA (complex,       complex_t);
        PUBLIC_CPPYY_DATA (icomplex,      icomplex_t);
        PUBLIC_CPPYY_DATA (enum,          CppyyTestData::EWhat);
        PUBLIC_CPPYY_DATA (voidp,         void*);

        PUBLIC_CPPYY_STATIC_DATA(char,    char);
        PUBLIC_CPPYY_STATIC_DATA(schar,   signed char);
        PUBLIC_CPPYY_STATIC_DATA(uchar,   unsigned char);
        PUBLIC_CPPYY_STATIC_DATA(wchar,   wchar_t);
        PUBLIC_CPPYY_STATIC_DATA(char16,  char16_t);
        PUBLIC_CPPYY_STATIC_DATA(char32,  char32_t);
        PUBLIC_CPPYY_STATIC_DATA(int8,    int8_t);
        PUBLIC_CPPYY_STATIC_DATA(uint8,   uint8_t);
        PUBLIC_CPPYY_STATIC_DATA(short,   short);
        PUBLIC_CPPYY_STATIC_DATA(ushort,  unsigned short);
        PUBLIC_CPPYY_STATIC_DATA(int,     int);
        PUBLIC_CPPYY_STATIC_DATA(uint,    unsigned int);
        PUBLIC_CPPYY_STATIC_DATA(long,    long);
        PUBLIC_CPPYY_STATIC_DATA(ulong,   unsigned long);
        PUBLIC_CPPYY_STATIC_DATA(llong,   long long);
        PUBLIC_CPPYY_STATIC_DATA(ullong,  unsigned long long);
        PUBLIC_CPPYY_STATIC_DATA(long64,  Long64_t);
        PUBLIC_CPPYY_STATIC_DATA(ulong64, ULong64_t);
        PUBLIC_CPPYY_STATIC_DATA(float,   float);
        PUBLIC_CPPYY_STATIC_DATA(double,  double);
        PUBLIC_CPPYY_STATIC_DATA(ldouble, long double);
        PUBLIC_CPPYY_STATIC_DATA(enum,    CppyyTestData::EWhat);
        PUBLIC_CPPYY_STATIC_DATA(voidp,   void*);

      // default tester for long double
        argtypes.clear();
        argtypes.push_back("long double");
        methods.push_back(new Cppyy_PseudoMethodInfo("get_ldouble_def", argtypes, "long double"));
        methods.back()->m_argdefaults.push_back("aap_t(1)");
        s_methods["CppyyTestData::get_ldouble_def"] = methods.back();

      // pretend enum values
        data.push_back(Cppyy_PseudoDatambrInfo(
            "kNothing", "CppyyTestData::EWhat", (ptrdiff_t)&Pseudo_kNothing, true));
        data.push_back(Cppyy_PseudoDatambrInfo(
            "kSomething", "CppyyTestData::EWhat", (ptrdiff_t)&Pseudo_kSomething, true));
        data.push_back(Cppyy_PseudoDatambrInfo(
            "kLots", "CppyyTestData::EWhat", (ptrdiff_t)&Pseudo_kLots, true));

        Cppyy_PseudoClassInfo info(methods, data);
        s_scopes[(cppyy_scope_t)s_scope_id] = info;
        } // -- class CppyyTest_data

        //====================================================================

        { // namespace pyzables --
        s_handles["pyzables"] = (cppyy_scope_t)++s_scope_id;
        s_scopes[(cppyy_scope_t)s_scope_id] = Cppyy_PseudoClassInfo{};
        s_handles["pyzables::SomeDummy1"] = (cppyy_scope_t)++s_scope_id;
        s_scopes[(cppyy_scope_t)s_scope_id] = Cppyy_PseudoClassInfo{};
        s_handles["pyzables::SomeDummy2"] = (cppyy_scope_t)++s_scope_id;
        s_scopes[(cppyy_scope_t)s_scope_id] = Cppyy_PseudoClassInfo{};
        } // -- namespace pyzables
    }
} _init;

} // unnamed namespace


/* local helpers ---------------------------------------------------------- */
static INLINE char* cppstring_to_cstring(const std::string& name) {
    char* name_char = (char*)malloc(name.size() + 1);
    strcpy(name_char, name.c_str());
    return name_char;
}


/* name to opaque C++ scope representation -------------------------------- */
char* cppyy_resolve_name(const char* cppitem_name) {
    if (strcmp(cppitem_name, "complex_t") == 0)
        return cppstring_to_cstring("std::complex<double>");
    else if (strcmp(cppitem_name, "icomplex_t") == 0)
        return cppstring_to_cstring("std::complex<int>");
    else if (cppyy_is_enum(cppitem_name))
        return cppstring_to_cstring("internal_enum_type_t");
    else if (strcmp(cppitem_name, "aap_t") == 0)
        return cppstring_to_cstring("long double");
    return cppstring_to_cstring(cppitem_name);
}

cppyy_scope_t cppyy_get_scope(const char* scope_name) {
    return s_handles[scope_name];  // lookup failure will return 0 (== error)
}

cppyy_type_t cppyy_actual_class(cppyy_type_t klass, cppyy_object_t /* obj */) {
    return klass;
}


/* memory management ------------------------------------------------------ */
void cppyy_destruct(cppyy_type_t handle, cppyy_object_t self) {
    if (handle == s_handles["example01"])
       delete (dummy::example01*)self;
}


/* method/function dispatching -------------------------------------------- */
void cppyy_call_v(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["static_example01::staticSetPayload_payload*_double"]) {
        assert(!self && nargs == 2);
        dummy::example01::staticSetPayload((dummy::payload*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]),
           ((CPPYY_G__value*)args)[1].obj.d);
    } else if (idx == s_methods["static_example01::setCount_int"]) {
        assert(!self && nargs == 1);
        dummy::example01::setCount(((CPPYY_G__value*)args)[0].obj.in);
    } else if (idx == s_methods["example01::setPayload_payload*"]) {
        assert(self && nargs == 1);
        ((dummy::example01*)self)->setPayload((dummy::payload*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]));
    } else if (idx == s_methods["CppyyTestData::destroy_arrays"]) {
        assert(self && nargs == 0);
        ((dummy::CppyyTestData*)self)->destroy_arrays();
    } else if (idx == s_methods["CppyyTestData::set_bool"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_bool((bool)((CPPYY_G__value*)args)[0].obj.i);
    } else if (idx == s_methods["CppyyTestData::set_char"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_char(((CPPYY_G__value*)args)[0].obj.ch);
    } else if (idx == s_methods["CppyyTestData::set_uchar"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_uchar(((CPPYY_G__value*)args)[0].obj.uch);
    } else if (idx == s_methods["CppyyTestData::set_wchar"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_wchar(((CPPYY_G__value*)args)[0].obj.i);
    } else if (idx == s_methods["CppyyTestData::set_char16"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_char16(((CPPYY_G__value*)args)[0].obj.i);
    } else if (idx == s_methods["CppyyTestData::set_char32"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_char32(((CPPYY_G__value*)args)[0].obj.i);
    } else if (idx == s_methods["CppyyTestData::set_int8"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_int8(((CPPYY_G__value*)args)[0].obj.ch);
    } else if (idx == s_methods["CppyyTestData::set_int8_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_int8_cr(*(int8_t*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_uint8"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_uint8(((CPPYY_G__value*)args)[0].obj.ch);
    } else if (idx == s_methods["CppyyTestData::set_uint8_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_uint8_cr(*(uint8_t*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_short"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_short(((CPPYY_G__value*)args)[0].obj.sh);
    } else if (idx == s_methods["CppyyTestData::set_short_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_short_cr(*(short*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_ushort"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_ushort(((CPPYY_G__value*)args)[0].obj.ush);
    } else if (idx == s_methods["CppyyTestData::set_ushort_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_ushort_cr(*(unsigned short*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_int"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_int(((CPPYY_G__value*)args)[0].obj.in);
    } else if (idx == s_methods["CppyyTestData::set_int_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_int_cr(*(int*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_uint"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_uint(((CPPYY_G__value*)args)[0].obj.uin);
    } else if (idx == s_methods["CppyyTestData::set_uint_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_uint_cr(*(unsigned int*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_long"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_long(((CPPYY_G__value*)args)[0].obj.i);
    } else if (idx == s_methods["CppyyTestData::set_long_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_long_cr(*(long*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_ulong"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_ulong(((CPPYY_G__value*)args)[0].obj.ulo);
    } else if (idx == s_methods["CppyyTestData::set_ulong_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_ulong_cr(*(unsigned long*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_llong"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_llong(((CPPYY_G__value*)args)[0].obj.ll);
    } else if (idx == s_methods["CppyyTestData::set_llong_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_llong_cr(*(long long*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_ullong"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_ullong(((CPPYY_G__value*)args)[0].obj.ull);
    } else if (idx == s_methods["CppyyTestData::set_ullong_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_ullong_cr(*(unsigned long*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_float"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_float(((CPPYY_G__value*)args)[0].obj.fl);
    } else if (idx == s_methods["CppyyTestData::set_float_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_float_cr(*(float*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_double"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_double(((CPPYY_G__value*)args)[0].obj.d);
    } else if (idx == s_methods["CppyyTestData::set_double_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_double_cr(*(double*)&((CPPYY_G__value*)args)[0]);
    } else if (idx == s_methods["CppyyTestData::set_ldouble"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_ldouble(((CPPYY_G__value*)args)[0].obj.ld);
    } else if (idx == s_methods["CppyyTestData::set_ldouble_cr"]) {
        assert(self && nargs == 1);
        ((dummy::CppyyTestData*)self)->set_ldouble_cr(*(long double*)&((CPPYY_G__value*)args)[0]);
    } else {
        assert(!"method unknown in cppyy_call_v");
    }
}

unsigned char cppyy_call_b(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    unsigned char result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["CppyyTestData::get_bool"]) {
        assert(self && nargs == 0);
        result = (unsigned char)((dummy::CppyyTestData*)self)->get_bool();
    } else {
        assert(!"method unknown in cppyy_call_b");
    }
    return result;
}

char cppyy_call_c(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    char result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["CppyyTestData::get_char"]) {
        assert(self && nargs == 0);
        result = ((dummy::CppyyTestData*)self)->get_char();
    } else if (idx == s_methods["CppyyTestData::get_uchar"]) {
        assert(self && nargs == 0);
        result = (char)((dummy::CppyyTestData*)self)->get_uchar();
    } else if (idx == s_methods["CppyyTestData::get_int8"]) {
        assert(self && nargs == 0);
        result = (long)((dummy::CppyyTestData*)self)->get_int8();
    } else if (idx == s_methods["CppyyTestData::get_uint8"]) {
        assert(self && nargs == 0);
        result = (long)((dummy::CppyyTestData*)self)->get_uint8();
    } else {
        assert(!"method unknown in cppyy_call_c");
    } 
    return result;
}

short cppyy_call_h(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    short result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["CppyyTestData::get_short"]) {
        assert(self && nargs == 0);
        result = ((dummy::CppyyTestData*)self)->get_short();
    } else if (idx == s_methods["CppyyTestData::get_ushort"]) {
        assert(self && nargs == 0);
        result = (short)((dummy::CppyyTestData*)self)->get_ushort();
    } else {
        assert(!"method unknown in cppyy_call_h");
    }   
    return result;
}

int cppyy_call_i(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    int result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["TInterpreter::ProcessLine_cchar*"]) {
        assert(self && nargs == 1);
        result = ((dummy::TInterpreter*)self)->ProcessLine(
            (const char*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]));
    } else if (idx == s_methods["static_example01::staticAddOneToInt_int"]) {
        assert(!self && nargs == 1);
        result = dummy::example01::staticAddOneToInt(((CPPYY_G__value*)args)[0].obj.in);
    } else if (idx == s_methods["static_example01::staticAddOneToInt_int_int"]) {
        assert(!self && nargs == 2);
        result = dummy::example01::staticAddOneToInt(
           ((CPPYY_G__value*)args)[0].obj.in, ((CPPYY_G__value*)args)[1].obj.in);
    } else if (idx == s_methods["static_example01::staticAtoi_cchar*"]) {
        assert(!self && nargs == 1);
        result = dummy::example01::staticAtoi((const char*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]));
    } else if (idx == s_methods["static_example01::getCount"]) {
        assert(!self && nargs == 0);
        result = dummy::example01::getCount();
    } else if (idx == s_methods["example01::addDataToInt_int"]) {
        assert(self && nargs == 1);
        result = ((dummy::example01*)self)->addDataToInt(((CPPYY_G__value*)args)[0].obj.in);
    } else if (idx == s_methods["example01::addDataToAtoi_cchar*"]) {
        assert(self && nargs == 1);
        result = ((dummy::example01*)self)->addDataToAtoi(
           (const char*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]));
    } else if (idx == s_methods["CppyyTestData::get_int"]) {
        assert(self && nargs == 0);
        result = ((dummy::CppyyTestData*)self)->get_int();
    } else if (idx == s_methods["std::complex<int>::real"]) {
        assert(self && nargs == 0);
        result = ((std::complex<int>*)self)->real();
    } else if (idx == s_methods["std::complex<int>::imag"]) {
        assert(self && nargs == 0);
        result = ((std::complex<int>*)self)->imag();
    } else {
        assert(!"method unknown in cppyy_call_i");
    }
    return result;
}

long cppyy_call_l(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    long result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["CppyyTestData::get_wchar"]) {
        assert(self && nargs == 0);
        result = (long)((dummy::CppyyTestData*)self)->get_wchar();
    } else if (idx == s_methods["CppyyTestData::get_char16"]) {
        assert(self && nargs == 0);
        result = (long)((dummy::CppyyTestData*)self)->get_char16();
    } else if (idx == s_methods["CppyyTestData::get_char32"]) {
        assert(self && nargs == 0);
        result = (long)((dummy::CppyyTestData*)self)->get_char32();
    } else if (idx == s_methods["CppyyTestData::get_uint"]) {
        assert(self && nargs == 0);
        result = (long)((dummy::CppyyTestData*)self)->get_uint();
    } else if (idx == s_methods["CppyyTestData::get_long"]) {
        assert(self && nargs == 0);
        result = ((dummy::CppyyTestData*)self)->get_long();
    } else if (idx == s_methods["CppyyTestData::get_ulong"]) {
        assert(self && nargs == 0);
        result = (long)((dummy::CppyyTestData*)self)->get_ulong();
    } else {
        assert(!"method unknown in cppyy_call_l");
    }
    return result;
}

long long cppyy_call_ll(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    long long result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["CppyyTestData::get_llong"]) {
        assert(self && nargs == 0);
        result = ((dummy::CppyyTestData*)self)->get_llong();
    } else if (idx == s_methods["CppyyTestData::get_ullong"]) {
        assert(self && nargs == 0);
        result = (long long)((dummy::CppyyTestData*)self)->get_ullong();
    } else {
        assert(!"method unknown in cppyy_call_ll");
    }
    return result;
}   

float cppyy_call_f(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    float result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["CppyyTestData::get_float"]) {
        assert(self && nargs == 0);
        result = ((dummy::CppyyTestData*)self)->get_float();
    } else {
        assert(!"method unknown in cppyy_call_f");
    }
    return result;
}   

double cppyy_call_d(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    double result = 0.;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["static_example01::staticAddToDouble_double"]) {
        assert(!self && nargs == 1);
        result = dummy::example01::staticAddToDouble(((CPPYY_G__value*)args)[0].obj.d);
    } else if (idx == s_methods["example01::addDataToDouble_double"]) {
        assert(self && nargs == 1);
        result = ((dummy::example01*)self)->addDataToDouble(((CPPYY_G__value*)args)[0].obj.d);
    } else if (idx == s_methods["payload::getData"]) {
        assert(self && nargs == 0);
        result = ((dummy::payload*)self)->getData();
    } else if (idx == s_methods["CppyyTestData::get_double"]) {
        assert(self && nargs == 0);
        result = ((dummy::CppyyTestData*)self)->get_double();
    } else if (idx == s_methods["std::complex<double>::real"]) {
        assert(self && nargs == 0);
        result = ((std::complex<double>*)self)->real();
    } else if (idx == s_methods["std::complex<double>::imag"]) {
        assert(self && nargs == 0);
        result = ((std::complex<double>*)self)->imag();
    } else {
        assert(!"method unknown in cppyy_call_d");
    }
    return result;
}

double cppyy_call_nld(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    double result = 0.;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["CppyyTestData::get_ldouble_def"]) {
        if (nargs == 1)
            result = (double)((dummy::CppyyTestData*)self)->get_ldouble_def(
                ((CPPYY_G__value*)args)[0].obj.ld);
        else {
            assert(self && nargs == 0);
            result = (double)((dummy::CppyyTestData*)self)->get_ldouble_def();
        }
    } else if (idx == s_methods["CppyyTestData::get_ldouble"]) {
        assert(self && nargs == 0);
        result = (double)((dummy::CppyyTestData*)self)->get_ldouble();
    } else {
        assert(!"method unknown in cppyy_call_nld");
    }
    return result;
}

#define DISPATCH_CALL_R_GET(tpname)                                           \
      else if (idx == s_methods["CppyyTestData::get_"#tpname"_r"]) {          \
        assert(self && nargs == 0);                                           \
        result = (void*)&((dummy::CppyyTestData*)self)->get_##tpname##_r();   \
    } else if (idx == s_methods["CppyyTestData::get_"#tpname"_cr"]) {         \
        assert(self && nargs == 0);                                           \
        result = (void*)&((dummy::CppyyTestData*)self)->get_##tpname##_cr();  \
    }

#define DISPATCH_CALL_R_GET2(tpname)                                          \
    DISPATCH_CALL_R_GET(tpname)                                               \
      else if (idx == s_methods["CppyyTestData::get_"#tpname"_array"]) {      \
        assert(self && nargs == 0);                                           \
        result = (void*)((dummy::CppyyTestData*)self)->get_##tpname##_array();\
    } else if (idx == s_methods["CppyyTestData::get_"#tpname"_array2"]) {     \
        assert(self && nargs == 0);                                           \
        result = (void*)((dummy::CppyyTestData*)self)->get_##tpname##_array2();\
    }

#define DISPATCH_CALL_R_GET3(tpname, tpcode, type)                            \
    DISPATCH_CALL_R_GET2(tpname)                                              \
      else if (idx == s_methods["CppyyTestData::pass_array_"#tpname]) {       \
        assert(self && nargs == 1);                                           \
        result = (void*)((dummy::CppyyTestData*)self)->pass_array(            \
           (*(type**)&((CPPYY_G__value*)args)[0]));                           \
    } else if (idx == s_methods["CppyyTestData::pass_void_array_"#tpcode]) {  \
        assert(self && nargs == 1);                                           \
        result = (void*)((dummy::CppyyTestData*)self)->pass_void_array_##tpcode (\
           (*(type**)&((CPPYY_G__value*)args)[0]));                           \
    }

void* cppyy_call_r(cppyy_method_t method, cppyy_object_t self, int nargs, void* args) {
    void* result = nullptr;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["static_example01::staticStrcpy_cchar*"]) {
        assert(!self && nargs == 1);
        result = (void*)dummy::example01::staticStrcpy(
           (const char*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]));
    } else if (idx == s_methods["static_example01::staticCyclePayload_payload*_double"]) {
        assert(!self && nargs == 2);
        result = (void*)dummy::example01::staticCyclePayload(
           (dummy::payload*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]),
           ((CPPYY_G__value*)args)[1].obj.d);
    } else if (idx == s_methods["example01::addToStringValue_cchar*"]) {
        assert(self && nargs == 1);
        result = (void*)((dummy::example01*)self)->addToStringValue(
           (const char*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]));
    } else if (idx == s_methods["example01::cyclePayload_payload*"]) {
        assert(self && nargs == 1);
        result = (void*)((dummy::example01*)self)->cyclePayload(
           (dummy::payload*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]));
    }
    DISPATCH_CALL_R_GET2(bool)
    DISPATCH_CALL_R_GET (wchar)
    DISPATCH_CALL_R_GET (int8)
    DISPATCH_CALL_R_GET (uint8)
    DISPATCH_CALL_R_GET3(short,    h, short)
    DISPATCH_CALL_R_GET3(ushort,   H, unsigned short)
    DISPATCH_CALL_R_GET3(int,      i, int)
    DISPATCH_CALL_R_GET3(uint,     I, unsigned int)
    DISPATCH_CALL_R_GET3(long,     l, long)
    DISPATCH_CALL_R_GET3(ulong,    L, unsigned long)
    DISPATCH_CALL_R_GET (llong)
    DISPATCH_CALL_R_GET (ullong)
    DISPATCH_CALL_R_GET (long64)
    DISPATCH_CALL_R_GET (ulong64)
    DISPATCH_CALL_R_GET3(float,    f, float)
    DISPATCH_CALL_R_GET3(double,   d, double)
    DISPATCH_CALL_R_GET (ldouble)
    DISPATCH_CALL_R_GET (complex)
    DISPATCH_CALL_R_GET (icomplex)
    else {
        assert(!"method unknown in cppyy_call_r");
    }
    return result;
}

char* cppyy_call_s(cppyy_method_t method, cppyy_object_t self, int nargs, void* args, size_t* /* length */) {
    char* result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["static_example01::staticStrcpy_cchar*"]) {
        assert(!self && nargs == 1);
        result = dummy::example01::staticStrcpy((const char*)(*(intptr_t*)&((CPPYY_G__value*)args)[0]));
    } else {
        assert(!"method unknown in cppyy_call_s");
    }
    return result;
}

cppyy_object_t cppyy_constructor(cppyy_method_t method, cppyy_type_t handle, int nargs, void* args) {
    void* result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["example01::example01"]) {
        assert(nargs == 0);
        result = new dummy::example01;
    } else if (idx == s_methods["example01::example01_int"]) {
        assert(nargs == 1);
        result = new dummy::example01(((CPPYY_G__value*)args)[0].obj.in);
    } else if (idx == s_methods["payload::payload_double"]) {
        assert(nargs == 0 || nargs == 1);
        if (nargs == 0) result = new dummy::payload;
        else if (nargs == 1) result = new dummy::payload(((CPPYY_G__value*)args)[0].obj.d);
    } else if (idx == s_methods["CppyyTestData::CppyyTestData"]) {
        assert(nargs == 0);
        result = new dummy::CppyyTestData;
    } else if (idx == s_methods["std::complex<double>::complex<double>_double_double"]) {
        assert(nargs == 2);
        result = new std::complex<double>(((CPPYY_G__value*)args)[0].obj.d, ((CPPYY_G__value*)args)[1].obj.d);
    } else if (idx == s_methods["std::complex<int>::complex<int>_int_int"]) {
        assert(nargs == 2);
        result = new std::complex<int>(((CPPYY_G__value*)args)[0].obj.i, ((CPPYY_G__value*)args)[1].obj.i);
    } else {
        assert(!"method unknown in cppyy_constructor");
    }       
    return (cppyy_object_t)result;
}

cppyy_object_t cppyy_call_o(
        cppyy_method_t method, cppyy_object_t self, int nargs, void* args, cppyy_type_t result_type) {
    void* result = 0;
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["CppyyTestData::get_complex"]) {
        assert(self && nargs == 0);
        result = new std::complex<double>(((dummy::CppyyTestData*)self)->get_complex());
    } else if (idx == s_methods["CppyyTestData::get_icomplex"]) {
        assert(self && nargs == 0);
        result = new std::complex<int>(((dummy::CppyyTestData*)self)->get_icomplex());
    }
    return (cppyy_object_t)result;
}

cppyy_funcaddr_t cppyy_function_address(cppyy_method_t /* method */) {
    return (cppyy_funcaddr_t)0;
}

/* handling of function argument buffer ----------------------------------- */
void* cppyy_allocate_function_args(int nargs) {
    /* nargs parameters + one unsigned long for exception status output */
    CPPYY_G__value* args = (CPPYY_G__value*)malloc(nargs*sizeof(CPPYY_G__value)+sizeof(unsigned long));
    for (int i = 0; i < nargs; ++i)
        args[i].type = 'l';
    return (void*)args;
}


/* handling of function argument buffer ----------------------------------- */
void cppyy_deallocate_function_args(void* args) {
    free(args);
}

size_t cppyy_function_arg_sizeof() {
    return sizeof(CPPYY_G__value);
}

size_t cppyy_function_arg_typeoffset() {
    return offsetof(CPPYY_G__value, type);
}


/* scope reflection information ------------------------------------------- */
int cppyy_is_namespace(cppyy_scope_t handle) {
    if (handle == s_handles[std::string("")] ||
        handle == s_handles["std"] ||
        handle == s_handles["pyzables"])
        return 1;
    return 0;
}

int cppyy_is_template(const char* template_name) {
    if (strcmp(template_name, "std::complex") == 0)
        return 1;
    return 0;
}

int cppyy_is_abstract(cppyy_type_t /* type) */) {
    return 0;
}

int cppyy_is_enum(const char* type_name) {
    if (strcmp(type_name, "CppyyTestData::EWhat") == 0)
        return 1;
    return 0;
}
    
    
/* class reflection information ------------------------------------------- */
char* cppyy_final_name(cppyy_type_t handle) {
    for (Handles_t::iterator isp = s_handles.begin(); isp != s_handles.end(); ++isp) {
        if (isp->second == handle)
            return cppstring_to_cstring(isp->first);
    }
    return cppstring_to_cstring("<unknown>");
}

char* cppyy_scoped_final_name(cppyy_type_t handle) {
    const std::string& rec_name = cppyy_final_name(handle);
    if (rec_name == "complex_t")
        return cppstring_to_cstring("std::complex<double>");
    else if (rec_name == "icomplex_t")
        return cppstring_to_cstring("std::complex<int>");
    return cppstring_to_cstring(rec_name);
}   

int cppyy_has_complex_hierarchy(cppyy_type_t /* handle */) {
    return 0;
}

int cppyy_num_bases(cppyy_type_t /*handle*/) {
   return 0;
}

int cppyy_smartptr_info(const char* name, cppyy_type_t* raw, cppyy_method_t* deref) {
   return 0;
}


/* method/function reflection information --------------------------------- */
cppyy_method_t cppyy_get_method(cppyy_scope_t handle, cppyy_index_t idx) {
    if (s_scopes.find(handle) != s_scopes.end()) {
        return (cppyy_method_t)s_scopes[handle].m_methods[idx];
    }
    assert(!"unknown class in cppyy_get_method");
    return (cppyy_method_t)0;
}

int cppyy_num_methods(cppyy_scope_t handle) {
    return s_scopes[handle].m_methods.size();
}

char* cppyy_method_name(cppyy_method_t method) {
    return cppstring_to_cstring(((Cppyy_PseudoMethodInfo*)method)->m_name);
}

char* cppyy_method_full_name(cppyy_method_t method) {
    return cppstring_to_cstring(((Cppyy_PseudoMethodInfo*)method)->m_name);
}

char* cppyy_method_result_type(cppyy_method_t method) {
    return cppstring_to_cstring(((Cppyy_PseudoMethodInfo*)method)->m_returntype);
}
    
int cppyy_method_num_args(cppyy_method_t method) {
    return ((Cppyy_PseudoMethodInfo*)method)->m_argtypes.size();
}

int cppyy_method_req_args(cppyy_method_t method) {
    return cppyy_method_num_args(method)-((Cppyy_PseudoMethodInfo*)method)->m_argdefaults.size();
}

char* cppyy_method_arg_type(cppyy_method_t method, int idx) {
    return cppstring_to_cstring(((Cppyy_PseudoMethodInfo*)method)->m_argtypes[idx]);
}

char* cppyy_method_arg_default(cppyy_method_t method, int idx) {
    if (idx < (int)((Cppyy_PseudoMethodInfo*)method)->m_argdefaults.size())
        return cppstring_to_cstring(((Cppyy_PseudoMethodInfo*)method)->m_argdefaults[idx]);
    return cppstring_to_cstring("");
}

char* cppyy_method_signature(cppyy_method_t method, int /* show_formalargs */) {
    Cppyy_PseudoMethodInfo* idx = (Cppyy_PseudoMethodInfo*)method;
    if (idx == s_methods["std::complex<double>::real"])
        return cppstring_to_cstring("()");
    else if (idx == s_methods["std::complex<double>::imag"])
        return cppstring_to_cstring("()");
    else if (idx == s_methods["std::complex<int>::real"])
        return cppstring_to_cstring("()");
    else if (idx == s_methods["std::complex<int>::imag"])
        return cppstring_to_cstring("()");
    return cppstring_to_cstring("");
}

char* cppyy_method_prototype(cppyy_scope_t, cppyy_method_t, int /* show_formalargs */) {
    return cppstring_to_cstring("");
}

int cppyy_get_num_templated_methods(cppyy_scope_t scope) {
    return 0;
}

int cppyy_exists_method_template(cppyy_scope_t scope, const char* name) {
    return 0;
}

int cppyy_method_is_template(cppyy_scope_t /* handle */, cppyy_index_t /* method_index */) {
    return 0;
}
    
cppyy_index_t cppyy_get_global_operator(cppyy_scope_t /* scope */,
        cppyy_scope_t /* lc */, cppyy_scope_t /* rc */, const char* /* op */) {
    return (cppyy_index_t)-1;
}


/* method properties -----------------------------------------------------  */
int cppyy_is_publicmethod(cppyy_method_t) {
    return 1;
}

int cppyy_is_constructor(cppyy_method_t method) {
    if (method)
        return ((Cppyy_PseudoMethodInfo*)method)->m_type == kConstructor;
    assert(!"unknown class in cppyy_is_constructor");
    return 0;
}

int cppyy_is_destructor(cppyy_method_t) {
    return 0;
}

int cppyy_is_staticmethod(cppyy_method_t method) {
    if (method)
        return ((Cppyy_PseudoMethodInfo*)method)->m_type == kStatic;
    assert(!"unknown class in cppyy_is_staticmethod");
    return 0;
}


/* data member reflection information ------------------------------------- */
int cppyy_num_datamembers(cppyy_scope_t handle) {
    if (cppyy_is_namespace(handle))
        return 0;
    return s_scopes[handle].m_datambrs.size();
}

char* cppyy_datamember_name(cppyy_scope_t handle, int idatambr) {
    return cppstring_to_cstring(s_scopes[handle].m_datambrs[idatambr].m_name);
}

char* cppyy_datamember_type(cppyy_scope_t handle, int idatambr) {
    return cppstring_to_cstring(s_scopes[handle].m_datambrs[idatambr].m_type);
}

ptrdiff_t cppyy_datamember_offset(cppyy_scope_t handle, int idatambr) {
    return s_scopes[handle].m_datambrs[idatambr].m_offset;
}

int cppyy_datamember_index(cppyy_scope_t handle, const char* name) {
    if (handle == s_handles[std::string("")]) {
        if (strcmp(name, "N") == 0)            return 0;
        if (strcmp(name, "gInterpreter") == 0) return 1;
    }

    return (int)-1;
}


/* data member properties ------------------------------------------------  */
int cppyy_is_publicdata(cppyy_scope_t /* handle */, cppyy_index_t /* idatambr */) {
    return 1;
}

int cppyy_is_staticdata(cppyy_scope_t handle, cppyy_index_t idatambr) {
    return s_scopes[handle].m_datambrs[idatambr].m_isstatic;
}

int cppyy_is_const_data(cppyy_scope_t handle, cppyy_index_t idatambr) {
    if (s_scopes[handle].m_datambrs[idatambr].m_name == "m_const_int")
        return 1;
    return 0;
}

int cppyy_is_enum_data(cppyy_scope_t /* handle */, cppyy_index_t /* idatambr */) {
    return 0;
}

int cppyy_get_dimension_size(
        cppyy_scope_t /* scope */, cppyy_index_t /* idata */, int /* dimension */) {
    return -1; // no dimensions
}


/* misc helpers ----------------------------------------------------------- */
#if defined(_MSC_VER)
long long cppyy_strtoll(const char* str) {
    return _strtoi64(str, NULL, 0);
}

extern "C" {
unsigned long long cppyy_strtoull(const char* str) {
    return _strtoui64(str, NULL, 0);
}
}
#else
long long cppyy_strtoll(const char* str) {
    return strtoll(str, NULL, 0);
}

extern "C" {
unsigned long long cppyy_strtoull(const char* str) {
    return strtoull(str, NULL, 0);
}
}
#endif

void cppyy_free(void* ptr) {
    free(ptr);
}

cppyy_object_t cppyy_charp2stdstring(const char* str, size_t sz) {
    return (cppyy_object_t)new std::string(str, sz);
}

const char* cppyy_stdstring2charp(cppyy_object_t ptr, size_t* lsz) {
    *lsz = ((std::string*)ptr)->size();
    return ((std::string*)ptr)->data();
}

cppyy_object_t cppyy_stdstring2stdstring(cppyy_object_t ptr) {
    return (cppyy_object_t)new std::string(*(std::string*)ptr);
}

double cppyy_longdouble2double(void* p) {
    return (double)*(long double*)p;
}

void cppyy_double2longdouble(double d, void* p) {
    *(long double*)p = d;
}

int cppyy_vectorbool_getitem(cppyy_object_t ptr, int idx) {
    return (int)(*(std::vector<bool>*)ptr)[idx];
}

void cppyy_vectorbool_setitem(cppyy_object_t ptr, int idx, int value) {
    (*(std::vector<bool>*)ptr)[idx] = (bool)value;
}
