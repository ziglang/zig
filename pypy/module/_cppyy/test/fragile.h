namespace fragile {

class no_such_class;

class A {
public:
    virtual int check() { return (int)'A'; }
    virtual A* gime_null() { return (A*)0; }
};

class B {
public:
    virtual int check() { return (int)'B'; }
    no_such_class* gime_no_such() { return 0; }
};

class C {
public:
    virtual int check() { return (int)'C'; }
    void use_no_such(no_such_class*) {}
};

class D {
public:
    virtual int check() { return (int)'D'; }
    virtual int check(int, int) { return (int)'D'; }
    void overload() {}
    void overload(no_such_class*) {}
    void overload(char, int i = 0) {}  // Reflex requires a named arg
    void overload(int, no_such_class* p = 0) {}
};


static const int dummy_location = 0xdead;

class E {
public:
    E() : m_pp_no_such((no_such_class**)&dummy_location), m_pp_a(0) {}

    virtual int check() { return (int)'E'; }
    void overload(no_such_class**) {}

    no_such_class** m_pp_no_such;
    A** m_pp_a;
};

class F {
public:
    F() : m_int(0) {}
    virtual int check() { return (int)'F'; }
    int m_int;
};

class G {
public:
    enum { unnamed1=24, unnamed2=96 };

    class GG {};
};

class H {
public:
    class HH {
    public:
       HH* copy();
    };
    HH* m_h;
};

class I {
public:
    operator bool() { return 0; }
};

extern I gI;

class J {
public:
    int method1(int, double) { return 0; }
};

void fglobal(int, double, char);

namespace nested1 {
    class A {};
    namespace nested2 {
        class A {};
        namespace nested3 {
            class A {};
        } // namespace nested3
    } // namespace nested2
} // namespace nested1

class K {
public:
    virtual ~K();
    K* GimeK(bool derived);
    K* GimeL();
};

class L : public K {
public:
    virtual ~L();
    no_such_class* m_no_such;
};

class M {
public:
    virtual ~M() {}
    enum E1 { kOnce=42 };
    enum E2 { kTwice=12 };
};

class N : public M {
public:
    enum E2 { kTwice=12 };
};

class O {
public:
   virtual int abstract() = 0;
};

} // namespace fragile
