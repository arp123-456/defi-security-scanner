# 🔴 TENDERLY FORK TESTING - STEP-BY-STEP GUIDE

**LIVE TESTING ON TENDERLY FORKS**

**Date:** December 31, 2025  
**Status:** Ready to Execute  
**Safety:** 100% Safe (Testnet Only)  

---

## 🚀 QUICK START - 5 MINUTES TO FIRST TEST

### **Prerequisites**

```bash
# 1. Node.js (v16+)
node --version

# 2. Git
git --version

# 3. Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

---

## 📋 STEP 1: TENDERLY ACCOUNT SETUP

### **Create Tenderly Account (Free)**

1. **Go to:** https://tenderly.co/
2. **Click:** "Sign Up" (top right)
3. **Choose:** GitHub, Google, or Email
4. **Verify:** Email confirmation
5. **Create Project:** 
   - Project Name: `defi-security-testing`
   - Click "Create Project"

### **Get Access Key**

1. **Click:** Your profile (top right)
2. **Select:** "Settings"
3. **Navigate:** "Authorization" → "Access Tokens"
4. **Click:** "Generate Access Token"
5. **Name:** `security-testing`
6. **Copy:** Token (save securely)

```bash
# Save your access key
export TENDERLY_ACCESS_KEY="your_access_key_here"
export TENDERLY_ACCOUNT_NAME="your_username"
export TENDERLY_PROJECT_NAME="defi-security-testing"
```

---

## 📋 STEP 2: PROJECT SETUP

### **Clone Repository**

```bash
# Clone the security scanner repo
git clone https://github.com/arp123-456/defi-security-scanner.git
cd defi-security-scanner

# Create testing directory
mkdir tenderly-tests
cd tenderly-tests
```

### **Initialize Foundry Project**

```bash
# Initialize Foundry
forge init oracle-tests --no-commit
cd oracle-tests

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts
forge install Uniswap/v2-periphery
forge install Uniswap/v3-periphery
```

### **Install Tenderly CLI**

```bash
# Install Tenderly CLI
npm install -g @tenderly/cli

# Login to Tenderly
tenderly login

# Initialize Tenderly in project
tenderly init
# Select your account and project when prompted
```

---

## 📋 STEP 3: CREATE TENDERLY FORK

### **Method 1: Via Tenderly Dashboard (Easiest)**

1. **Go to:** https://dashboard.tenderly.co/
2. **Navigate:** Your Project → "Forks"
3. **Click:** "Create Fork"
4. **Configure:**
   - Network: `Ethereum Mainnet`
   - Block Number: `Latest` or specific block
   - Fork Name: `oracle-test-fork`
5. **Click:** "Create Fork"
6. **Copy:** Fork RPC URL (looks like: `https://rpc.tenderly.co/fork/xxx`)

### **Method 2: Via CLI**

```bash
# Create fork via CLI
tenderly fork create \
  --network mainnet \
  --block-number latest \
  --fork-name oracle-test-fork

# Output will show:
# Fork created successfully!
# Fork ID: abc123def456
# RPC URL: https://rpc.tenderly.co/fork/abc123def456
```

### **Method 3: Via API (Programmatic)**

```javascript
// create-fork.js
const axios = require('axios');

async function createFork() {
  const response = await axios.post(
    `https://api.tenderly.co/api/v1/account/${process.env.TENDERLY_ACCOUNT_NAME}/project/${process.env.TENDERLY_PROJECT_NAME}/fork`,
    {
      network_id: '1', // Ethereum mainnet
      block_number: 18500000, // Or 'latest'
      alias: 'oracle-test-fork'
    },
    {
      headers: {
        'X-Access-Key': process.env.TENDERLY_ACCESS_KEY,
        'Content-Type': 'application/json'
      }
    }
  );
  
  console.log('Fork created!');
  console.log('Fork ID:', response.data.simulation_fork.id);
  console.log('RPC URL:', `https://rpc.tenderly.co/fork/${response.data.simulation_fork.id}`);
  
  return response.data.simulation_fork.id;
}

createFork();
```

---

## 📋 STEP 4: CONFIGURE FOUNDRY

### **Update foundry.toml**

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.19"

# Tenderly fork configuration
[rpc_endpoints]
tenderly = "${TENDERLY_FORK_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }

# Testing configuration
[profile.default.fuzz]
runs = 256

[profile.default.invariant]
runs = 256
depth = 15
```

### **Set Environment Variables**

