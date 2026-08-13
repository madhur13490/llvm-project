; RUN: opt < %s -disable-output -passes="print<da>" 2>&1 | FileCheck %s

; The accesses walk a two-dimensional array whose extents are known, but the
; loops that generate the subscripts are bounded by arguments. Nothing rules out
; a subscript running past its own dimension and into the next, so the shape of
; the array cannot be recovered from the flattened address and the dependence
; has to be described conservatively.
;
; The subscripts.inrange metadata states that the subscripts do stay within
; their dimensions, which is what a language such as Fortran requires of a
; conforming program, and the shape follows from it.

@a = local_unnamed_addr global [150 x [150 x double]] zeroinitializer, align 8

; CHECK-LABEL: 'Dependence Analysis' for function 'unmarked'
; CHECK: da analyze - input [* *]
; CHECK: da analyze - anti [* *|<]
; CHECK: da analyze - output [* *]

define void @unmarked(i32 %n, i32 %m) {
entry:
  %n.pos = icmp sgt i32 %n, 0
  %m.pos = icmp sgt i32 %m, 0
  %enter = and i1 %n.pos, %m.pos
  br i1 %enter, label %preheader, label %exit

preheader:
  %nx = zext nneg i32 %n to i64
  %mx = zext nneg i32 %m to i64
  br label %outer

outer:
  %i = phi i64 [ 0, %preheader ], [ %i.next, %outer.latch ]
  %row = getelementptr inbounds nuw [8 x i8], ptr @a, i64 %i
  br label %inner

inner:
  %j = phi i64 [ 0, %outer ], [ %j.next, %inner ]
  %elt = getelementptr inbounds nuw [1200 x i8], ptr %row, i64 %j
  %v = load double, ptr %elt, align 8
  %mul = fmul double %v, 2.000000e+00
  store double %mul, ptr %elt, align 8
  %j.next = add nuw nsw i64 %j, 1
  %j.done = icmp eq i64 %j.next, %mx
  br i1 %j.done, label %outer.latch, label %inner

outer.latch:
  %i.next = add nuw nsw i64 %i, 1
  %i.done = icmp eq i64 %i.next, %nx
  br i1 %i.done, label %exit, label %outer

exit:
  ret void
}

; CHECK-LABEL: 'Dependence Analysis' for function 'marked'
; CHECK: da analyze - none!
; CHECK: da analyze - anti [0 0|<]
; CHECK: da analyze - none!

define void @marked(i32 %n, i32 %m) {
entry:
  %n.pos = icmp sgt i32 %n, 0
  %m.pos = icmp sgt i32 %m, 0
  %enter = and i1 %n.pos, %m.pos
  br i1 %enter, label %preheader, label %exit

preheader:
  %nx = zext nneg i32 %n to i64
  %mx = zext nneg i32 %m to i64
  br label %outer

outer:
  %i = phi i64 [ 0, %preheader ], [ %i.next, %outer.latch ]
  %row = getelementptr inbounds nuw [8 x i8], ptr @a, i64 %i
  br label %inner

inner:
  %j = phi i64 [ 0, %outer ], [ %j.next, %inner ]
  %elt = getelementptr inbounds nuw [1200 x i8], ptr %row, i64 %j, !subscripts.inrange !0
  %v = load double, ptr %elt, align 8
  %mul = fmul double %v, 2.000000e+00
  store double %mul, ptr %elt, align 8
  %j.next = add nuw nsw i64 %j, 1
  %j.done = icmp eq i64 %j.next, %mx
  br i1 %j.done, label %outer.latch, label %inner

outer.latch:
  %i.next = add nuw nsw i64 %i, 1
  %i.done = icmp eq i64 %i.next, %nx
  br i1 %i.done, label %exit, label %outer

exit:
  ret void
}

!0 = !{}
