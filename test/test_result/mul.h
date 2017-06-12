#ifndef MUL_H_
#define MUL_H_
#include "systemc.h"
SC_MODULE(mul) {
sc_fifo_in<sc_lv<32> > in1;
sc_fifo_in<sc_lv<32> > in2;
sc_fifo_out<sc_lv<32> > out;


void proc();
SC_CTOR(mul) {
SC_THREAD(proc);
}
};

void mul::proc() {
while(true) {
out.write((sc_uint<32>)in1.read()*(sc_uint<32>)in2.read());
}
}
#endif