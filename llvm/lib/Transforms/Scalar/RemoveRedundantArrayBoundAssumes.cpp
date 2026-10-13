//===- RemoveRedundantArrayBoundAssumes.cpp ----------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Fortran lowering can attach !llvm.array.bounds metadata to llvm.assume
// intrinsics that encode declared array-dimension bounds (e.g. 1 <= idx <= 54).
// Multiple array accesses can produce identical checks of the same SSA value.
// This pass keeps only the first assume in a basic block for each unique
// compared value, predicate, and constant bound. Restricting elimination to a
// block guarantees that the retained assume dominates each removed duplicate.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Scalar/RemoveRedundantArrayBoundAssumes.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/Transforms/Utils/Local.h"
#include <set>
#include <tuple>

using namespace llvm;

PreservedAnalyses
RemoveRedundantArrayBoundAssumesPass::run(Module &M,
                                          ModuleAnalysisManager &AM) {
  bool Changed = false;

  for (Function &F : M) {
    if (F.isDeclaration())
      continue;

    // Different indices are not interchangeable facts even when they use the
    // same predicate and bound.
    using BoundsKey =
        std::tuple<CmpInst::Predicate, Value *, ConstantInt *>;
    SmallVector<Instruction *, 16> ToDelete;

    for (BasicBlock &BB : F) {
      std::set<BoundsKey> SeenBounds;
      for (Instruction &I : BB) {
        auto *Assume = dyn_cast<AssumeInst>(&I);
        if (!Assume)
          continue;

        if (!Assume->getMetadata("llvm.array.bounds"))
          continue;

        Value *Cond = Assume->getArgOperand(0);
        auto *ICmp = dyn_cast<ICmpInst>(Cond);
        if (!ICmp)
          continue;

        CmpInst::Predicate Pred = ICmp->getPredicate();
        Value *Compared = ICmp->getOperand(0);
        ConstantInt *Bound = dyn_cast<ConstantInt>(ICmp->getOperand(1));
        if (!Bound) {
          Bound = dyn_cast<ConstantInt>(ICmp->getOperand(0));
          Compared = ICmp->getOperand(1);
          Pred = ICmp->getSwappedPredicate();
        }
        if (!Bound)
          continue;

        BoundsKey Key(Pred, Compared, Bound);
        if (!SeenBounds.insert(Key).second)
          ToDelete.push_back(Assume);
      }
    }

    SmallVector<WeakTrackingVH, 16> DeadOps;
    for (Instruction *I : ToDelete) {
      Value *Cond = cast<AssumeInst>(I)->getArgOperand(0);
      I->eraseFromParent();
      if (Cond->use_empty())
        DeadOps.push_back(Cond);
      Changed = true;
    }
    RecursivelyDeleteTriviallyDeadInstructionsPermissive(DeadOps);
  }

  if (!Changed)
    return PreservedAnalyses::all();

  return PreservedAnalyses::none();
}
