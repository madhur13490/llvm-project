// Check if LoopFusion pass is triggered.
//
// RUN: %clang -c -fexperimental-loop-fusion -mllvm -print-pipeline-passes -O3 %s 2>&1 | FileCheck --check-prefixes=LOOP-FUSION-ON %s
// RUN: %clang -c -mllvm -print-pipeline-passes -O3 %s 2>&1 | FileCheck --check-prefixes=LOOP-FUSION-OFF %s

// LOOP-FUSION-ON: loop-fusion
// LOOP-FUSION-OFF-NOT: loop-fusion
void foo(void) {}
