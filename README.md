# 🔒 DeFi Security Scanner

Automated CI/CD security testing pipeline for DeFi protocols using multiple industry-standard tools.

## 🎯 Overview

This repository provides a comprehensive security analysis framework for DeFi smart contracts, featuring:

- **Automated CI/CD Pipeline** - GitHub Actions workflow for continuous security testing
- **Multiple Analysis Tools** - Slither, Foundry, Mythril, Echidna, Aderyn
- **Comprehensive Coverage** - Tests for 7+ vulnerability categories
- **Detailed Reporting** - Consolidated reports with risk scoring
- **Fork Testing** - Real-world testing against mainnet state

## 🛠️ Tools Included

| Tool | Purpose | Strengths |
|------|---------|-----------|
| **Slither** | Static analysis | Fast, comprehensive detector coverage |
| **Foundry** | Testing & fuzzing | Property-based testing, fork testing |
| **Mythril** | Symbolic execution | Deep path exploration |
| **Echidna** | Property fuzzing | Invariant testing |
| **Aderyn** | Modern static analysis | Rust-based, fast performance |

## 🚀 Quick Start

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Slither
pip3 install slither-analyzer

# Install Mythril
pip3 install mythril

# Install Echidna
wget https://github.com/crytic/echidna/releases/download/v2.2.1/echidna-2.2.1-Linux.tar.gz
tar -xzf echidna-2.2.1-Linux.tar.gz
sudo mv echidna /usr/local/bin/

# Install Aderyn
cargo install aderyn
```

### Local Analysis

```bash
# Clone this repository
git clone https://github.com/arp123-456/defi-security-scanner.git
cd defi-security-scanner

# Make script executable
chmod +x scripts/analyze-protocol.sh

# Analyze a protocol
./scripts/analyze-protocol.sh compound compound-finance/compound-protocol
```

### CI/CD Setup

1. **Fork this repository**
2. **Add secrets** (optional for fork testing):
   - `MAINNET_RPC_URL` - Ethereum mainnet RPC
   - `POLYGON_RPC_URL` - Polygon RPC
   - `ARBITRUM_RPC_URL` - Arbitrum RPC
   - `BSC_RPC_URL` - BSC RPC

3. **Enable GitHub Actions** in repository settings

4. **Trigger workflow**:
   - Push to `main` branch
   - Create pull request
   - Manual trigger via Actions tab
   - Scheduled daily at 2 AM UTC

## 📊 Vulnerability Categories

### 1. Reentrancy Attacks
- Classic reentrancy
- Cross-function reentrancy
- Read-only reentrancy
- Cross-contract reentrancy

### 2. Price Oracle Manipulation
- Flash loan price manipulation
- TWAP manipulation
- Oracle staleness
- Zero/invalid price handling

### 3. Access Control Issues
- Unauthorized function access
- Privilege escalation
- Missing role checks
- Improper initialization

### 4. Integer Vulnerabilities
- Overflow/Underflow (pre-0.8.0)
- Decimal mismatches
- Rounding errors
- Precision loss

### 5. Logic Errors
- Incorrect state transitions
- Edge case handling
- Front-running vulnerabilities
- MEV exploitation

### 6. External Call Issues
- Unchecked return values
- Delegatecall vulnerabilities
- Call injection
- Gas griefing

### 7. Other Vulnerabilities
- Timestamp dependence
- Weak randomness
- Locked ether
- Deprecated functions

## 📁 Repository Structure

```
defi-security-scanner/
├── .github/
│   └── workflows/
│       └── security-scan.yml      # Main CI/CD pipeline
├── scripts/
│   └── analyze-protocol.sh        # Local analysis script
├── test/
│   └── SecurityTests.t.sol        # Foundry test templates
├── reports/                       # Generated reports (gitignored)
├── foundry.toml                   # Foundry configuration
├── slither.config.json           # Slither configuration
└── README.md                      # This file
```

## 🔍 Analyzed Protocols

Current pipeline analyzes:

- ✅ **Compound** - Lending protocol
- ✅ **Venus** - BSC lending protocol
- ✅ **Curve** - Stablecoin DEX
- ✅ **Uniswap v4** - Latest DEX version
- ✅ **MakerDAO** - DAI stablecoin
- ✅ **dYdX v4** - Perpetuals exchange
- ✅ **PancakeSwap** - BSC DEX
- ✅ **Pendle** - Yield trading

## 📈 Risk Scoring

Protocols are scored on a 0-10 scale:

| Score | Risk Level | Action Required |
|-------|-----------|-----------------|
| 8-10 | 🔴 CRITICAL | Immediate review |
| 6-7.9 | 🟠 HIGH | Priority review |
| 4-5.9 | 🟡 MEDIUM | Scheduled review |
| 0-3.9 | 🟢 LOW | Monitor |

## 📊 Sample Report Output

```markdown
# Security Analysis Report: Compound

**Risk Score:** 7.5/10 (HIGH)

## Findings Summary
- 🔴 High: 2 issues
- 🟡 Medium: 5 issues
- 🟢 Low: 12 issues

## Critical Issues
1. **Price Oracle Manipulation** (HIGH)
   - Location: PriceOracle.sol:15
   - Description: No staleness check
   - Recommendation: Add timestamp validation

2. **Reentrancy Risk** (HIGH)
   - Location: CToken.sol:234
   - Description: External call before state update
   - Recommendation: Use ReentrancyGuard
```

## 🔧 Customization

### Add New Protocol

Edit `.github/workflows/security-scan.yml`:

```yaml
strategy:
  matrix:
    protocol:
      - name: your-protocol
        repo: org/repo-name
        path: contracts
```

### Modify Detectors

Edit `slither.config.json` to enable/disable specific detectors.

### Adjust Fuzz Parameters

Edit `foundry.toml`:

```toml
[profile.default]
fuzz = { runs = 10000 }  # Increase for more thorough testing
```

## 📚 Resources

- [Slither Documentation](https://github.com/crytic/slither)
- [Foundry Book](https://book.getfoundry.sh/)
- [Mythril Documentation](https://mythril-classic.readthedocs.io/)
- [Echidna Tutorial](https://github.com/crytic/building-secure-contracts/tree/master/program-analysis/echidna)
- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## ⚠️ Disclaimer

This tool is for educational and research purposes. Always:

- Conduct professional security audits
- Perform manual code review
- Test thoroughly before mainnet deployment
- Maintain bug bounty programs
- Monitor contracts post-deployment

## 📄 License

MIT License - See LICENSE file for details

## 🔗 Links

- **Repository**: https://github.com/arp123-456/defi-security-scanner
- **Issues**: https://github.com/arp123-456/defi-security-scanner/issues
- **Discussions**: https://github.com/arp123-456/defi-security-scanner/discussions

---

**Built with ❤️ for DeFi security**
