// Test that an array access is marked as having subscripts that stay within
// their dimensions, which is what Fortran requires of a conforming program and
// what dependence analysis needs to recover the array's shape from a flattened
// address.

// RUN: tco --enable-array-bounds-metadata --enable-array-bounds-assumes=false \
// RUN:   %s | FileCheck %s

func.func @load_2d(%addr : !fir.ref<!fir.array<10x20xi32>>, %i : index, %j : index) -> i32 {
  %c10 = arith.constant 10 : index
  %c20 = arith.constant 20 : index
  %shape = fir.shape %c10, %c20 : (index, index) -> !fir.shape<2>
  %ref = fir.array_coor %addr(%shape) %i, %j : (!fir.ref<!fir.array<10x20xi32>>, !fir.shape<2>, index, index) -> !fir.ref<i32>
  %val = fir.load %ref : !fir.ref<i32>
  return %val : i32
}

// The metadata carries no operands, so it costs no instructions.
// CHECK-LABEL: define i32 @load_2d
// CHECK-NOT: call void @llvm.assume
// CHECK: load i32{{.*}}!subscripts.inrange

func.func @store_2d(%addr : !fir.ref<!fir.array<10x20xi32>>, %i : index, %j : index, %v : i32) {
  %c10 = arith.constant 10 : index
  %c20 = arith.constant 20 : index
  %shape = fir.shape %c10, %c20 : (index, index) -> !fir.shape<2>
  %ref = fir.array_coor %addr(%shape) %i, %j : (!fir.ref<!fir.array<10x20xi32>>, !fir.shape<2>, index, index) -> !fir.ref<i32>
  fir.store %v to %ref : !fir.ref<i32>
  return
}

// CHECK-LABEL: define void @store_2d
// CHECK: store i32{{.*}}!subscripts.inrange

// An assumed-size dimension has no extent for a subscript to stay within, and
// the metadata speaks for every dimension at once, so it is not attached here.
func.func @load_assumed_size(%addr : !fir.ref<!fir.array<?xi32>>, %idx : index) -> i32 {
  %ext = fir.assumed_size_extent : index
  %shape = fir.shape %ext : (index) -> !fir.shape<1>
  %ref = fir.array_coor %addr(%shape) %idx : (!fir.ref<!fir.array<?xi32>>, !fir.shape<1>, index) -> !fir.ref<i32>
  %val = fir.load %ref : !fir.ref<i32>
  return %val : i32
}

// CHECK-LABEL: define i32 @load_assumed_size
// CHECK-NOT: subscripts.inrange
