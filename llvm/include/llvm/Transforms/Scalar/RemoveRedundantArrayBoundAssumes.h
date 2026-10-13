//===------------------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Removes redundant llvm.assume intrinsics that carry !llvm.array.bounds
// metadata. Fortran lowering can produce multiple identical assume bundles
// for static array index bounds (e.g. 1 <= IV <= 54) across different uses
// of the same induction variable. Only the first unique assume in each basic
// block is kept, so the retained fact dominates every removed duplicate.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_REMOVEREDUNDANTARRAYBOUNDASSUMES_H
#define LLVM_TRANSFORMS_SCALAR_REMOVEREDUNDANTARRAYBOUNDASSUMES_H

#include "llvm/IR/PassManager.h"

namespace llvm {

class RemoveRedundantArrayBoundAssumesPass
    : public OptionalPassInfoMixin<RemoveRedundantArrayBoundAssumesPass> {
public:
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &AM);
};

} // namespace llvm

#endif // LLVM_TRANSFORMS_SCALAR_REMOVEREDUNDANTARRAYBOUNDASSUMES_H
