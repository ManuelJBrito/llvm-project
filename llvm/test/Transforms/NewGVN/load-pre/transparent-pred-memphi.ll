; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
; XFAIL: *
;
; Transparent predecessor with unresolvable MemoryPhi.
;
; A diamond (one path stores, the other calls may_write) merges into
; a "transparent" block with no memory ops.  The load's block has two
; predecessors: the transparent block and another block with a call.
;
; Neither GVN nor NewGVN can handle this.  GVN's memdep does not walk
; through mid's MemoryPhi into the diamond arms — it treats mid as a
; single predecessor with an unresolvable clobber.  Both passes see
; NumUnavail = 2 (mid + direct would need deeper analysis) and bail.
;
; Fixing this would require recursive MemoryPhi resolution: walking
; through transparent blocks to decompose a single MemoryPhi predecessor
; into its constituent paths.

; We want the load eliminated from 'target'.
; CHECK-LABEL: @transparent_memphi(
; CHECK:      clobber:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   {{.*}} = load i64, ptr %p
; CHECK:      target:
; CHECK-NEXT:   {{%.*}} = phi i64

define i64 @transparent_memphi(ptr %p, i64 %val, i1 %c1, i1 %c2) {
entry:
  store i64 %val, ptr %p
  br i1 %c1, label %store_path, label %clobber

store_path:
  ; %p still holds %val — available.
  br label %mid

clobber:
  call void @may_write(ptr %p)
  br label %mid

mid:
  ; MemoryPhi: [entry store from store_path, call def from clobber].
  ; MSSA walker can't resolve — returns MemoryPhi.
  ; No memory ops here — transparent block.
  br i1 %c2, label %target, label %direct

direct:
  ; %p holds %val from the entry store (no clobber on this path).
  br label %target

target:
  ; Preds: mid (MemoryPhi → unavail), direct (entry store → avail).
  ; NewGVN: NumUnavail = 1 for mid, but PredClobber = MemoryPhi → no value.
  ;
  ; GVN walks through mid into store_path (avail: %val) and clobber
  ; (unavail).  With direct (avail: %val), total = 2 avail + 1 unavail.
  ; GVN inserts a reload in clobber and builds a PHI.
  %v = load i64, ptr %p
  ret i64 %v
}

declare void @may_write(ptr)
