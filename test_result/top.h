#include "systemc.h"
#include "testbench.h"
#include "mainFunc.h"

SC_MODULE(top) {

mainFunc m;
testbench tb;
sc_fifo<sc_lv<32> > __i0;
sc_fifo<sc_lv<32> > __i1;
sc_fifo<sc_lv<32> > out;


SC_CTOR(top) : m("m"), tb("tb") {
m.__i0(__i0); tb.__i0(__i0);
m.__i1(__i1); tb.__i1(__i1);
m.out(out); tb.out(out);


}
};