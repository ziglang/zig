void trans(unsigned char *img, unsigned int *intimg) {  
  int l=0;
  for (int i=640; i<640*480; i++) {
    l+=img[i];
    intimg[i]=intimg[i-640]+l;
  }
}


void transf(double *img, double *intimg) {  
  double l=0;
  for (int i=640; i<640*480; i++) {
    l+=img[i];
    intimg[i]=intimg[i-640]+l;
  }
}


