class MySimpleBase {
public:
    MySimpleBase() {}
};

class MySimpleDerived : public MySimpleBase {
public:
    MySimpleDerived() { m_data = -42; }
    int get_data() { return m_data; }
    void set_data(int data) { m_data = data; }
public:
    int m_data;
};

typedef MySimpleDerived MySimpleDerived_t;
