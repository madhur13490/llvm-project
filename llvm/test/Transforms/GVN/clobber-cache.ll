; Demonstrate the GVN clobber cache servicing real hits.
;
; Under the MSSA-GVN value-numbering path, every load and every
; readonly call triggers addMemoryStateToExp, which asks the skip-self
; MSSA walker for a clobbering access. The clobber cache sits at that
; call site and memoizes (Instruction*) -> (MemoryAccess*).
;
; To drive the cache to hit, we need (a) MSSA-GVN on, (b) GVN's outer
; fixpoint to iterate at least twice so that the second iteration
; re-asks for the same clobbers after cleanupGlobalSets() has wiped
; VN's value-numbering table, and (c) enough load-like work that the
; first iteration leaves more to do (which happens naturally because
; the first iteration of GVN tends to insert new PHIs that the second
; iteration commons up -- see the comment on processBlock).
;
; REQUIRES: asserts
; RUN: opt -passes='gvn<memoryssa;no-memdep>' \
; RUN:     -gvn-clobber-cache=1 -stats -S < %s \
; RUN:   2>&1 | FileCheck %s
;
; The cache must record both hits and misses on this input. We do not
; check an exact number (which could drift with MSSA heuristics), only
; that the counters are non-zero.
; CHECK: gvn{{[[:space:]]+}}- Number of GVN MSSA clobber queries served from cache
; CHECK: gvn{{[[:space:]]+}}- Number of GVN MSSA clobber queries that missed the cache

declare i32 @foo(ptr) memory(read)

; The chain of read-only calls on %p forces MSSA-GVN's value-numbering
; path (addMemoryStateToExp) into the cache, and the redundant calls
; force GVN to delete some of them -- which makes iterateOnFunction()
; return true and the outer fixpoint run a second iteration. The
; second iteration re-numbers the surviving instructions and must
; query the same clobbering MemoryAccess for them. Those re-queries
; are the cache hits.

define i32 @multi_iter(ptr %p, i1 %c1, i1 %c2) {
entry:
  br i1 %c1, label %a, label %b

a:
  %aa1 = call i32 @foo(ptr %p)
  %aa2 = call i32 @foo(ptr %p)
  %aa3 = call i32 @foo(ptr %p)
  %ra = add i32 %aa1, %aa2
  %ra2 = add i32 %ra, %aa3
  br label %m

b:
  %bb1 = call i32 @foo(ptr %p)
  %bb2 = call i32 @foo(ptr %p)
  %bb3 = call i32 @foo(ptr %p)
  %rb = add i32 %bb1, %bb2
  %rb2 = add i32 %rb, %bb3
  br label %m

m:
  %mm = phi i32 [ %ra2, %a ], [ %rb2, %b ]
  br i1 %c2, label %x, label %y

x:
  %xx1 = call i32 @foo(ptr %p)
  %xx2 = call i32 @foo(ptr %p)
  %rx = add i32 %xx1, %xx2
  br label %j

y:
  %yy1 = call i32 @foo(ptr %p)
  %yy2 = call i32 @foo(ptr %p)
  %ry = add i32 %yy1, %yy2
  br label %j

j:
  %jj = phi i32 [ %rx, %x ], [ %ry, %y ]
  %jl1 = call i32 @foo(ptr %p)
  %jl2 = call i32 @foo(ptr %p)
  %rj = add i32 %jl1, %jl2
  %add = add i32 %mm, %jj
  %all1 = add i32 %add, %rj
  ret i32 %all1
}
