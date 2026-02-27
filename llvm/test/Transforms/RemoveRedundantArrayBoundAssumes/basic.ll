; RUN: opt -S -passes=remove-redundant-array-bound-assumes < %s | FileCheck %s

; Two pairs of assumes checking 1 <= %iv <= 54 with the same operands.
; The second pair is redundant and should be removed.
define void @duplicate_assumes(i64 %iv, ptr %arr) {
; CHECK-LABEL: define void @duplicate_assumes(
; CHECK-SAME: i64 [[IV:%.*]], ptr [[ARR:%.*]]) {
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sle i64 [[IV]], 54
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]]), !llvm.array.bounds !0
; CHECK-NEXT:    [[GEP1:%.*]] = getelementptr double, ptr [[ARR]], i64 [[IV]]
; CHECK-NEXT:    [[LOAD1:%.*]] = load double, ptr [[GEP1]], align 8
; CHECK-NEXT:    [[GEP2:%.*]] = getelementptr double, ptr [[ARR]], i64 [[IV]]
; CHECK-NEXT:    store double [[LOAD1]], ptr [[GEP2]], align 8
; CHECK-NEXT:    ret void
;
  %cmp1 = icmp sge i64 %iv, 1
  %cmp2 = icmp sle i64 %iv, 54
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  %gep1 = getelementptr double, ptr %arr, i64 %iv
  %load1 = load double, ptr %gep1, align 8
  %cmp3 = icmp sge i64 %iv, 1
  %cmp4 = icmp sle i64 %iv, 54
  call void @llvm.assume(i1 %cmp3), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp4), !llvm.array.bounds !0
  %gep2 = getelementptr double, ptr %arr, i64 %iv
  store double %load1, ptr %gep2, align 8
  ret void
}

; Three copies of the same assume pair. Only the first should survive.
define void @triple_duplicate(i64 %iv, ptr %arr) {
; CHECK-LABEL: define void @triple_duplicate(
; CHECK-SAME: i64 [[IV:%.*]], ptr [[ARR:%.*]]) {
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sle i64 [[IV]], 100
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]]), !llvm.array.bounds !0
; CHECK-NEXT:    [[GEP1:%.*]] = getelementptr double, ptr [[ARR]], i64 [[IV]]
; CHECK-NEXT:    [[V1:%.*]] = load double, ptr [[GEP1]], align 8
; CHECK-NEXT:    [[GEP2:%.*]] = getelementptr double, ptr [[ARR]], i64 [[IV]]
; CHECK-NEXT:    [[V2:%.*]] = load double, ptr [[GEP2]], align 8
; CHECK-NEXT:    [[GEP3:%.*]] = getelementptr double, ptr [[ARR]], i64 [[IV]]
; CHECK-NEXT:    [[V3:%.*]] = load double, ptr [[GEP3]], align 8
; CHECK-NEXT:    ret void
;
  %cmp1 = icmp sge i64 %iv, 1
  %cmp2 = icmp sle i64 %iv, 100
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  %gep1 = getelementptr double, ptr %arr, i64 %iv
  %v1 = load double, ptr %gep1, align 8
  %cmp3 = icmp sge i64 %iv, 1
  %cmp4 = icmp sle i64 %iv, 100
  call void @llvm.assume(i1 %cmp3), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp4), !llvm.array.bounds !0
  %gep2 = getelementptr double, ptr %arr, i64 %iv
  %v2 = load double, ptr %gep2, align 8
  %cmp5 = icmp sge i64 %iv, 1
  %cmp6 = icmp sle i64 %iv, 100
  call void @llvm.assume(i1 %cmp5), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp6), !llvm.array.bounds !0
  %gep3 = getelementptr double, ptr %arr, i64 %iv
  %v3 = load double, ptr %gep3, align 8
  ret void
}

; Different upper bounds (54 vs 32) produce distinct keys, so (sle,32) is kept.
; But (sge,1) appears twice so the second is removed.
define void @different_ivs(i64 %iv1, i64 %iv2, ptr %arr) {
; CHECK-LABEL: define void @different_ivs(
; CHECK-SAME: i64 [[IV1:%.*]], i64 [[IV2:%.*]], ptr [[ARR:%.*]]) {
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IV1]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sle i64 [[IV1]], 54
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]]), !llvm.array.bounds !0
; CHECK-NEXT:    [[CMP4:%.*]] = icmp sle i64 [[IV2]], 32
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP4]]), !llvm.array.bounds !0
; CHECK-NEXT:    ret void
;
  %cmp1 = icmp sge i64 %iv1, 1
  %cmp2 = icmp sle i64 %iv1, 54
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  %cmp3 = icmp sge i64 %iv2, 1
  %cmp4 = icmp sle i64 %iv2, 32
  call void @llvm.assume(i1 %cmp3), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp4), !llvm.array.bounds !0
  ret void
}

