#include "all.h"
#include <cstdio>
#include <cstring>

SimpleString::SimpleString(size_t max_size)
: max_size{ max_size }, length{} {
  if (max_size == 0) {
    throw Error{ "Max size must be at least 1." };
  }
  buffer = new char[max_size];
  buffer[0] = 0;
}

SimpleString::~SimpleString() {
  delete[] buffer;
}

void SimpleString::print(const char* tag) const {
  printf("%s: %s", tag, buffer);
}

bool SimpleString::append_line(const char* x) {
  const auto x_len = strlen(x);
  if (x_len + length + 2 > max_size) return false;
  std::strncpy(buffer + length, x, max_size - length);
  length += x_len;
  buffer[length++] = '\n';
  buffer[length] = 0;
  return true;
}
