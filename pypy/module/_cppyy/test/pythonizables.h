#include <memory>
#include <vector>


namespace pyzables {

//===========================================================================
class SomeDummy1 {};
class SomeDummy2 {};


//===========================================================================
class MyBase {
public:
    virtual ~MyBase();
};
class MyDerived : public MyBase {
public:
    virtual ~MyDerived();
};

MyBase* GimeDerived();


//===========================================================================
class Countable {
public:
    Countable() { ++sInstances; }
    Countable(const Countable&) { ++sInstances; }
    Countable& operator=(const Countable&) { return *this; }
    ~Countable() { --sInstances; }

public:
    virtual const char* say_hi() { return "Hi!"; }

public:
    unsigned int m_check = 0xcdcdcdcd;

public:
    static int sInstances;
};

typedef std::shared_ptr<Countable> SharedCountable_t; 
extern SharedCountable_t mine;

void renew_mine();

SharedCountable_t gime_mine();
SharedCountable_t* gime_mine_ptr();
SharedCountable_t& gime_mine_ref();

unsigned int pass_mine_sp(SharedCountable_t p);
unsigned int pass_mine_sp_ref(SharedCountable_t& p);
unsigned int pass_mine_sp_ptr(SharedCountable_t* p);

unsigned int pass_mine_rp(Countable);
unsigned int pass_mine_rp_ref(const Countable&);
unsigned int pass_mine_rp_ptr(const Countable*);

Countable* gime_naked_countable();

} // namespace pyzables