```bash
# Create .env file
cat > .env << EOF
TENDERLY_ACCESS_KEY=your_access_key_here
TENDERLY_ACCOUNT_NAME=your_username
TENDERLY_PROJECT_NAME=defi-security-testing
TENDERLY_FORK_RPC_URL=https://rpc.tenderly.co/fork/your_fork_id
ETHERSCAN_API_KEY=your_etherscan_key
EOF

# Load environment variables
source .env
```

---

## 📋 STEP 5: CREATE TEST CONTRACT

### **Create Test File**

```bash
# Create test directory
mkdir -p test

# Create test file
cat > test/OracleExploit.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV2Factory {
    function getPair(address, address) external view returns (address);
}

contract OracleExploitTest is Test {
    // Mainnet addresses
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ALPHA = 0xa1faa113cbE53436Df28FF0aEe54275c13B40975;
    address constant SUSHI = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
    
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    
    function setUp() public {
        // Fork is already set up via RPC URL
        console.log("Testing on Tenderly fork");
        console.log("Block number:", block.number);
        console.log("Chain ID:", block.chainid);
    }
    
    function testCheckLiquidity() public view {
        console.log("\n=== LIQUIDITY CHECK ===");
        
        // Check ALPHA/WETH liquidity
        address alphaPair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(ALPHA, WETH);
        if (alphaPair != address(0)) {
            (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(alphaPair).getReserves();
            address token0 = IUniswapV2Pair(alphaPair).token0();
            
            uint256 alphaReserve = token0 == ALPHA ? reserve0 : reserve1;
            uint256 wethReserve = token0 == ALPHA ? reserve1 : reserve0;
            
            console.log("ALPHA/WETH Pair:", alphaPair);
            console.log("ALPHA Reserve:", alphaReserve);
            console.log("WETH Reserve:", wethReserve);
            console.log("ALPHA Liquidity (USD):", (wethReserve * 2 * 2000) / 1e18); // Assuming ETH = $2000
        }
        
        // Check SUSHI/WETH liquidity
        address sushiPair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(SUSHI, WETH);
        if (sushiPair != address(0)) {
            (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(sushiPair).getReserves();
            address token0 = IUniswapV2Pair(sushiPair).token0();
            
            uint256 sushiReserve = token0 == SUSHI ? reserve0 : reserve1;
            uint256 wethReserve = token0 == SUSHI ? reserve1 : reserve0;
            
            console.log("\nSUSHI/WETH Pair:", sushiPair);
            console.log("SUSHI Reserve:", sushiReserve);
            console.log("WETH Reserve:", wethReserve);
            console.log("SUSHI Liquidity (USD):", (wethReserve * 2 * 2000) / 1e18);
        }
    }
    
    function testPriceManipulation() public {
        console.log("\n=== PRICE MANIPULATION TEST ===");
        
        // Get initial price
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = ALPHA;
        
        uint256 amountIn = 1 ether;
        uint256[] memory amountsOut = IUniswapV2Router(UNISWAP_ROUTER).getAmountsOut(amountIn, path);
        uint256 initialPrice = amountsOut[1];
        
        console.log("Initial ALPHA price (per 1 ETH):", initialPrice);
        
        // Simulate having 100 ETH
        deal(WETH, address(this), 100 ether);
        console.log("Attacker WETH balance:", IERC20(WETH).balanceOf(address(this)));
        
        // Approve router
        IERC20(WETH).approve(UNISWAP_ROUTER, type(uint256).max);
        
        // Execute large swap to manipulate price
        uint256 swapAmount = 50 ether;
        console.log("\nExecuting swap of", swapAmount / 1e18, "ETH for ALPHA...");
        
        uint256[] memory amounts = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            address(this),
            block.timestamp + 1
        );
        
        console.log("Received ALPHA:", amounts[1]);
        
        // Check new price
        uint256[] memory newAmountsOut = IUniswapV2Router(UNISWAP_ROUTER).getAmountsOut(amountIn, path);
        uint256 manipulatedPrice = newAmountsOut[1];
        
        console.log("Manipulated ALPHA price (per 1 ETH):", manipulatedPrice);
        
        // Calculate price change
        uint256 priceChange = ((initialPrice - manipulatedPrice) * 100) / initialPrice;
        console.log("Price decreased by:", priceChange, "%");
        
        // This demonstrates how easy it is to manipulate low liquidity token prices
        assertLt(manipulatedPrice, initialPrice, "Price should decrease after large buy");
    }
    
    function testFlashLoanSimulation() public {
        console.log("\n=== FLASH LOAN SIMULATION ===");
        
        // Simulate flash loan by giving ourselves tokens
        uint256 flashLoanAmount = 1000 ether;
        deal(WETH, address(this), flashLoanAmount);
        
        console.log("Flash loan amount:", flashLoanAmount / 1e18, "ETH");
        
        uint256 initialBalance = IERC20(WETH).balanceOf(address(this));
        
        // Execute attack
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = ALPHA;
        
        // Approve
        IERC20(WETH).approve(UNISWAP_ROUTER, type(uint256).max);
        
        // Step 1: Buy ALPHA (manipulate price up)
        console.log("\nStep 1: Buying ALPHA to manipulate price...");
        uint256[] memory amounts1 = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            flashLoanAmount / 2,
            0,
            path,
            address(this),
            block.timestamp + 1
        );
        
        uint256 alphaReceived = amounts1[1];
        console.log("ALPHA received:", alphaReceived);
        
        // At this point, a vulnerable protocol would read the manipulated price
        // and allow us to borrow more than we should
        
        // Step 2: Sell ALPHA back (reverse manipulation)
        console.log("\nStep 2: Selling ALPHA back...");
        path[0] = ALPHA;
        path[1] = WETH;
        
        IERC20(ALPHA).approve(UNISWAP_ROUTER, type(uint256).max);
        
        uint256[] memory amounts2 = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            alphaReceived,
            0,
            path,
            address(this),
            block.timestamp + 1
        );
        
        uint256 wethReceived = amounts2[1];
        console.log("WETH received back:", wethReceived);
        
        // Calculate loss from slippage
        uint256 finalBalance = IERC20(WETH).balanceOf(address(this));
        uint256 loss = initialBalance - finalBalance;
        
        console.log("\nFinal WETH balance:", finalBalance);
        console.log("Loss from slippage:", loss);
        console.log("Loss percentage:", (loss * 100) / initialBalance, "%");
        
        // In a real exploit, the profit would come from borrowing
        // against the manipulated collateral value
        console.log("\nNote: In real exploit, profit comes from overborrowing");
        console.log("during the price manipulation window");
    }
    
    function testMultiTokenAttack() public {
        console.log("\n=== MULTI-TOKEN ATTACK SIMULATION ===");
        
        address[] memory tokens = new address[](3);
        tokens[0] = ALPHA;
        tokens[1] = SUSHI;
        tokens[2] = 0xD533a949740bb3306d119CC777fa900bA034cd52; // CRV
        
        // Simulate large capital
        deal(WETH, address(this), 10000 ether);
        IERC20(WETH).approve(UNISWAP_ROUTER, type(uint256).max);
        
        for (uint i = 0; i < tokens.length; i++) {
            console.log("\n--- Attacking token", i + 1, "---");
            console.log("Token address:", tokens[i]);
            
            // Check if pair exists
            address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(tokens[i], WETH);
            if (pair == address(0)) {
                console.log("No pair found, skipping...");
                continue;
            }
            
            // Get initial price
            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = tokens[i];
            
            try IUniswapV2Router(UNISWAP_ROUTER).getAmountsOut(1 ether, path) returns (uint256[] memory amounts) {
                console.log("Initial price:", amounts[1]);
                
                // Execute manipulation
                try IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
                    100 ether,
                    0,
                    path,
                    address(this),
                    block.timestamp + 1
                ) returns (uint256[] memory swapAmounts) {
                    console.log("Tokens received:", swapAmounts[1]);
                    
                    // Check new price
                    uint256[] memory newAmounts = IUniswapV2Router(UNISWAP_ROUTER).getAmountsOut(1 ether, path);
                    console.log("Manipulated price:", newAmounts[1]);
                    
                    uint256 priceChange = ((amounts[1] - newAmounts[1]) * 100) / amounts[1];
                    console.log("Price impact:", priceChange, "%");
                } catch {
                    console.log("Swap failed");
                }
            } catch {
                console.log("Could not get price");
            }
        }
    }
}
EOF
```

