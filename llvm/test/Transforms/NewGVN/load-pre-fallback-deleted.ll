; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
;
; Test that the load PRE fallback scan does not reuse loads that were
; already PRE'd and marked for deletion.  When two loads of the same
; address are both candidates for PRE, the fallback pointer-users scan
; for the second load must skip the first load (which has been replaced
; with a PHI and scheduled for erasure).  Otherwise the cleanup phase
; replaces it with poison, corrupting the second load's PHI.

; CHECK-LABEL: @test(
; CHECK-NOT: poison

define i32 @test(ptr %p, i1 %c1, i1 %c2) {
entry:
  %v0 = load i32, ptr %p, align 4
  br i1 %c1, label %call1, label %merge1

call1:
  call void @may_clobber()
  br label %merge1

merge1:
  ; First load PRE candidate: partially redundant.
  ;   From entry: available (fallback finds %v0, both see liveOnEntry)
  ;   From call1: unavailable (call may clobber %p)
  %v1 = load i32, ptr %p, align 4
  %use1 = add i32 %v0, %v1
  br i1 %c2, label %call2, label %merge2

call2:
  call void @may_clobber()
  br label %merge2

merge2:
  ; Second load PRE candidate: partially redundant.
  ;   From merge1: the fallback scan should find %v0 (not the deleted %v1).
  ;   From call2: unavailable.
  %v2 = load i32, ptr %p, align 4
  %use2 = add i32 %use1, %v2
  ret i32 %use2
}

declare void @may_clobber()
