; RUN: opt < %s -passes=optpre -S | FileCheck %s

define i32 @TypeI_1(i32 %a) {
  %x = add i32 %a, 1
  %cmp = icmp eq i32 %x, 10
  br i1 true, label %bb1, label %bb2
bb1:
  %z = add i32 %a, 1
  ret i32 %z
bb2:
  ret i32 poison
}

define i32 @TypeI_2(i32 %a, i1 %c) {
  br i1 %c, label %bb1, label %bb2
bb1:
  %x = add i32 %a, 1
  %cmp1 = icmp eq i32 %x, 10
  br label %bb3
bb2:
  %y = add i32 %a, 1
  %cmp2 = icmp eq i32 %y, 10
  br label %bb3
bb3:
  %z = add i32 %a, 1
  ret i32 %z
}

define i32 @TypeII(i32 %a1, i32 %a2, i1 %c) {
  br i1 %c, label %bb1, label %bb2
bb1:
  %x = add i32 %a1, 1
  %cmp1 = icmp eq i32 %x, 10
  br label %bb3
bb2:
  %y = add i32 %a2, 1
  %cmp2 = icmp eq i32 %y, 10
  br label %bb3
bb3:
  %a = phi i32 [%a1, %bb1], [%a2, %bb2]
  %z = add i32 %a, 1
  ret i32 %z
}

define i32 @TypeIII(i32 %a, i1 %c) {
  br i1 %c, label %bb1, label %bb2
bb1:
  %x = add i32 %a, 1
  %cmp1 = icmp eq i32 %x, 10
  br label %bb3
bb2:
  br label %bb3
bb3:
  %z = add i32 %a, 1
  ret i32 %z
}

define i32 @TypeIV_1(i32 %a1, i32 %a2, i1 %c) {
  br i1 %c, label %bb1, label %bb2
bb1:
  %x = add i32 %a1, 1
  %cmp1 = icmp eq i32 %x, 10
  br label %bb3
bb2:
  br label %bb3
bb3:
  %a = phi i32 [%a1, %bb1], [%a2, %bb2]
  %z = add i32 %a, 1
  ret i32 %z
}

define i32 @TypeV(i32 %a) {
  %b = add i32 %a, 1
  %c = add i32 %b, 2
  %cmp1 = icmp eq i32 %c, 10
  br i1 true, label %bb1, label %bb2
bb1:
  %b1 = add i32 %a, 1
  %c1 = add i32 %b1, 2
  ret i32 %c1
bb2:
  ret i32 poison
}

define i32 @TypeVI(i32 %a1, i32 %a2, i1 %cond) {
  br i1 %cond, label %bb1, label %bb2
bb1:
  %b1 = add i32 %a1, 1
  %c1 = add i32 %b1, 2
  %cmp1 = icmp eq i32 %c1, 10
  br label %bb3
bb2:
  %b2 = add i32 %a2, 1
  %c2 = add i32 %b2, 2
  %cmp2 = icmp eq i32 %c2, 10
  br label %bb3
bb3:
  %a = phi i32 [%a1, %bb1], [%a2, %bb2]
  %b = add i32 %a, 1
  %c = add i32 %b, 2
  ret i32 %c
}

define i32 @TypeVII_1(i32 %a, i1 %cond) {
  br i1 %cond, label %bb1, label %bb2
bb1:
  %b = add i32 %a, 1
  %c = add i32 %b, 2
  %cmp1 = icmp eq i32 %c, 10
  br label %bb3
bb2:
  br label %bb3
bb3:
  %b1 = add i32 %a, 1
  %c1 = add i32 %b1, 2
  ret i32 %c1
}

define i32 @TypeVII_2(i32 %a, i1 %cond) {
  br label %bb1
bb1:
  %b = add i32 %a, 1
  %c = add i32 %b, 2
  %cmp1 = call i1 @cond(i32 %c)
  br i1 %cmp1 ,label %bb1, label %bb2
bb2:
  ret i32 %c
}

declare i1 @cond(i32)

define i32 @TypeVIII(i32 %a1, i32 %a2, i1 %cond) {
  br i1 %cond, label %bb1, label %bb2
bb1:
  %b1 = add i32 %a1, 1
  %c1 = add i32 %b1, 2
  %cmp1 = icmp eq i32 %c1, 10
  br label %bb3
bb2:
  br label %bb3
bb3:
  %a = phi i32 [%a1, %bb1], [%a2, %bb2]
  %b = add i32 %a, 1
  %c = add i32 %b, 2
  ret i32 %c
}
