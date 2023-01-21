#include "all.h"

SimpleStringOwner::SimpleStringOwner(const char* x) : string{ 10 } {
  if (!string.append_line(x)) {
    throw Error{ "Not enough memory!" };
  }
  string.print("Constructed");
}

SimpleStringOwner::~SimpleStringOwner() {
  string.print("About to destroy");
}
