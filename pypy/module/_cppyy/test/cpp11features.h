#if __cplusplus >= 201103L

#include <memory>


//===========================================================================
class TestSharedPtr {        // for std::shared_ptr<> testing
public:
    static int s_counter;

public:
    TestSharedPtr() { ++s_counter; }
    TestSharedPtr(const TestSharedPtr&) { ++s_counter; }
    ~TestSharedPtr() { --s_counter; }
};

std::shared_ptr<TestSharedPtr> create_shared_ptr_instance();


//===========================================================================
class TestMoving1 {          // for move ctors etc.
public:
    static int s_move_counter;

public:
    TestMoving1() {}
    TestMoving1(TestMoving1&&) { ++s_move_counter; }
    TestMoving1(const TestMoving1&) {}
    TestMoving1& operator=(TestMoving1&&) { ++s_move_counter; return *this; }
    TestMoving1& operator=(TestMoving1&) { return *this; }
};

class TestMoving2 {          // note opposite method order from TestMoving1
public:
    static int s_move_counter;

public:
    TestMoving2() {}
    TestMoving2(const TestMoving2&) {}
    TestMoving2(TestMoving2&& other) { ++s_move_counter; }
    TestMoving2& operator=(TestMoving2&) { return *this; }
    TestMoving2& operator=(TestMoving2&&) { ++s_move_counter; return *this; }
};

#endif // c++11 and later
