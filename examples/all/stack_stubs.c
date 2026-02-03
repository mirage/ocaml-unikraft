#include <caml/mlvalues.h>
#include <string.h>

void fill_buffer(char *buf, int size) {
  int i;
  for (i = 0; i < size; i++) {
    buf[i] = i & 0xff;
  }
}

value use_large_buffer(value size) {
  char buf[Int_val(size)];
  int i, sum;
  fill_buffer(buf, Int_val(size));
  for (i = 0, sum = 0; i < size; i++) {
    sum += buf[i];
  }
  return Val_int(sum);
}