---

## 📋 STEP 6: RUN TESTS ON TENDERLY FORK

### **Basic Test Run**

```bash
# Run all tests
forge test --fork-url $TENDERLY_FORK_RPC_URL -vvv

# Run specific test
forge test --fork-url $TENDERLY_FORK_RPC_URL --match-test testCheckLiquidity -vvv

# Run with gas reporting
forge test --fork-url $TENDERLY_FORK_RPC_URL --gas-report -vvv
```

### **Expected Output**

```
Running 4 tests for test/OracleExploit.t.sol:OracleExploitTest

[PASS] testCheckLiquidity() (gas: 123456)
Logs:
  === LIQUIDITY CHECK ===
  ALPHA/WETH Pair: 0x...
  ALPHA Reserve: 1234567890
  WETH Reserve: 123456789
  ALPHA Liquidity (USD): 5000000
  
  SUSHI/WETH Pair: 0x...
  SUSHI Reserve: 9876543210
  WETH Reserve: 987654321
  SUSHI Liquidity (USD): 50000000

[PASS] testPriceManipulation() (gas: 234567)
Logs:
  === PRICE MANIPULATION TEST ===
  Initial ALPHA price (per 1 ETH): 1000000000000000000
  Attacker WETH balance: 100000000000000000000
  
  Executing swap of 50 ETH for ALPHA...
  Received ALPHA: 45000000000000000000
  Manipulated ALPHA price (per 1 ETH): 750000000000000000
  Price decreased by: 25 %

[PASS] testFlashLoanSimulation() (gas: 345678)
Logs:
  === FLASH LOAN SIMULATION ===
  Flash loan amount: 1000 ETH
  
  Step 1: Buying ALPHA to manipulate price...
  ALPHA received: 450000000000000000000
  
  Step 2: Selling ALPHA back...
  WETH received back: 475000000000000000000
  
  Final WETH balance: 975000000000000000000
  Loss from slippage: 25000000000000000000
  Loss percentage: 2 %
  
  Note: In real exploit, profit comes from overborrowing
  during the price manipulation window

[PASS] testMultiTokenAttack() (gas: 456789)
Logs:
  === MULTI-TOKEN ATTACK SIMULATION ===
  
  --- Attacking token 1 ---
  Token address: 0xa1faa113cbE53436Df28FF0aEe54275c13B40975
  Initial price: 1000000000000000000
  Tokens received: 95000000000000000000
  Manipulated price: 800000000000000000
  Price impact: 20 %
  
  --- Attacking token 2 ---
  Token address: 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2
  Initial price: 500000000000000000
  Tokens received: 190000000000000000000
  Manipulated price: 450000000000000000
  Price impact: 10 %

Test result: ok. 4 passed; 0 failed; finished in 12.34s
```

