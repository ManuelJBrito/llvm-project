# GVN vs NewGVN Test Differences

This directory contains GVN lit tests adapted for NewGVN. This document tracks
cases where NewGVN produces different results from GVN, with minimal reproducers
and explanations.

## Summary of Difference Categories

| Category | NewGVN Behavior | GVN Behavior |
|---|---|---|
| Block merging | Does not merge blocks | Merges single-pred/single-succ blocks |
| Cross-type load forwarding | Does not forward | Forwards loads of different types from stores |
| PHI translation | Does not do PHI translation | Does PHI translation for load elimination |
| Unreachable blocks | Replaces content with poison | Uses MemDep to handle unreachable paths |
| Uninitialized alloca | Keeps load | Replaces with undef |
| Assume propagation | Partial (direct uses only) | Full (negations, equality) |
| Equality propagation | Limited | Propagates from trunc nuw, etc. |
| Dead code elimination | Implicit DCE (removes unused instrs) | No implicit DCE |
| Load PRE | Not supported | Supported via -enable-load-pre |

---

## Individual Test Differences

### basic.ll
**Difference:** Block merging
**Reproducer:**
```llvm
define i32 @main() {
block1:
  %z1 = bitcast i32 0 to i32
  br label %block2
block2:
  %z2 = bitcast i32 0 to i32
  ret i32 %z2
}
```
**GVN:** Merges block1 and block2 into a single block, returns `ret i32 0`.
**NewGVN:** Eliminates the redundant bitcast but keeps both blocks.
**Reason:** NewGVN does not perform block merging (SimplifyCFG-like optimization).

### addrspacecast.ll
**Difference:** Block merging
**Reproducer:**
```llvm
define ptr addrspace(1) @addrspacecast(ptr %ptr) {
block1:
  %z1 = addrspacecast ptr %ptr to ptr addrspace(1)
  store ptr addrspace(1) %z1, ptr undef
  br label %block2
block2:
  %z2 = addrspacecast ptr %ptr to ptr addrspace(1)
  ret ptr addrspace(1) %z2
}
```
**GVN:** Merges blocks, eliminates %z2, uses %z1 directly.
**NewGVN:** Eliminates %z2 (uses %z1) but keeps the block structure.
**Reason:** Same as basic.ll — NewGVN does not merge blocks.

### 2008-02-12-UndefLoad.ll
**Difference:** Uninitialized alloca load elimination
**Reproducer:**
```llvm
%struct.anon = type { i32, i8, i8, i8, i8 }
define i32 @a() {
entry:
  %c = alloca %struct.anon
  %tmp1 = getelementptr i32, ptr %c, i32 1
  %tmp2 = load i32, ptr %tmp1, align 4  ; load from uninitialized alloca
  %tmp3 = or i32 %tmp2, 11
  ...
}
```
**GVN:** Uses MemDep to detect the load reads from uninitialized alloca, eliminates the load (CHECK-NOT: load).
**NewGVN:** Keeps the load from uninitialized alloca.
**Reason:** NewGVN does not use MemDep and doesn't have the "load from uninitialized alloca → undef" optimization.

### pr10820.ll
**Difference:** Cross-type load forwarding (store i32, load i31)
**Reproducer:**
```llvm
@g = external global i31
define void @main() {
  store i32 402662078, ptr @g, align 8
  %0 = load i31, ptr @g, align 8
  store i31 %0, ptr undef, align 1
  unreachable
}
```
**GVN:** Forwards the i32 store value to the i31 load (truncating the constant).
**NewGVN:** Keeps the i31 load as-is.
**Reason:** NewGVN does not do cross-type load forwarding from prior stores.

### pr24397.ll
**Difference:** Cross-type load forwarding (ptr → i64) + unreachable block handling
**Reproducer:**
```llvm
define i64 @foo(ptr %arrayidx) {
entry:
  %p = load ptr, ptr %arrayidx, align 8
  br label %BB2
entry2:                          ; No predecessors!
  br label %BB2
BB2:
  %load = load i64, ptr %arrayidx, align 8
  ret i64 %load
}
```
**GVN:** Forwards ptr→i64 via ptrtoint, replaces entry2 content.
**NewGVN:** Replaces unreachable entry2 with poison store, keeps the i64 load.
**Reason:** NewGVN does not do cross-type load forwarding; also handles unreachable blocks differently.

