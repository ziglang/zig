extern int foo();
extern int bar();
int main() {
  return bar() - foo();
}