---

## 📋 STEP 7: ADVANCED TESTING

### **Test with Specific Block**

```bash
# Fork at specific block (before Radiant exploit)
tenderly fork create \
  --network mainnet \
  --block-number 18400000 \
  --fork-name radiant-pre-exploit

# Run tests on that fork
forge test --fork-url https://rpc.tenderly.co/fork/YOUR_NEW_FORK_ID -vvv
```

### **Test Multiple Scenarios**

```bash
# Create script to test multiple scenarios
cat > test-scenarios.sh << 'EOF'
#!/bin/bash

echo "=== Testing Oracle Vulnerabilities ==="

# Scenario 1: Low liquidity token
echo "\n1. Testing ALPHA token manipulation..."
forge test --fork-url $TENDERLY_FORK_RPC_URL --match-test testPriceManipulation -vv

# Scenario 2: Flash loan attack
echo "\n2. Testing flash loan simulation..."
forge test --fork-url $TENDERLY_FORK_RPC_URL --match-test testFlashLoanSimulation -vv

# Scenario 3: Multi-token attack
echo "\n3. Testing multi-token attack..."
forge test --fork-url $TENDERLY_FORK_RPC_URL --match-test testMultiTokenAttack -vv

echo "\n=== All tests complete ==="
EOF

chmod +x test-scenarios.sh
./test-scenarios.sh
```

---

## 📋 STEP 8: MONITOR ON TENDERLY DASHBOARD

### **View Test Results**

1. **Go to:** https://dashboard.tenderly.co/
2. **Navigate:** Your Project → "Forks" → Your Fork
3. **Click:** "Transactions" tab
4. **See:** All test transactions with full details

### **Analyze Transactions**

For each transaction you can see:
- ✅ Gas used
- ✅ State changes
- ✅ Events emitted
- ✅ Internal calls
- ✅ Storage changes
- ✅ Balance changes

### **Debug Failed Tests**

1. **Click:** Failed transaction
2. **View:** Stack trace
3. **See:** Exact line where it failed
4. **Check:** State at failure point
5. **Fix:** Update test and re-run

