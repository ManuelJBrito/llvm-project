#include "llvm/Transforms/Scalar/GVNExpression.h"

// Anchor methods.
namespace llvm {
namespace GVNExpression {

Expression::~Expression() = default;
BasicExpression::~BasicExpression() = default;
CallExpression::~CallExpression() = default;
LoadExpression::~LoadExpression() = default;
StoreExpression::~StoreExpression() = default;
AggregateValueExpression::~AggregateValueExpression() = default;
PHIExpression::~PHIExpression() = default;

template <typename T>
static bool equalsLoadStoreHelper(const T &LHS, const Expression &RHS) {
  if (!isa<LoadExpression>(RHS) && !isa<StoreExpression>(RHS))
    return false;
  return LHS.MemoryExpression::equals(RHS);
}

bool LoadExpression::equals(const Expression &Other) const {
  return equalsLoadStoreHelper(*this, Other);
}

bool StoreExpression::equals(const Expression &Other) const {
  if (!equalsLoadStoreHelper(*this, Other))
    return false;
  // Make sure that store vs store includes the value operand.
  if (const auto *S = dyn_cast<StoreExpression>(&Other))
    if (getStoredValue() != S->getStoredValue())
      return false;
  return true;
}

} // end namespace GVNExpression
} // end namespace llvm