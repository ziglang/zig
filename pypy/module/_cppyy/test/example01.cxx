#include <sstream>
#include <string>
#include <stdlib.h>
#include <string.h>

#include "example01.h"

//===========================================================================
payload::payload(double d) : m_data(d) {
    count++;
}
payload::payload(const payload& p) : m_data(p.m_data) {
    count++;
}
payload& payload::operator=(const payload& p) {
    if (this != &p) {
        m_data = p.m_data;
    }
    return *this;
}
payload::~payload() {
    count--;
}

double payload::getData() { return m_data; }
void payload::setData(double d) { m_data = d; }

// class-level data
int payload::count = 0;


//===========================================================================
example01::example01() : m_somedata(-99) {
    count++;
}
example01::example01(int a) : m_somedata(a) {
    count++;
}
example01::example01(const example01& e) : m_somedata(e.m_somedata) {
    count++;
}
example01& example01::operator=(const example01& e) {
    if (this != &e) {
        m_somedata = e.m_somedata;
    }
    return *this;
}
example01::~example01() {
    count--;
}

// class-level methods
int example01::staticAddOneToInt(int a) {
    return a + 1;
}
int example01::staticAddOneToInt(int a, int b) {
    return a + b + 1;
}
double example01::staticAddToDouble(double a) {
    return a + 0.01;
}
int example01::staticAtoi(const char* str) {
    return ::atoi(str);
}
char* example01::staticStrcpy(const char* strin) {
    char* strout = (char*)malloc(::strlen(strin)+1);
    ::strcpy(strout, strin);
    return strout;
}
void example01::staticSetPayload(payload* p, double d) {
    p->setData(d);
}

payload* example01::staticCyclePayload(payload* p, double d) {
    staticSetPayload(p, d);
    return p;
}

payload example01::staticCopyCyclePayload(payload* p, double d) {
    staticSetPayload(p, d);
    return *p;
}

int example01::getCount() {
    return count;
}

void example01::setCount(int value) {
    count = value;
}

// instance methods
int example01::addDataToInt(int a) {
    return m_somedata + a;
}

int example01::addDataToIntConstRef(const int& a) {
    return m_somedata + a;
}

int example01::overloadedAddDataToInt(int a, int b) {
   return m_somedata + a + b;
}

int example01::overloadedAddDataToInt(int a) {
   return m_somedata + a;
}

int example01::overloadedAddDataToInt(int a, int b, int c) {
   return m_somedata + a + b + c;
}

double example01::addDataToDouble(double a) {
    return m_somedata + a;
}

int example01::addDataToAtoi(const char* str) {
    return ::atoi(str) + m_somedata;
}   

char* example01::addToStringValue(const char* str) {
    int out = ::atoi(str) + m_somedata;
    std::ostringstream ss;
    ss << out << std::ends;
    std::string result = ss.str();
    char* cresult = (char*)malloc(result.size()+1);
    ::strcpy(cresult, result.c_str());
    return cresult;
}

void example01::setPayload(payload* p) {
    p->setData(m_somedata);
}

payload* example01::cyclePayload(payload* p) {
    setPayload(p);
    return p;
}

payload example01::copyCyclePayload(payload* p) {
    setPayload(p);
    return *p;
}

// class-level data
int example01::count = 0;


// global
int globalAddOneToInt(int a) {
   return a + 1;
}

int ns_example01::globalAddOneToInt(int a) {
   return ::globalAddOneToInt(a);
}

int installableAddOneToInt(example01& e, int a) {
   return e.staticAddOneToInt(a);
}

int ns_example01::gMyGlobalInt = 99;


// argument passing
#define typeValueImp(itype, tname)                                            \
itype ArgPasser::tname##Value(itype arg0, int argn, itype arg1, itype arg2)   \
{                                                                             \
   switch (argn) {                                                            \
   case 0:                                                                    \
      return arg0;                                                            \
   case 1:                                                                    \
      return arg1;                                                            \
   case 2:                                                                    \
      return arg2;                                                            \
   default:                                                                   \
      break;                                                                  \
   }                                                                          \
                                                                              \
   return (itype)-1;                                                          \
}

typeValueImp(short, short)
typeValueImp(unsigned short, ushort)
typeValueImp(int, int)
typeValueImp(unsigned int, uint)
typeValueImp(long, long)
typeValueImp(unsigned long, ulong)

typeValueImp(float, float)
typeValueImp(double, double)

std::string ArgPasser::stringValue(std::string arg0, int argn, std::string arg1)
{
   switch (argn) {
   case 0:
      return arg0;
   case 1:
      return arg1;
   default:
      break;
   }

   return "argn invalid";
}

std::string ArgPasser::stringRef(const std::string& arg0, int argn, const std::string& arg1)
{
   return stringValue(arg0, argn, arg1);
}


// special case naming
z_& z_::gime_z_(z_& z) { return z; }
