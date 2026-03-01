; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
; XFAIL: *
;
; Two consecutive loops that each load from the same pointer in their
; headers, with calls that may clobber the pointer in each loop body.
;
; GVN PREs both header loads: for loop1 the preheader value comes from the
; store in entry; for loop2 the preheader value comes from the exit of
; loop1 (the last PHI value, known to be 0).
;
; NewGVN misses both due to backedge rejection in standard PRE.

; CHECK-LABEL: @two_loops(
; CHECK:      body1:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   [[R1:%.*]] = load i64, ptr %p
; CHECK:      loop1:
; CHECK-NEXT:   {{%.*}} = phi i64 [ [[R1]], %body1 ], [ %init, %entry ]
; CHECK:      body2:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   [[R2:%.*]] = load i64, ptr %p
; CHECK:      loop2:
; CHECK-NEXT:   {{%.*}} = phi i64

define i64 @two_loops(ptr %p, i64 %init) {
entry:
  store i64 %init, ptr %p
  br label %loop1

loop1:
  %v1 = load i64, ptr %p
  %done1 = icmp eq i64 %v1, 0
  br i1 %done1, label %between, label %body1

body1:
  call void @may_write(ptr %p)
  br label %loop1

between:
  br label %loop2

loop2:
  %v2 = load i64, ptr %p
  %done2 = icmp eq i64 %v2, 0
  br i1 %done2, label %exit, label %body2

body2:
  call void @may_write(ptr %p)
  br label %loop2

exit:
  ret i64 %v2
}

declare void @may_write(ptr)
