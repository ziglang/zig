#ifndef ALL
#define ALL

#include <cstddef>
#include <string>
#include <stdexcept>

struct SimpleString {
  SimpleString(size_t max_size);
  ~SimpleString();

  void print(const char* tag) const;
  bool append_line(const char* x);

private:
  size_t max_size;
  char* buffer;
  size_t length;
};

struct SimpleStringOwner {
  SimpleStringOwner(const char* x);
  ~SimpleStringOwner();

private:
  SimpleString string;
};

class Error: public std::exception {
public:
  explicit Error(const char* msg) : msg{ msg } {}
  virtual ~Error() noexcept {}
  virtual const char* what() const noexcept {
    return msg.c_str();
  }

protected:
  std::string msg;
};

#endif
