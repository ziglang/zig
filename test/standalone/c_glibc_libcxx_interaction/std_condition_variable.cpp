#include <condition_variable>
#include <mutex>

int main()
{
    std::mutex mutex;
    std::unique_lock<std::mutex> lock(mutex);

    std::condition_variable cv;
    cv.wait_for(lock, std::chrono::seconds(1));

    return 0;
}
