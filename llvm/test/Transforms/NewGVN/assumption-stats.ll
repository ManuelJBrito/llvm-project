; Test that NumGVNInstrDeleted counts correctly across assumption modes
; and matches GVN's counting. SSA copies (PredicateInfo) should NOT be counted.
;
; REQUIRES: asserts
; RUN: opt < %s -passes=gvn -stats -disable-output 2>&1 | FileCheck %s --check-prefix=GVN
; RUN: opt < %s -passes=newgvn -newgvn-assumption=optimistic -stats -disable-output 2>&1 | FileCheck %s --check-prefix=OPT
; RUN: opt < %s -passes=newgvn -newgvn-assumption=balanced -stats -disable-output 2>&1 | FileCheck %s --check-prefix=BAL
; RUN: opt < %s -passes=newgvn -newgvn-assumption=pessimistic -stats -disable-output 2>&1 | FileCheck %s --check-prefix=PESS

; Simple CSE: %y is redundant with %x.
define i32 @simple_cse(i32 %a, i32 %b) {
  %x = add i32 %a, %b
  %y = add i32 %a, %b
  %z = add i32 %x, %y
  ret i32 %z
}

; Multi-CSE: 3 redundant adds.
define i32 @multi_cse(i32 %a, i32 %b) {
entry:
  %x1 = add i32 %a, %b
  %x2 = add i32 %a, %b
  %x3 = add i32 %a, %b
  %x4 = add i32 %a, %b
  %s1 = add i32 %x1, %x2
  %s2 = add i32 %s1, %x3
  %s3 = add i32 %s2, %x4
  ret i32 %s3
}

; Diamond CSE: %y in bb3 is redundant with %x in entry.
define i32 @diamond_cse(i32 %a, i32 %b, i1 %c) {
entry:
  %x = add i32 %a, %b
  br i1 %c, label %bb1, label %bb2
bb1:
  br label %bb3
bb2:
  br label %bb3
bb3:
  %y = add i32 %a, %b
  %z = add i32 %x, %y
  ret i32 %z
}

; Constant fold: sub %a, %a folds to 0.
define i32 @const_fold(i32 %a) {
  %x = sub i32 %a, %a
  ret i32 %x
}

; All modes: 1 + 3 + 1 + 1 = 6 redundant instructions deleted.
; GVN and NewGVN should agree on the count.
; GVN: 6 gvn - Number of redundant instructions deleted
; OPT: 6 newgvn - Number of redundant instructions deleted
; BAL: 6 newgvn - Number of redundant instructions deleted
; PESS: 6 newgvn - Number of redundant instructions deleted
