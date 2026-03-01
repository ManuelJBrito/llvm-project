; RUN: opt -S -passes=newgvn -newgvn-enable-pre=true -newgvn-enable-load-pre=true < %s | FileCheck %s
;
; Loop header load where the loop body contains a call that may clobber the
; loaded pointer.  The value is available from the preheader (via a store)
; and unavailable from the backedge (call may write).
;
; Standard PRE inserts a reload after the call on the backedge and creates
; a PHI in the header.

; CHECK-LABEL: @simple(
; CHECK:      loop:
; CHECK-NEXT:   {{%.*}} = phi i64 [ [[RELOAD:%.*]], %body ], [ %init, %entry ]
; CHECK:      body:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   [[RELOAD]] = load i64, ptr %p

define i64 @simple(ptr %p, i64 %init) {
entry:
  store i64 %init, ptr %p
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

; Same pattern but the store to %p is not in the immediate preheader —
; it is in a grandparent block.  The value must still flow through.

; CHECK-LABEL: @store_in_grandparent(
; CHECK:      loop:
; CHECK-NEXT:   {{%.*}} = phi i64 [ [[RELOAD2:%.*]], %body ], [ %init, %preheader ]
; CHECK:      body:
; CHECK:        call void @may_write(ptr %p)
; CHECK-NEXT:   [[RELOAD2]] = load i64, ptr %p

define i64 @store_in_grandparent(ptr %p, i64 %init, i1 %c) {
entry:
  store i64 %init, ptr %p
  br i1 %c, label %preheader, label %early_exit

early_exit:
  ret i64 0

preheader:
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
