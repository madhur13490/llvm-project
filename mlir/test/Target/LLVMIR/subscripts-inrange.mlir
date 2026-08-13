// RUN: mlir-translate -mlir-to-llvmir %s | FileCheck %s

// The `llvm.subscripts_inrange` attribute states that the subscripts of the
// array access an operation performs each stay within the dimension they
// select, and lists the extents of those dimensions from the fastest-varying to
// the slowest. It is translated to the `subscripts.inrange` metadata on the LLVM
// IR instruction, whose operands are those extents.

// CHECK-LABEL: @access_subscripts_inrange
llvm.func @access_subscripts_inrange(%ptr: !llvm.ptr, %val: f32) {
  // CHECK: = load float, ptr %{{.*}}, !subscripts.inrange ![[MD:[0-9]+]]
  %0 = llvm.load %ptr {llvm.subscripts_inrange = array<i64: 10, 20>} : !llvm.ptr -> f32
  // CHECK: store float %{{.*}}, ptr %{{.*}}, !subscripts.inrange ![[MD]]
  llvm.store %val, %ptr {llvm.subscripts_inrange = array<i64: 10, 20>} : f32, !llvm.ptr
  llvm.return
}

// An empty list states the guarantee for an array whose extents are not known
// at compile time, leaving a consumer without a shape to check it against.
// CHECK: @access_subscripts_inrange_no_extents
llvm.func @access_subscripts_inrange_no_extents(%ptr: !llvm.ptr) -> f32 {
  // CHECK: = load float, ptr %{{.*}}, !subscripts.inrange ![[EMPTY:[0-9]+]]
  %0 = llvm.load %ptr {llvm.subscripts_inrange = array<i64>} : !llvm.ptr -> f32
  llvm.return %0 : f32
}

// CHECK-DAG: ![[MD]] = !{i64 10, i64 20}
// CHECK-DAG: ![[EMPTY]] = !{}