### big-endian.ll
**Difference:** Cross-type load forwarding (store i8, load i1 on big-endian)
**Reproducer:**
```llvm
target datalayout = "E-m:e-i64:64-n32:64"
define i1 @test2(i8 %V, ptr %P) {
  store i8 %V, ptr %P
  %A = load i1, ptr %P
  ret i1 %A
}
```
**GVN:** Forwards the i8 store to the i1 load via `trunc i8 %V to i1`.
**NewGVN:** Keeps the i1 load as-is.
**Reason:** NewGVN does not do cross-type store-to-load forwarding.

### load-from-unreachable-predecessor.ll
**Difference:** Unreachable block handling
**Reproducer:**
```llvm
define i32 @f(ptr %f) {
bb0:
  %bar = load ptr, ptr %f
  br label %bb2
bb1:                              ; unreachable
  %zed = load ptr, ptr %f
  br i1 false, label %bb1, label %bb2
bb2:
  %foo = phi ptr [ null, %bb0 ], [ %zed, %bb1 ]
  %storemerge = load i32, ptr %foo
  ret i32 %storemerge
}
```
**GVN:** Eliminates dead load in bb0, keeps PHI with proper values, loads from correct pointer.
**NewGVN:** Replaces bb1 content with poison store, simplifies PHI to constant null, loads from null.
**Reason:** NewGVN handles unreachable predecessors by replacing content with poison, allowing PHI simplification.

### load-dead-block.ll
**Difference:** Load forwarding through dead branches + unreachable blocks
**Reproducer:**
```llvm
define i64 @test(ptr noalias %p, ptr noalias %q) {
entry:
  store ptr %q, ptr %p
  br i1 false, label %if, label %merge
if:
  call void @clobber(ptr %p)
  br label %merge
merge:
  %q2 = load ptr, ptr %p     ; GVN forwards to %q
  store i64 1, ptr %q2
  %v = load i64, ptr %q      ; GVN forwards to 1
  %q3 = getelementptr i64, ptr %q, i64 %v  ; GVN uses offset 1
  store i64 2, ptr %q3
  %v2 = load i64, ptr %q     ; GVN forwards to 1
  ret i64 %v2
}
```
**GVN:** Chains load forwarding: q2→q, v→1, q3 offset→1, v2→1. Returns `ret i64 1`.
**NewGVN:** Replaces unreachable %if content with poison but does not do the full load forwarding chain. Returns `ret i64 %v2` (load).
**Reason:** NewGVN does not do the same inter-dependent load forwarding chain as GVN.

