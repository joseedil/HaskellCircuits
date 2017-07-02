#include "systemc.h"

SC_MODULE(testbench) {
sc_fifo_in<sc_lv<32> > out;
sc_fifo_out<sc_lv<32> > n;
sc_fifo_out<sc_lv<32> > k;
sc_fifo_out<sc_lv<32> > s;
 sc_fifo_out<sc_lv<32> > a;

void proc();

SC_CTOR(testbench) {
SC_THREAD(proc);
}
};

void testbench::proc() {

  a.write(0b00000000000000000000000000000000);
  s.write(0b00000000000000000000000000000011);
  s.write(0b00000000000000000000000000000101);
  s.write(0b00000000000000000000000000000111);
  s.write(0b00000000000000000000000000001001);
  s.write(0b00000000000000000000000000001011);
  s.write(0b00000000000000000000000000000000);
  k.write(0b00000000000000000000000000000000);
  n.write(0b00000000000000000000000000000000);

  while (true) {
  cout << "ANS: " << out.read() << endl;
  }
  
  /*
  a.write(0b00000000000000000000000000000011);
  a.write(0b00000000000000000000000000000101);
  a.write(0b00000000000000000000000000000111);
  a.write(0b00000000000000000000000000000000);
  cout << "ANS: " << out.read() << endl;

  
  cout << "ANS: " << out.read() << endl;
  s.write(0b00000000000000000000000000000011);
  s.write(0b00000000000000000000000000000101);
  s.write(0b00000000000000000000000000000000);
  s.write(0b00000000000000000000000000000000);
  cout << "ANS: " << out.read() << endl;
  s.write(0b00000000000000000000000000000011);
  s.write(0b00000000000000000000000000000101);
  s.write(0b00000000000000000000000000000111);
  s.write(0b00000000000000000000000000000000);
  cout << "ANS: " << out.read() << endl;*/
}