; Assumes without !llvm.array.bounds metadata should not be touched.
define void @no_metadata(i64 %iv) {
; CHECK-LABEL: define void @no_metadata(
; CHECK-SAME: i64 [[IV:%.*]]) {
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]])
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]])
; CHECK-NEXT:    ret void
;
  %cmp1 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp1)
  %cmp2 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp2)
  ret void
}

; Mixed: one assume with metadata (kept), duplicate with metadata (removed),
; one without metadata (kept).
define void @mixed_metadata(i64 %iv) {
; CHECK-LABEL: define void @mixed_metadata(
; CHECK-SAME: i64 [[IV:%.*]]) {
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    [[CMP3:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP3]])
; CHECK-NEXT:    ret void
;
  %cmp1 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  %cmp2 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  %cmp3 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp3)
  ret void
}

; No duplicates — nothing should be removed.
define void @no_duplicates(i64 %iv) {
; CHECK-LABEL: define void @no_duplicates(
; CHECK-SAME: i64 [[IV:%.*]]) {
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sle i64 [[IV]], 54
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]]), !llvm.array.bounds !0
; CHECK-NEXT:    ret void
;
  %cmp1 = icmp sge i64 %iv, 1
  %cmp2 = icmp sle i64 %iv, 54
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  ret void
}

; Assumes across two functions — each function is independent.
; Duplicates within each function are removed, but the same pattern
; in different functions is kept.
define void @func_a(i64 %iv) {
; CHECK-LABEL: define void @func_a(
; CHECK-SAME: i64 [[IV:%.*]]) {
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    ret void
;
  %cmp1 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  %cmp2 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  ret void
}

define void @func_b(i64 %iv) {
; CHECK-LABEL: define void @func_b(
; CHECK-SAME: i64 [[IV:%.*]]) {
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IV]], 1
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    ret void
;
  %cmp1 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  %cmp2 = icmp sge i64 %iv, 1
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  ret void
}

; Two subscript expressions derived from the same load, both checked against
; the same bounds [1, 1000]. Only the first pair of assumes should survive.
; Dead instructions feeding the removed assumes are recursively cleaned up.
define void @same_load_different_subscripts(ptr %dimptr, i32 %a, i32 %b, i32 %c, i32 %d) {
; CHECK-LABEL: define void @same_load_different_subscripts(
; CHECK-SAME: ptr [[DIMPTR:%.*]], i32 [[A:%.*]], i32 [[B:%.*]], i32 [[C:%.*]], i32 [[D:%.*]]) {
; CHECK-NEXT:    [[DIM:%.*]] = load i32, ptr [[DIMPTR]], align 4
; CHECK-NEXT:    [[MUL1:%.*]] = mul nsw i32 [[DIM]], [[A]]
; CHECK-NEXT:    [[ADD1:%.*]] = add nsw i32 [[MUL1]], [[B]]
; CHECK-NEXT:    [[IDX1:%.*]] = sext i32 [[ADD1]] to i64
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IDX1]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sle i64 [[IDX1]], 1000
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]]), !llvm.array.bounds !0
; CHECK-NEXT:    ret void
;
  %dim = load i32, ptr %dimptr, align 4
  %mul1 = mul nsw i32 %dim, %a
  %add1 = add nsw i32 %mul1, %b
  %idx1 = sext i32 %add1 to i64
  %mul2 = mul nsw i32 %dim, %c
  %add2 = add nsw i32 %mul2, %d
  %idx2 = sext i32 %add2 to i64
  %cmp1 = icmp sge i64 %idx1, 1
  %cmp2 = icmp sle i64 %idx1, 1000
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  %cmp3 = icmp sge i64 %idx2, 1
  %cmp4 = icmp sle i64 %idx2, 1000
  call void @llvm.assume(i1 %cmp3), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp4), !llvm.array.bounds !0
  ret void
}