### rle-no-phi-translate.ll
**Difference:** PHI translation for load elimination
**Reproducer:**
```llvm
define i32 @g(ptr %b, ptr %c) {
entry:
  store i32 1, ptr %b
  store i32 2, ptr %c
  %t1 = icmp eq ptr %b, null
  br i1 %t1, label %bb, label %bb2
bb:
  br label %bb2
bb2:
  %c_addr.0 = phi ptr [ %b, %entry ], [ %c, %bb ]
  %cv = load i32, ptr %c_addr.0, align 4
  ret i32 %cv
}
```
**GVN:** Also XFAIL (cannot do PHI translation here).
**NewGVN:** Keeps the load through the PHI (same result, both can't optimize this).
**Reason:** Neither GVN nor NewGVN can do path-sensitive PHI translation here. The original GVN test is marked XFAIL.

### 2007-07-26-PhiErasure.ll
**Difference:** Unreachable block handling in loops
**Reproducer:**
```llvm
@n_spills = external global i32
define i32 @reload(...) {
cond_next2835.1:
  %tmp2922 = load i32, ptr @n_spills
  br label %bb2928
bb2928:
  br i1 false, label %cond_next2943, label %cond_true2935
  ...
bb2982.preheader:
  %tmp298316 = load i32, ptr @n_spills
  ret i32 %tmp298316
}
```
**GVN:** Eliminates redundant load in entry block, inserts critical edge split, keeps load in preheader.
**NewGVN:** Eliminates both loads, replaces preheader with `store i8 poison` + `ret i32 poison` (treats as unreachable).
**Reason:** NewGVN detects the preheader is only reachable via an always-false branch, making it effectively unreachable.

### pr48805.ll
**Difference:** Load forwarding with unreachable blocks
**GVN:** Does PRE-style load hoisting, creates critical edge splits, forwards loads.
**NewGVN:** Replaces unreachable block with poison, keeps more loads.
**Reason:** NewGVN lacks GVN's PRE load hoisting and handles unreachable blocks differently.

### unreachable-predecessor.ll
**Difference:** Unreachable predecessor handling in loops
**GVN:** Detects unreachable predecessor, replaces %ptr2 with poison in PHI, adds critical edge split block, hoists loop-invariant load.
**NewGVN:** Replaces %ptr2 with poison in PHI but does not split critical edges or hoist loop-invariant loads.
**Reason:** NewGVN does not do critical edge splitting or PRE-style load hoisting.

### pr32314.ll
**Difference:** PHI-of-ops optimization
**GVN:** Computes `%0 = add nsw i64 %indvars.iv, -1` as a separate instruction.
**NewGVN:** Inserts a `%phiofops = phi i64 [ 0, %entry ], [ %indvars.iv, %for.body ]` to represent the loop offset, eliminating the add.
**Reason:** NewGVN's phi-of-ops optimization creates PHI nodes for loop-variant expressions.

### scalable-memloc.ll
**Difference:** Implicit dead code elimination
**GVN:** Keeps unused `extractelement` and `fadd` instructions.
**NewGVN:** Removes unused instructions (implicit DCE).
**Reason:** NewGVN eliminates instructions whose results are unused as part of value numbering.

### masked-load-store-vn-crash.ll
**Difference:** Aggressive dead code elimination before unreachable
**GVN:** Keeps the first masked load, removes the scalar load and second masked load.
**NewGVN:** Removes all masked loads and the or, keeping only the scalar load before unreachable.
**Reason:** NewGVN more aggressively eliminates unused code before unreachable terminators.

### pr14166.ll
**Difference:** Store-through-type-change load forwarding
**GVN (MemDep):** Forwards load through inttoptr+store (bitcast-like forwarding).
**GVN (MemorySSA) / NewGVN:** Does not forward because the store changes interpretation.
**Reason:** NewGVN uses MemorySSA which is more conservative about type-punning stores.

### int_sideeffect.ll
**Difference:** Loop-invariant load handling
**GVN:** Hoists loop-invariant load to a preheader using PRE.
**NewGVN:** Keeps the load inside the loop (no PRE).
**Reason:** NewGVN does not implement PRE (Partial Redundancy Elimination).

### trunc-nuw-equality.ll
**Difference:** Equality propagation from trunc nuw
**Reproducer:**
```llvm
define void @test(ptr %p, i64 %v) {
  %tr = trunc nuw i64 %v to i1
  br i1 %tr, label %ret, label %store
store:
  store i64 %v, ptr %p
  ret void
ret:
  store i64 %v, ptr %p
  ret void
}
```
**GVN:** Propagates: if trunc nuw is false→%v=0, if true→%v=1. Replaces stores.
**NewGVN:** Does not propagate the equality from trunc nuw. Keeps `store i64 %v`.
**Reason:** NewGVN does not implement trunc nuw equality propagation.

### assume.ll
**Difference:** Partial assume propagation
**GVN:** Full propagation — replaces `assume(false)` with `store poison`, propagates negations.
**NewGVN:** Partial — replaces direct uses after `assume(%x)` with `true`, but does not propagate negations or convert `assume(false)` to unreachable.
**Reason:** NewGVN has limited assume knowledge propagation compared to GVN.

---

## Tests Skipped (not copied)

The following GVN tests were not copied because they require GVN-specific flags,
additional passes, or special build configurations:

- `condprop-memdep-invalidation.ll` — uses `-enable-gvn-memdep`
- `load-constant-mem.ll` — uses `-passes=gvn,instcombine`
- `masked-load-store-no-mem-dep.ll` — uses `-enable-gvn-memdep=false`
- `no-mem-dep-info.ll` — uses `-enable-gvn-memdep=false`
- `nonescaping-malloc.ll` — uses `-stats` (REQUIRES: asserts)
- `opt-remark-assert-constant-uselistorder.ll` — uses `-pass-remarks-output` + GVN-specific remarks
- `opt-remarks-multiple-users.ll` — uses `-pass-remarks-output` + GVN-specific remarks
- `opt-remarks-non-dominating.ll` — uses `-pass-remarks-output` + GVN-specific remarks
- `opt-remarks.ll` — uses `-pass-remarks=gvn` + GVN-specific remarks
- `pr24426.ll` — uses `-passes=memcpyopt,mldst-motion,gvn`
- `pr36063.ll` — uses `-passes=memcpyopt,mldst-motion,gvn`
- `preserve-analysis.ll` — tests GVN-specific analysis preservation
- `remarks-selfdomination.ll` — uses `-pass-remarks-analysis=gvn`

## Coverage Summary

- **Total GVN tests (main dir):** 170
- **Copied to NewGVN/GVN/:** 157 (92%)
- **Skipped:** 13 (require GVN-specific flags/passes/build config)
- **GVN/PRE/ subdirectory:** not yet covered (44 tests, all require PRE)
