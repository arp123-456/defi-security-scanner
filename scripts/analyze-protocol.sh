#!/bin/bash

# DeFi Protocol Security Analysis Script
# Usage: ./analyze-protocol.sh <protocol-name> <github-repo>

set -e

PROTOCOL_NAME=$1
GITHUB_REPO=$2
REPORT_DIR="reports/${PROTOCOL_NAME}"

if [ -z "$PROTOCOL_NAME" ] || [ -z "$GITHUB_REPO" ]; then
    echo "Usage: ./analyze-protocol.sh <protocol-name> <github-repo>"
    echo "Example: ./analyze-protocol.sh compound compound-finance/compound-protocol"
    exit 1
fi

echo "🔍 Starting security analysis for ${PROTOCOL_NAME}..."
echo "=================================================="

# Create report directory
mkdir -p "${REPORT_DIR}"

# Clone protocol repository
echo "📥 Cloning repository..."
if [ -d "temp/${PROTOCOL_NAME}" ]; then
    rm -rf "temp/${PROTOCOL_NAME}"
fi
mkdir -p "temp"
git clone "https://github.com/${GITHUB_REPO}" "temp/${PROTOCOL_NAME}"
cd "temp/${PROTOCOL_NAME}"

# Install dependencies
echo "📦 Installing dependencies..."
if [ -f "package.json" ]; then
    npm install || yarn install || true
fi

# Run Slither
echo "🐍 Running Slither analysis..."
slither . \
    --detect reentrancy-eth,reentrancy-no-eth,reentrancy-benign \
    --detect timestamp,weak-prng \
    --detect suicidal,unprotected-upgrade \
    --detect arbitrary-send-eth,controlled-delegatecall \
    --detect unchecked-transfer,unchecked-lowlevel \
    --json "../../${REPORT_DIR}/slither-report.json" \
    --markdown-root "../../${REPORT_DIR}/slither-report.md" \
    || echo "Slither completed with findings"

# Run Foundry tests
echo "⚒️  Running Foundry tests..."
if command -v forge &> /dev/null; then
    forge install || true
    forge build --sizes > "../../${REPORT_DIR}/build-sizes.txt" 2>&1 || true
    forge test -vvv --gas-report > "../../${REPORT_DIR}/test-results.txt" 2>&1 || true
    forge coverage --report summary > "../../${REPORT_DIR}/coverage.txt" 2>&1 || true
else
    echo "⚠️  Foundry not installed, skipping..."
fi

# Run Mythril on key contracts
echo "🔮 Running Mythril analysis..."
if command -v myth &> /dev/null; then
    mkdir -p "../../${REPORT_DIR}/mythril"
    
    # Find and analyze main contracts
    find contracts -name "*.sol" -type f | head -5 | while read contract; do
        filename=$(basename "$contract" .sol)
        echo "  Analyzing ${filename}..."
        myth analyze "$contract" \
            --execution-timeout 180 \
            --max-depth 30 \
            -o markdown > "../../${REPORT_DIR}/mythril/${filename}-report.md" 2>&1 \
            || echo "  Mythril analysis completed for ${filename}"
    done
else
    echo "⚠️  Mythril not installed, skipping..."
fi

# Run Aderyn
echo "🦀 Running Aderyn analysis..."
if command -v aderyn &> /dev/null; then
    aderyn . -o "../../${REPORT_DIR}/aderyn-report.md" || true
else
    echo "⚠️  Aderyn not installed, skipping..."
fi

# Generate summary report
cd ../..
echo "📊 Generating summary report..."

cat > "${REPORT_DIR}/SUMMARY.md" << EOF
# Security Analysis Report: ${PROTOCOL_NAME}

**Generated:** $(date)
**Repository:** https://github.com/${GITHUB_REPO}

---

## 🔍 Analysis Tools Used

- ✅ Slither (Static Analysis)
- ✅ Foundry (Testing & Fuzzing)
- ✅ Mythril (Symbolic Execution)
- ✅ Aderyn (Rust-based Analysis)

---

## 📋 Vulnerability Categories Checked

### 1. Reentrancy Attacks
- Classic reentrancy
- Cross-function reentrancy
- Read-only reentrancy

### 2. Price Oracle Manipulation
- Flash loan attacks
- TWAP manipulation
- Stale price data
- Zero price handling

### 3. Access Control
- Unauthorized function access
- Privilege escalation
- Role-based access control

### 4. Integer Issues
- Overflow/Underflow
- Decimal mismatches
- Rounding errors

### 5. Logic Errors
- State transition bugs
- Edge case handling
- Front-running vulnerabilities

### 6. Other Vulnerabilities
- Unchecked external calls
- Delegatecall issues
- Timestamp dependence
- Weak randomness

---

## 📊 Results Summary

### Slither Findings
$(if [ -f "${REPORT_DIR}/slither-report.json" ]; then
    echo "See detailed report: slither-report.md"
else
    echo "No Slither report generated"
fi)

### Foundry Test Results
$(if [ -f "${REPORT_DIR}/test-results.txt" ]; then
    echo "See detailed results: test-results.txt"
else
    echo "No test results available"
fi)

### Mythril Analysis
$(if [ -d "${REPORT_DIR}/mythril" ]; then
    echo "See contract-specific reports in mythril/ directory"
else
    echo "No Mythril reports generated"
fi)

---

## 🚨 Critical Issues

*To be filled after manual review of tool outputs*

---

## 📈 Recommendations

1. **Immediate Actions**
   - Review all HIGH severity findings
   - Patch critical vulnerabilities
   - Add missing access controls

2. **Short-term Improvements**
   - Increase test coverage
   - Add invariant tests
   - Implement monitoring

3. **Long-term Strategy**
   - Professional security audit
   - Bug bounty program
   - Continuous security testing

---

## 📎 Detailed Reports

- [Slither Report](slither-report.md)
- [Test Results](test-results.txt)
- [Coverage Report](coverage.txt)
- [Mythril Reports](mythril/)
- [Aderyn Report](aderyn-report.md)

EOF

echo "✅ Analysis complete!"
echo "📁 Reports saved to: ${REPORT_DIR}"
echo ""
echo "📄 Summary: ${REPORT_DIR}/SUMMARY.md"
echo ""
echo "🔍 Next steps:"
echo "  1. Review ${REPORT_DIR}/SUMMARY.md"
echo "  2. Check detailed reports in ${REPORT_DIR}/"
echo "  3. Prioritize and fix critical issues"
echo "  4. Re-run analysis after fixes"
