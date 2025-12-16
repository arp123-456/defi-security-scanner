# 📖 Usage Guide - DeFi Security Scanner

Complete guide for using the automated security testing pipeline.

## 🚀 Quick Start

### Option 1: GitHub Actions (Recommended)

The CI/CD pipeline runs automatically on:
- Every push to `main` branch
- Every pull request
- Daily at 2 AM UTC
- Manual trigger via Actions tab

**View Results:**
1. Go to **Actions** tab in GitHub
2. Click on latest **DeFi Security Scanner** run
3. Download artifacts for detailed reports

### Option 2: Local Analysis

```bash
# Clone repository
git clone https://github.com/arp123-456/defi-security-scanner.git
cd defi-security-scanner

# Analyze a protocol
chmod +x scripts/analyze-protocol.sh
./scripts/analyze-protocol.sh compound compound-finance/compound-protocol

# View reports
ls -la reports/compound/
```

## 📊 Understanding Reports

### Report Structure

```
reports/
└── compound/
    ├── SUMMARY.md                    # Executive summary
    ├── slither-report.json          # Machine-readable findings
    ├── slither-report.md            # Human-readable findings
    ├── test-results.txt             # Foundry test output
    ├── coverage.txt                 # Code coverage
    ├── build-sizes.txt              # Contract sizes
    └── mythril/
        ├── CToken-report.md         # Per-contract analysis
        └── Comptroller-report.md
```

### Severity Levels

| Level | Icon | Description | Action Required |
|-------|------|-------------|-----------------|
| **Critical** | 🔴 | Immediate exploit risk | Fix immediately |
| **High** | 🟠 | Significant vulnerability | Fix within 24h |
| **Medium** | 🟡 | Potential security issue | Fix within 1 week |
| **Low** | 🟢 | Minor issue or best practice | Fix when convenient |
| **Info** | ℹ️ | Informational finding | Review and consider |

## 🔍 Analyzing Specific Vulnerabilities

### 1. Reentrancy Detection

**Tools Used:** Slither, Mythril, Foundry

**What to Look For:**
```solidity
// Vulnerable pattern
function withdraw(uint amount) public {
    require(balances[msg.sender] >= amount);
    (bool success, ) = msg.sender.call{value: amount}("");  // External call
    require(success);
    balances[msg.sender] -= amount;  // State change AFTER call
}
```

**In Reports:**
- Slither: `reentrancy-eth`, `reentrancy-no-eth`
- Mythril: SWC-107 (Reentrancy)
- Foundry: Test `testReentrancyAttack()`

### 2. Price Oracle Manipulation

**Tools Used:** Slither, Custom Foundry Tests

**What to Look For:**
```solidity
// Vulnerable pattern
function liquidate(address user) public {
    uint price = oracle.getPrice();  // No staleness check
    // ... liquidation logic
}
```

**In Reports:**
- Slither: Custom detector for oracle usage
- Foundry: `testFlashLoanPriceManipulation()`
- Look for: Missing timestamp checks, single-source oracles

### 3. Access Control Issues

**Tools Used:** Slither, Foundry

**What to Look For:**
```solidity
// Vulnerable pattern
function setAdmin(address newAdmin) public {
    admin = newAdmin;  // No access control!
}
```

**In Reports:**
- Slither: `unprotected-upgrade`, `suicidal`
- Foundry: `testUnauthorizedAdminAccess()`

### 4. Integer Overflow/Underflow

**Tools Used:** Slither (for Solidity < 0.8.0)

**What to Look For:**
```solidity
// Vulnerable in Solidity < 0.8.0
uint256 balance = 0;
balance = balance - 1;  // Underflows to max uint256
```

**In Reports:**
- Slither: `integer-overflow`, `divide-before-multiply`
- Check Solidity version in reports

### 5. Decimal Mismatches

**Tools Used:** Custom Foundry Tests

**What to Look For:**
```solidity
// Vulnerable pattern
uint256 usdcAmount = 1000000;  // 6 decimals
uint256 daiAmount = 1000000;   // 18 decimals - NOT equivalent!
```

**In Reports:**
- Foundry: `testDecimalMismatch()`
- Manual review of token interactions

## 🛠️ Customizing Analysis

### Add New Protocol

Edit `.github/workflows/security-scan.yml`:

```yaml
strategy:
  matrix:
    protocol:
      - name: aave
        repo: aave/aave-v3-core
        path: contracts
```

### Adjust Tool Settings

**Slither:**
```json
// slither.config.json
{
  "detectors_to_run": [
    "reentrancy-eth",
    "your-custom-detector"
  ]
}
```

**Foundry:**
```toml
# foundry.toml
[profile.default]
fuzz = { runs = 50000 }  # More thorough
```

