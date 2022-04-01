#include <list>
#include <map>
#include <string>
#include <utility>
#include <vector>


//- basic example class
class just_a_class {
public:
    int m_i;
};

// enum for vector of enums setitem tests
enum VecTestEnum {
    EVal1 = 1, EVal2 = 3
};

namespace VecTestEnumNS {
    enum VecTestEnum { EVal1 = 5, EVal2 = 42 };
}


//- class with lots of std::string handling
class stringy_class {
public:
   stringy_class(const char* s);

   std::string get_string1();
   void get_string2(std::string& s);

   void set_string1(const std::string& s);
   void set_string2(std::string s);

   std::string m_string;
};

//- class that has an STL-like interface
class no_dict_available;
    
template<class T>
class stl_like_class {
public: 
   no_dict_available* begin() { return 0; }
   no_dict_available* end() { return (no_dict_available*)1; }
   int size() { return 4; }
   int operator[](int i) { return i; }
   std::string operator[](double) { return "double"; }
   std::string operator[](const std::string&) { return "string"; }
};      

namespace {
    stl_like_class<int> stlc_1;
}


//- helpers for testing array
namespace ArrayTest {

struct Point {
    Point() : px(0), py(0) {}
    Point(int x, int y) : px(x), py(y) {}
    int px, py;
};

int get_pp_px(Point** p, int idx);
int get_pp_py(Point** p, int idx);
int get_pa_px(Point* p[], int idx);
int get_pa_py(Point* p[], int idx);

} // namespace ArrayTest


// helpers for string testing
extern std::string str_array_1[3];
extern std::string str_array_2[];
extern std::string str_array_3[3][2];
extern std::string str_array_4[4][2][2];
