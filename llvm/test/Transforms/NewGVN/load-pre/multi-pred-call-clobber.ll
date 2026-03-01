; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
; XFAIL: *
;
; Load PRE where 2 out of 3 predecessors have call clobbers.
; NumUnavail = 2 → standard PRE bails (requires NumUnavail <= 1).
;
; Neither GVN nor NewGVN can handle this in isolation.  Both require
; NumUnavail <= 1.  In SPEC, GVN handles similar patterns through
; iteration: first-pass eliminations simplify the IR so that subsequent
; passes see fewer clobbers and NumUnavail drops to 1.

; CHECK-LABEL: @multi_call_clobber(
; CHECK:      clobber1:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   {{.*}} = load i64, ptr %p
; CHECK:      clobber2:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   {{.*}} = load i64, ptr %p
; CHECK:      merge:
; CHECK-NEXT:   {{%.*}} = phi i64

define i64 @multi_call_clobber(ptr %p, i64 %val, i32 %sel) {
entry:
  store i64 %val, ptr %p
  switch i32 %sel, label %clean [
    i32 0, label %clobber1
    i32 1, label %clobber2
  ]

clobber1:
  call void @may_write(ptr %p)
  br label %merge

clobber2:
  call void @may_write(ptr %p)
  br label %merge

clean:
  ; %p still holds %val — available.
  br label %merge

merge:
  %v = load i64, ptr %p
  ret i64 %v
}

declare void @may_write(ptr)
