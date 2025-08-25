#include <iostream>
#include <thread>

extern "C" void doit() {
    std::cout << "mt: thread=" << std::this_thread::get_id() << std::endl;
}
