#include <string>

class payload {
public:
    payload(double d = 0.);
    payload(const payload& p);
    payload& operator=(const payload& e);
    ~payload();

    double getData();
    void setData(double d);

public:        // class-level data
    static int count;

private:
    double m_data;
};


class example01 {
public:
    example01();
    example01(int a);
    example01(const example01& e);
    example01& operator=(const example01& e);
    virtual ~example01();

public:        // class-level methods
    static int staticAddOneToInt(int a);
    static int staticAddOneToInt(int a, int b);
    static double staticAddToDouble(double a);
    static int staticAtoi(const char* str);
    static char* staticStrcpy(const char* strin);
    static void staticSetPayload(payload* p, double d);
    static payload* staticCyclePayload(payload* p, double d);
    static payload staticCopyCyclePayload(payload* p, double d);
    static int getCount();
    static void setCount(int);

public:        // instance methods
    int addDataToInt(int a);
    int addDataToIntConstRef(const int& a);
    int overloadedAddDataToInt(int a, int b);
    int overloadedAddDataToInt(int a);
    int overloadedAddDataToInt(int a, int b, int c);
    double addDataToDouble(double a);
    int addDataToAtoi(const char* str);
    char* addToStringValue(const char* str);

    void setPayload(payload* p);
    payload* cyclePayload(payload* p);
    payload copyCyclePayload(payload* p);

public:        // class-level data
    static int count;

public:        // instance data
    int m_somedata;
};


// global functions and data
int globalAddOneToInt(int a);
namespace ns_example01 {
    int globalAddOneToInt(int a);
    extern int gMyGlobalInt;
}

int installableAddOneToInt(example01&, int a);

#define itypeValue(itype, tname) \
   itype tname##Value(itype arg0, int argn=0, itype arg1=1, itype arg2=2)

#define ftypeValue(ftype) \
   ftype ftype##Value(ftype arg0, int argn=0, ftype arg1=1., ftype arg2=2.)


// argument passing
class ArgPasser {        // use a class for now as methptrgetter not
public:                  // implemented for global functions
   itypeValue(short, short);
   itypeValue(unsigned short, ushort);
   itypeValue(int, int);
   itypeValue(unsigned int, uint);
   itypeValue(long, long);
   itypeValue(unsigned long, ulong);

   ftypeValue(float);
   ftypeValue(double);

   std::string stringValue(
      std::string arg0, int argn=0, std::string arg1 = "default");

   std::string stringRef(
      const std::string& arg0, int argn=0, const std::string& arg1="default");
};


// typedefs
typedef example01 example01_t;


// special case naming
class z_ {
public:
   z_& gime_z_(z_& z);
   int myint;
};

// for pythonization checking
class example01a : public example01 {
public:
   example01a(int a) : example01(a) {}
};
