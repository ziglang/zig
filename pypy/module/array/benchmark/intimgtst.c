void trans(unsigned char *img, unsigned int *intimg);

void main2() {
  unsigned char img[640*480];
  unsigned int intimg[640*480];

  for (int l=0; l<500; l++) trans(img,intimg);
}

void transf(double *img, double *intimg);
void main() {
  double img[640*480];
  double intimg[640*480];

  for (int l=0; l<500; l++) transf(img,intimg);
}
