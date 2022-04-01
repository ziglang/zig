int main() {
  double s =0.0;
  double i =0.0;
  while (i < 1000000000) {
    s += i;
    i += 1.0;
  }
  return s;
}