---

## 📋 STEP 9: SIMULATE REAL PROTOCOLS

### **Test Against Morpho Blue**

```solidity
// Add to test file
interface IMorpho {
    function supply(
        address market,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);
    
    function borrow(
        address market,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

function testMorphoExploit() public {
    console.log("\n=== MORPHO BLUE EXPLOIT TEST ===");
    
    address morpho = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    
    // Simulate flash loan
    deal(WETH, address(this), 1000 ether);
    
    // Manipulate ALPHA price
    // ... manipulation code ...
    
    // Try to exploit Morpho
    // ... exploit code ...
    
    console.log("Test complete");
}
```

### **Test Against Silo Finance**

```solidity
interface ISilo {
    function deposit(address _asset, uint256 _amount, bool _collateralOnly) external;
    function borrow(address _asset, uint256 _amount) external;
}

function testSiloExploit() public {
    console.log("\n=== SILO FINANCE EXPLOIT TEST ===");
    
    address silo = 0x...; // Silo address
    
    // Test exploit
    // ... code ...
}
```

---

## 📋 STEP 10: GENERATE REPORT

### **Create Report Script**

```javascript
// generate-report.js
const fs = require('fs');
const { execSync } = require('child_process');

async function generateReport() {
  console.log('Generating test report...');
  
  // Run tests and capture output
  const output = execSync(
    `forge test --fork-url ${process.env.TENDERLY_FORK_RPC_URL} --json`,
    { encoding: 'utf-8' }
  );
  
  const results = JSON.parse(output);
  
  // Generate markdown report
  let report = '# Oracle Vulnerability Test Report\n\n';
  report += `**Date:** ${new Date().toISOString()}\n`;
  report += `**Fork:** ${process.env.TENDERLY_FORK_RPC_URL}\n\n`;
  
  report += '## Test Results\n\n';
  
  for (const test of results.tests) {
    report += `### ${test.name}\n`;
    report += `- **Status:** ${test.status}\n`;
    report += `- **Gas Used:** ${test.gasUsed}\n`;
    report += `- **Duration:** ${test.duration}ms\n\n`;
    
    if (test.logs) {
      report += '**Logs:**\n```\n';
      report += test.logs.join('\n');
      report += '\n```\n\n';
    }
  }
  
  // Save report
  fs.writeFileSync('TEST_REPORT.md', report);
  console.log('Report saved to TEST_REPORT.md');
}

generateReport();
```

---

## 🎯 QUICK REFERENCE

### **Essential Commands**

```bash
# Create fork
tenderly fork create --network mainnet --fork-name test-fork

# Run all tests
forge test --fork-url $TENDERLY_FORK_RPC_URL -vvv

# Run specific test
forge test --match-test testPriceManipulation -vvv

# Run with gas report
forge test --gas-report -vvv

# Clean and rebuild
forge clean && forge build

# Update dependencies
forge update
```

### **Troubleshooting**

**Issue: "Fork not found"**
```bash
# Check fork exists
tenderly fork list

# Recreate fork
tenderly fork create --network mainnet
```

**Issue: "Insufficient funds"**
```solidity
// Use deal() to give yourself tokens
deal(WETH, address(this), 1000 ether);
```

**Issue: "Transaction reverted"**
```bash
# Run with more verbosity
forge test -vvvv

# Check Tenderly dashboard for details
```

---

## ✅ SUCCESS CHECKLIST

- [ ] Tenderly account created
- [ ] Access key obtained
- [ ] Foundry installed
- [ ] Project initialized
- [ ] Fork created
- [ ] Environment variables set
- [ ] Test contract created
- [ ] Tests running successfully
- [ ] Results visible on dashboard
- [ ] Report generated

---

## 🎉 YOU'RE READY!

**You can now:**
- ✅ Test oracle vulnerabilities safely
- ✅ Simulate flash loan attacks
- ✅ Analyze price manipulation
- ✅ Test multiple protocols
- ✅ Generate detailed reports
- ✅ Debug on Tenderly dashboard

**Next Steps:**
1. Run the basic tests
2. Analyze the results
3. Try different scenarios
4. Test real protocols
5. Report findings responsibly

---

**🔴 REMEMBER: Always test on forks, never on mainnet!**

**View full guide:** https://github.com/arp123-456/defi-security-scanner/blob/main/TENDERLY_TESTING_GUIDE.md
