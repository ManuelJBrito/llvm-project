; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
; XFAIL: *
;
; Load PRE where a predecessor's incoming MemoryAccess is a MemoryPhi
; that the MSSA walker cannot resolve through.  The walker returns the
; MemoryPhi as the "clobber", and NewGVN cannot extract an available
; value from it.
;
; Neither GVN nor NewGVN can handle this: the loop header load has
; 2 unavailable predecessors (preheader via unresolvable MemoryPhi +
; backedge via call clobber), exceeding the NumUnavail <= 1 limit.
; Fixing this would require recursive/nested PRE across the MemoryPhi
; diamond.

; The preheader feeds through a MemoryPhi (from a diamond where one
; path calls an opaque function).  The call doesn't actually clobber %p
; at runtime, but MSSA conservatively reports it as a clobber.  Since
; the two MemoryPhi incoming values disagree, the walker returns the
; MemoryPhi — leaving the preheader predecessor "unavailable" even
; though the entry store dominates all paths to it.
;
; With two unavailable predecessors (preheader + backedge), both
; GVN and NewGVN give up (NumUnavail > 1).

; CHECK-LABEL: @memphi_preheader(
; CHECK:      body:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   [[R:%.*]] = load i64, ptr %p
; CHECK:      loop:
; CHECK-NEXT:   {{%.*}} = phi i64

define i64 @memphi_preheader(ptr %p, i64 %init, i1 %c) {
entry:
  store i64 %init, ptr %p
  br i1 %c, label %clobber, label %no_clobber

clobber:
  call void @may_write(ptr %p)
  br label %preheader

no_clobber:
  br label %preheader

preheader:
  ; MemoryPhi: from clobber (call def) vs no_clobber (entry store).
  ; MSSA walker may return this MemoryPhi as the "clobber" for the
  ; preheader→loop edge.
  br label %loop

loop:
  %v = load i64, ptr %p
  %done = icmp eq i64 %v, 0
  br i1 %done, label %exit, label %body

body:
  call void @may_write(ptr %p)
  br label %loop

exit:
  ret i64 %v
}

declare void @may_write(ptr)
