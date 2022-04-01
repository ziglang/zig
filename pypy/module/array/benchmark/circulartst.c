
double circular(double *buf) {
  int i;
  double sa;
  for (i=0; i<65536; i++) buf[i] = i;

  i = 10;
  sa = 0;
  while(i<200000000) {
    sa += buf[(i-2)&65535] + buf[(i-1)&65535] + buf[i&65535] + buf[(i+1)&65535] + buf[(i+2)&65535];
    i += 1;
  }
  return sa;
}