; Different loads but same constant bounds (sge 1, sle 100). The second pair
; is removed because the key is purely (predicate, constant).
define void @different_loads(ptr %dimptr1, ptr %dimptr2, i32 %a) {
; CHECK-LABEL: define void @different_loads(
; CHECK-SAME: ptr [[DIMPTR1:%.*]], ptr [[DIMPTR2:%.*]], i32 [[A:%.*]]) {
; CHECK-NEXT:    [[DIM1:%.*]] = load i32, ptr [[DIMPTR1]], align 4
; CHECK-NEXT:    [[IDX1:%.*]] = sext i32 [[DIM1]] to i64
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IDX1]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sle i64 [[IDX1]], 100
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]]), !llvm.array.bounds !0
; CHECK-NEXT:    ret void
;
  %dim1 = load i32, ptr %dimptr1, align 4
  %idx1 = sext i32 %dim1 to i64
  %cmp1 = icmp sge i64 %idx1, 1
  %cmp2 = icmp sle i64 %idx1, 100
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  %dim2 = load i32, ptr %dimptr2, align 4
  %idx2 = sext i32 %dim2 to i64
  %cmp3 = icmp sge i64 %idx2, 1
  %cmp4 = icmp sle i64 %idx2, 100
  call void @llvm.assume(i1 %cmp3), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp4), !llvm.array.bounds !0
  ret void
}

; Same load, same bounds, three subscript expressions. Only the first pair kept.
define void @same_load_triple(ptr %dimptr, i32 %a, i32 %b, i32 %c) {
; CHECK-LABEL: define void @same_load_triple(
; CHECK-SAME: ptr [[DIMPTR:%.*]], i32 [[A:%.*]], i32 [[B:%.*]], i32 [[C:%.*]]) {
; CHECK-NEXT:    [[DIM:%.*]] = load i32, ptr [[DIMPTR]], align 4
; CHECK-NEXT:    [[IDX1:%.*]] = sext i32 [[DIM]] to i64
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IDX1]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sle i64 [[IDX1]], 54
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]]), !llvm.array.bounds !0
; CHECK-NEXT:    ret void
;
  %dim = load i32, ptr %dimptr, align 4
  %idx1 = sext i32 %dim to i64
  %cmp1 = icmp sge i64 %idx1, 1
  %cmp2 = icmp sle i64 %idx1, 54
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  %mul2 = mul nsw i32 %dim, %a
  %add2 = add nsw i32 %mul2, %b
  %idx2 = sext i32 %add2 to i64
  %cmp3 = icmp sge i64 %idx2, 1
  %cmp4 = icmp sle i64 %idx2, 54
  call void @llvm.assume(i1 %cmp3), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp4), !llvm.array.bounds !0
  %mul3 = mul nsw i32 %dim, %b
  %add3 = add nsw i32 %mul3, %c
  %idx3 = sext i32 %add3 to i64
  %cmp5 = icmp sge i64 %idx3, 1
  %cmp6 = icmp sle i64 %idx3, 54
  call void @llvm.assume(i1 %cmp5), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp6), !llvm.array.bounds !0
  ret void
}

; Three independent loads checking the same bounds [1, 54]. Only the first
; pair of assumes survives; the other two pairs and their dead chains are removed.
define void @three_loads_same_bounds(ptr %p1, ptr %p2, ptr %p3) {
; CHECK-LABEL: define void @three_loads_same_bounds(
; CHECK-SAME: ptr [[P1:%.*]], ptr [[P2:%.*]], ptr [[P3:%.*]]) {
; CHECK-NEXT:    [[V1:%.*]] = load i32, ptr [[P1]], align 4
; CHECK-NEXT:    [[IDX1:%.*]] = sext i32 [[V1]] to i64
; CHECK-NEXT:    [[CMP1:%.*]] = icmp sge i64 [[IDX1]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sle i64 [[IDX1]], 54
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP1]]), !llvm.array.bounds !0
; CHECK-NEXT:    call void @llvm.assume(i1 [[CMP2]]), !llvm.array.bounds !0
; CHECK-NEXT:    ret void
;
  %v1 = load i32, ptr %p1, align 4
  %idx1 = sext i32 %v1 to i64
  %v2 = load i32, ptr %p2, align 4
  %idx2 = sext i32 %v2 to i64
  %v3 = load i32, ptr %p3, align 4
  %idx3 = sext i32 %v3 to i64
  %cmp1 = icmp sge i64 %idx1, 1
  %cmp2 = icmp sle i64 %idx1, 54
  call void @llvm.assume(i1 %cmp1), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp2), !llvm.array.bounds !0
  %cmp3 = icmp sge i64 %idx2, 1
  %cmp4 = icmp sle i64 %idx2, 54
  call void @llvm.assume(i1 %cmp3), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp4), !llvm.array.bounds !0
  %cmp5 = icmp sge i64 %idx3, 1
  %cmp6 = icmp sle i64 %idx3, 54
  call void @llvm.assume(i1 %cmp5), !llvm.array.bounds !0
  call void @llvm.assume(i1 %cmp6), !llvm.array.bounds !0
  ret void
}

!0 = !{!"array bounds metadata"}
