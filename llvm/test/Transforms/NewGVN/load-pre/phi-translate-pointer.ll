; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
; XFAIL: *
;
; Load whose pointer is a PHI.  Per-predecessor phi-translation reveals
; the value is available on one edge (via a store to the translated pointer)
; and unavailable on the other.
;
; GVN phi-translates the pointer in its availability analysis and inserts
; a reload on the unavailable edge using the translated pointer.
; NewGVN queries MSSA with the PHI pointer directly, which gives imprecise
; results because AA cannot resolve the PHI.

; CHECK-LABEL: @phi_ptr_one_avail(
; CHECK:      right:
; CHECK:        [[R:%.*]] = load i64, ptr %p2
; CHECK:      merge:
; CHECK-NEXT:   {{%.*}} = phi i64 [ %val, %left ], [ [[R]], %right ]

define i64 @phi_ptr_one_avail(ptr noalias %p1, ptr noalias %p2, i64 %val, i1 %c) {
entry:
  store i64 %val, ptr %p1
  br i1 %c, label %left, label %right

left:
  ; p1 available via entry store
  br label %merge

right:
  ; p2 has no store — unavailable
  br label %merge

merge:
  %p = phi ptr [ %p1, %left ], [ %p2, %right ]
  %v = load i64, ptr %p
  ret i64 %v
}

; Variation: both pointers have stores but one path clobbers its pointer.
; After phi-translation, left has %p1 available (entry store, no clobber)
; and right has %p2 unavailable (clobbered by call).

; CHECK-LABEL: @phi_ptr_clobber_one(
; CHECK:      right:
; CHECK:        call void @may_write(ptr %p2)
; CHECK-NEXT:   [[R2:%.*]] = load i64, ptr %p2
; CHECK:      merge:
; CHECK-NEXT:   {{%.*}} = phi i64 [ %v1, %left ], [ [[R2]], %right ]

define i64 @phi_ptr_clobber_one(ptr noalias %p1, ptr noalias %p2, i64 %v1, i64 %v2, i1 %c) {
entry:
  store i64 %v1, ptr %p1
  store i64 %v2, ptr %p2
  br i1 %c, label %left, label %right

left:
  ; p1 still holds %v1 from entry
  br label %merge

right:
  call void @may_write(ptr %p2)
  br label %merge

merge:
  %p = phi ptr [ %p1, %left ], [ %p2, %right ]
  %v = load i64, ptr %p
  ret i64 %v
}

declare void @may_write(ptr)
