; RUN: opt < %s -passes=loop-interchange -pass-remarks=loop-interchange \
; RUN:     -disable-output 2>&1 | FileCheck -allow-empty -check-prefix=STOCK %s
; RUN: opt < %s -passes=loop-interchange -loop-interchange-chain-walk \
; RUN:     -pass-remarks=loop-interchange -disable-output 2>&1 \
; RUN:     | FileCheck -check-prefix=WALK %s

; The outermost loop has two loops beneath it, so the nest's loops do not form
; a single chain and the whole nest is discarded by default. Walking the chains
; the nest contains reaches the two-deep nest inside it, whose inner loop
; strides by a row and is worth interchanging.
;
; The two-deep nest also sits inside the outermost loop, so its dependences
; report levels counted from that loop rather than from the nest. A row built
; from those levels is longer than the nest is deep, which the padding of short
; rows cannot correct, so this also covers reading directions at the nest's own
; depth.

; STOCK-NOT: Loop interchanged
; WALK: Loop interchanged with enclosing loop

define void @f(ptr %A, ptr %B, i32 %n) {
entry:
  %guard = icmp slt i32 0, %n
  br i1 %guard, label %outer.ph, label %exit

outer.ph:
  br label %outer.body

outer.body:
  %t = phi i32 [ 0, %outer.ph ], [ %t.next, %outer.latch ]
  br label %i.body

i.body:
  %i = phi i64 [ 0, %outer.body ], [ %i.next, %i.latch ]
  br label %j.body

j.body:
  %j = phi i64 [ 0, %i.body ], [ %j.next, %j.latch ]
  %row = getelementptr inbounds [1024 x i8], ptr %A, i64 %j
  %elt = getelementptr inbounds [8 x i8], ptr %row, i64 %i
  %v = load double, ptr %elt, align 8
  %add = fadd double %v, 1.000000e+00
  store double %add, ptr %elt, align 8
  br label %j.latch

j.latch:
  %j.next = add nuw nsw i64 %j, 1
  %j.cmp = icmp ne i64 %j.next, 128
  br i1 %j.cmp, label %j.body, label %i.latch

i.latch:
  %i.next = add nuw nsw i64 %i, 1
  %i.cmp = icmp ne i64 %i.next, 128
  br i1 %i.cmp, label %i.body, label %k.ph

k.ph:
  br label %k.body

k.body:
  %k = phi i64 [ 0, %k.ph ], [ %k.next, %k.body ]
  %bel = getelementptr inbounds [8 x i8], ptr %B, i64 %k
  store double 0.000000e+00, ptr %bel, align 8
  %k.next = add nuw nsw i64 %k, 1
  %k.cmp = icmp ne i64 %k.next, 128
  br i1 %k.cmp, label %k.body, label %outer.latch

outer.latch:
  %t.next = add nuw nsw i32 %t, 1
  %t.cmp = icmp ne i32 %t.next, %n
  br i1 %t.cmp, label %outer.body, label %exit

exit:
  ret void
}
