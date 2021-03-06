#include "systemc.h"
#include "testbench.h"
#include "mainFunc.h"

SC_MODULE(top) {

mainFunc m;
testbench tb;
sc_fifo<sc_lv<32> > s1;
sc_fifo<sc_lv<32> > s2;
sc_fifo<sc_lv<32> > a;
sc_fifo<sc_lv<32> > out;


SC_CTOR(top) : m("m"), tb("tb") {
m.s1(s1); tb.s1(s1);
m.s2(s2); tb.s2(s2);
m.a(a); tb.a(a);
m.out(out); tb.out(out);


}
};