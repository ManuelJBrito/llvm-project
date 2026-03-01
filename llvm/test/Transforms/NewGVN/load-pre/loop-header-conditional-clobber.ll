; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
; XFAIL: *
;
; Loop header load where only one path through the loop body clobbers the
; loaded pointer.  GVN performs two rounds of PRE:
;  1) PRE of the header load — inserts reload on backedge (latch), PHI in header.
;  2) PRE of the backedge reload — inserts reload only in clobber_path,
;     PHI in latch for the two body paths.
;
; NewGVN rejects backedges in standard PRE.

; CHECK-LABEL: @conditional_clobber(
; CHECK:      clobber_path:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   [[RELOAD:%.*]] = load i64, ptr %p
; CHECK:      latch:
; CHECK-NEXT:   [[LATCH_PHI:%.*]] = phi i64
; CHECK:      loop:
; CHECK-NEXT:   [[HDR_PHI:%.*]] = phi i64

define i64 @conditional_clobber(ptr %p, i64 %init, i1 %flag) {
entry:
  store i64 %init, ptr %p
  br label %loop

loop:
  %v = load i64, ptr %p
  %done = icmp eq i64 %v, 0
  br i1 %done, label %exit, label %body

body:
  br i1 %flag, label %clobber_path, label %noclobber

clobber_path:
  call void @may_write(ptr %p)
  br label %latch

noclobber:
  br label %latch

latch:
  br label %loop

exit:
  ret i64 %v
}

declare void @may_write(ptr)
