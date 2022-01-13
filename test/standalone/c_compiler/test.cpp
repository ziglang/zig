#include <iostream>
#include <cassert>

class CTest {
public:
	CTest(int val) : m_val(val) {};
	virtual ~CTest() {}

	virtual int getVal() const { return m_val; }
	virtual void printVal() { std::cout << "val=" << m_val << std::endl; }
private:
	int m_val;
};


volatile int runtime_val = 456;
CTest global(runtime_val);	// test if global initializers are called.

int main (int argc, char *argv[])
{
	assert(global.getVal() == 456);

	auto* t = new CTest(123);
	assert(t->getVal()!=456);

	if (argc>1) t->printVal();
	bool ok = t->getVal() == 123;
	delete t;

	if (!ok) abort();

	return 0;
}
