double sum(double *img) {
  int l=0;
  for (int i=0; i<640*480; i++) {
    l+=img[i];
  }
  return l;
}
