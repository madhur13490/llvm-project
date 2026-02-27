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
// Multiple array accesses along the same dimension produce identical bound
// checks even though the index expressions differ.  This pass keeps only the
// first assume for each unique (predicate, constant-bound) pair per function,
// removing all later duplicates together with any dead feeding instructions.
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

    // Key: (predicate, constant bound).  Two assumes that test against the
    // same constant with the same relational operator are redundant regardless
    // of which SSA value is being compared.
    using BoundsKey = std::pair<CmpInst::Predicate, int64_t>;
    std::set<BoundsKey> SeenBounds;
    SmallVector<Instruction *, 16> ToDelete;

    for (BasicBlock &BB : F) {
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

        ConstantInt *Bound = dyn_cast<ConstantInt>(ICmp->getOperand(1));
        if (!Bound)
          Bound = dyn_cast<ConstantInt>(ICmp->getOperand(0));
        if (!Bound)
          continue;

        BoundsKey Key(ICmp->getPredicate(), Bound->getSExtValue());
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

  PreservedAnalyses PA;
  PA.preserveSet<AllAnalysesOn<Function>>();
  return PA;
}
