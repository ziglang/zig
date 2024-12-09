template <typename T>
class Adder {
    const T increment;
public:
    Adder(T _increment) : increment(_increment) {}
    T add(T x) const  { return x + increment; }
};

extern "C" int add_CXX(int x, int a) {
    Adder<int> adder(a);
    return adder.add(x);
}
