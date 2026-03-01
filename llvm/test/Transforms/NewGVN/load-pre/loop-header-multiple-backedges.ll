; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
; XFAIL: *
;
; Loop header load where the loop body branches into multiple paths that
; each may clobber the pointer, then reconverge at a single latch.  The
; latch has a MemoryPhi from the different body paths.
;
; This pattern appears in SPEC deepsjeng (gen function) where
; FindFirstRemove and add_capture/add_move modify a local bitboard
; through a pointer, with conditional paths for captures vs quiet moves.

; CHECK-LABEL: @body_diamond_clobber(
; CHECK:      latch:
; CHECK:        [[RELOAD:%.*]] = load i64, ptr %p
; CHECK:      loop:
; CHECK-NEXT:   {{%.*}} = phi i64 [ [[RELOAD]], %latch ], [ %init, %entry ]

define i64 @body_diamond_clobber(ptr %p, i64 %init, i32 %sel) {
entry:
  store i64 %init, ptr %p
  br label %loop

loop:
  %v = load i64, ptr %p
  %done = icmp eq i64 %v, 0
  br i1 %done, label %exit, label %body

body:
  switch i32 %sel, label %path_default [
    i32 0, label %path0
    i32 1, label %path1
  ]

path0:
  call void @may_write(ptr %p)
  br label %latch

path1:
  call void @other_write(ptr %p)
  br label %latch

path_default:
  call void @may_write(ptr %p)
  br label %latch

latch:
  br label %loop

exit:
  ret i64 %v
}

declare void @may_write(ptr)
declare void @other_write(ptr)
