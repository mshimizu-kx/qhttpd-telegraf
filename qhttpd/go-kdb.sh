#!/bin/bash
echo $*
# QHOME=`pwd` numactl --interleave=all --physcpubind=0-54 rlwrap `pwd`/l64/q -s 55 $* # LD_LIBRARY_PATH=/usr/src/qsimdjson/qhome/ QHOME=`pwd`  gdb --args `pwd`/l64/q 
#LD_LIBRARY_PATH=/usr/src/qsimdjson/qhome/ QHOME=`pwd` numactl --localalloc --physcpubind=42-55 rlwrap $QHOME/l64/q init.q -s 14
LD_LIBRARY_PATH=`pwd` rlwrap $QHOME/l64/q -s 56 $*
