; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
; XFAIL: *
;
; GEP index phi-translation for load redundancy elimination.
;
; The load pointer is a GEP whose index is a PHI.  GVN phi-translates
; the GEP per-predecessor, resolving each to a concrete pointer that
; matches a dominating store:
;   left  → GEP(%arr, 0) → store 42 (available)
;   right → GEP(%arr, 1) → store 99 (available)
;
; NewGVN does not phi-translate GEP indices for availability checking,
; so the load remains.

; CHECK-LABEL: @gep_phi_translate(
; CHECK:      merge:
; CHECK-NEXT:   {{%.*}} = phi i32 [ 42, %left ], [ 99, %right ]
; CHECK-NOT:    load

define i32 @gep_phi_translate(ptr %arr, i1 %c) {
entry:
  %gep0 = getelementptr i32, ptr %arr, i64 0
  store i32 42, ptr %gep0
  %gep1 = getelementptr i32, ptr %arr, i64 1
  store i32 99, ptr %gep1
  br i1 %c, label %left, label %right

left:
  br label %merge

right:
  br label %merge

merge:
  %idx = phi i64 [ 0, %left ], [ 1, %right ]
  %gep = getelementptr i32, ptr %arr, i64 %idx
  %v = load i32, ptr %gep
  ret i32 %v
}