**Echidna:**
```yaml
# echidna.config.yml
testLimit: 100000  # More tests
```

### Add Custom Tests

Create new test file in `test/`:

```solidity
// test/CustomProtocolTests.t.sol
pragma solidity ^0.8.25;

import "./SecurityTests.t.sol";

contract CustomProtocolTests is SecurityTests {
    function testCustomVulnerability() public {
        // Your custom test logic
    }
}
```

## 📈 Interpreting Risk Scores

### Risk Score Calculation

```
Base Score (protocol-specific) + Findings Adjustment
```

**Base Scores:**
- Venus: 8.5 (old Solidity version)
- Compound: 7.5 (complex logic)
- Curve: 6.0 (Vyper, simpler)
- Uniswap v4: 5.0 (modern, well-tested)

**Adjustments:**
- Critical finding: +2.0
- High finding: +1.0
- Medium finding: +0.3
- Low finding: +0.1

**Example:**
```
Compound Base: 7.5
+ 1 Critical (2.0)
+ 3 High (3.0)
+ 5 Medium (1.5)
= 14.0 → Capped at 10.0 (CRITICAL)
```

## 🔧 Troubleshooting

### Workflow Fails

**Issue:** Slither analysis fails
```bash
# Solution: Check Solidity version compatibility
solc-select install 0.8.25
solc-select use 0.8.25
```

**Issue:** Foundry tests timeout
```bash
# Solution: Reduce test complexity
forge test --no-match-test testFuzz_*
```

**Issue:** Out of memory
```bash
# Solution: Reduce parallel jobs in workflow
# Edit .github/workflows/security-scan.yml
# Change matrix to run fewer protocols simultaneously
```

### Local Analysis Issues

**Issue:** Dependencies not found
```bash
# Solution: Install all dependencies
npm install
forge install
```

**Issue:** RPC connection fails
```bash
# Solution: Use public RPC or skip fork tests
export MAINNET_RPC_URL=""
forge test --no-fork
```

## 📊 Sample Workflow

### Complete Analysis Workflow

```bash
# 1. Clone and setup
git clone https://github.com/arp123-456/defi-security-scanner.git
cd defi-security-scanner

# 2. Analyze protocol
./scripts/analyze-protocol.sh morpho morpho-org/morpho-blue

# 3. Review summary
cat reports/morpho/SUMMARY.md

# 4. Check critical findings
grep -r "Critical\|High" reports/morpho/

# 5. Review specific contracts
cat reports/morpho/mythril/Morpho-report.md

# 6. Check test coverage
cat reports/morpho/coverage.txt

# 7. Generate consolidated report
python3 scripts/generate-report.py reports/

# 8. View final report
cat SECURITY_REPORT.md
```

## 🎯 Best Practices

### Before Deployment

1. ✅ Run full security scan
2. ✅ Achieve >90% test coverage
3. ✅ Fix all Critical and High findings
4. ✅ Review all Medium findings
5. ✅ Professional audit
6. ✅ Bug bounty program
7. ✅ Gradual rollout with monitoring

### Continuous Monitoring

1. ✅ Daily automated scans
2. ✅ Monitor for new vulnerabilities
3. ✅ Track dependency updates
4. ✅ Review security advisories
5. ✅ Maintain incident response plan

### Code Review Checklist

- [ ] All external calls checked
- [ ] Reentrancy guards in place
- [ ] Access control on sensitive functions
- [ ] Oracle staleness checks
- [ ] Decimal handling verified
- [ ] Edge cases tested
- [ ] Gas optimization reviewed
- [ ] Documentation complete

## 📚 Additional Resources

### Learning Resources

- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Slither Documentation](https://github.com/crytic/slither/wiki)
- [Foundry Book](https://book.getfoundry.sh/)
- [Secureum Bootcamp](https://secureum.substack.com/)

### Security Tools

- [Slither](https://github.com/crytic/slither) - Static analysis
- [Mythril](https://github.com/ConsenSys/mythril) - Symbolic execution
- [Echidna](https://github.com/crytic/echidna) - Fuzzing
- [Manticore](https://github.com/trailofbits/manticore) - Symbolic execution
- [Certora](https://www.certora.com/) - Formal verification

### Audit Firms

- Trail of Bits
- OpenZeppelin
- Consensys Diligence
- Sigma Prime
- ChainSecurity

## 🤝 Contributing

Want to improve the scanner? See [CONTRIBUTING.md](CONTRIBUTING.md)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/arp123-456/defi-security-scanner/issues)
- **Discussions**: [GitHub Discussions](https://github.com/arp123-456/defi-security-scanner/discussions)

---

**⚠️ Important:** This tool aids security analysis but doesn't replace professional audits. Always conduct thorough manual review and professional security audits before mainnet deployment.
