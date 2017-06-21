#ifndef MAINFUNC_H_
#define MAINFUNC_H_

#include "systemc.h"
#include "const_dec_12_.h"
#include "const_dec_11_.h"
#include "add1_.h"
#include "equ1_.h"


SC_MODULE(mainFunc) {
sc_fifo_in<sc_lv<32> > n;
sc_fifo_in<sc_lv<32> > k;
sc_fifo_in<sc_lv<32> > s;

sc_fifo_out<sc_lv<32> > out;

sc_fifo<sc_lv<32> > const_dec_12_out__add1_in2;

const_dec_12_ const_dec_12;
const_dec_11_ const_dec_11;
add1_ add1;
equ1_ equ1;

sc_lv<32> n__aux;
sc_lv<32> k__aux;
sc_fifo<sc_lv<32> > __fifo__main__cond__1__in__n;
sc_fifo<sc_lv<32> > __fifo__main__cond__1__in__k;
sc_lv<1> __fifo__main__cond__1__out__aux;
sc_fifo<sc_lv<1> > __fifo__main__cond__1__out;
sc_lv<1> __fifo__main__cond__2__out__aux;
sc_fifo<sc_lv<1> > __fifo__main__cond__2__out;
sc_lv<2> cond;
sc_lv<32> s__copy__val;
sc_lv<32> s__destroy;
sc_fifo<sc_lv<32> > __fifo__main__rec__expr__2__2__in__k;
sc_lv<32> __fifo__main__rec__expr__2__2__out__aux;
sc_fifo<sc_lv<32> > __fifo__main__rec__expr__2__2__out;
sc_lv<32> s__now__1;

void proc();
SC_CTOR(mainFunc) : const_dec_12("const_dec_12"), const_dec_11("const_dec_11"), add1("add1"), equ1("equ1") {

const_dec_12.out(const_dec_12_out__add1_in2);
add1.in2(const_dec_12_out__add1_in2);

add1.in1(__fifo__main__rec__expr__2__2__in__k);
add1.out(__fifo__main__rec__expr__2__2__out);
const_dec_11.out(__fifo__main__cond__2__out);
equ1.in2(__fifo__main__cond__1__in__k);
equ1.in1(__fifo__main__cond__1__in__n);
equ1.out(__fifo__main__cond__1__out);

SC_THREAD(proc);
}
};
void mainFunc::proc() {
while(true) {
n__aux = n.read();
k__aux = k.read();
while (true) {
__fifo__main__cond__1__in__n.write(n__aux);
__fifo__main__cond__1__in__k.write(k__aux);
__fifo__main__cond__1__out__aux = __fifo__main__cond__1__out.read();
__fifo__main__cond__2__out__aux = __fifo__main__cond__2__out.read();
cond = (__fifo__main__cond__2__out__aux, __fifo__main__cond__1__out__aux);
if (cond[0]==1) {
while (s.nb_read(s__copy__val)) {
out.write(s__copy__val);
}

while(s.nb_read(s__destroy)) {}

break;


} else {
__fifo__main__rec__expr__2__2__in__k.write(k__aux);
//blob
__fifo__main__rec__expr__2__2__out__aux = __fifo__main__rec__expr__2__2__out.read();
//blob
k__aux = __fifo__main__rec__expr__2__2__out__aux;
s__now__1 = s.read();

}

}

}
}

#endif
