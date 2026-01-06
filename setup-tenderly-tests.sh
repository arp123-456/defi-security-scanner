#!/bin/bash

# 🔴 TENDERLY FORK TESTING - AUTOMATED SETUP
# This script automates the entire setup process

set -e

echo "🚀 Starting Tenderly Fork Testing Setup..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found. Please install Node.js v16+${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Node.js found: $(node --version)${NC}"

# Check Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git not found. Please install Git${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Git found: $(git --version)${NC}"

# Check Foundry
if ! command -v forge &> /dev/null; then
    echo -e "${YELLOW}⚠️  Foundry not found. Installing...${NC}"
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
fi
echo -e "${GREEN}✅ Foundry found: $(forge --version)${NC}"

echo ""
echo "📦 Setting up project..."

# Create project directory
PROJECT_DIR="tenderly-oracle-tests"
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠️  Directory $PROJECT_DIR already exists${NC}"
    read -p "Do you want to remove it and start fresh? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_DIR"
    else
        echo "Exiting..."
        exit 1
    fi
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize Foundry project
echo "🔨 Initializing Foundry project..."
forge init --no-commit . > /dev/null 2>&1

# Install dependencies
echo "📚 Installing dependencies..."
forge install OpenZeppelin/openzeppelin-contracts --no-commit > /dev/null 2>&1
forge install Uniswap/v2-periphery --no-commit > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies installed${NC}"

# Install Tenderly CLI
echo "🔧 Installing Tenderly CLI..."
if ! command -v tenderly &> /dev/null; then
    npm install -g @tenderly/cli > /dev/null 2>&1
    echo -e "${GREEN}✅ Tenderly CLI installed${NC}"
else
    echo -e "${GREEN}✅ Tenderly CLI already installed${NC}"
fi

# Create .env file
echo ""
echo "🔑 Setting up environment variables..."
cat > .env << 'EOF'
# Tenderly Configuration
TENDERLY_ACCESS_KEY=
TENDERLY_ACCOUNT_NAME=
TENDERLY_PROJECT_NAME=defi-security-testing
TENDERLY_FORK_RPC_URL=

# Optional: Etherscan API Key
ETHERSCAN_API_KEY=
EOF

echo -e "${YELLOW}⚠️  Please edit .env file with your Tenderly credentials${NC}"
echo ""
echo "To get your Tenderly credentials:"
echo "1. Go to https://tenderly.co/ and sign up (free)"
echo "2. Create a project named 'defi-security-testing'"
echo "3. Go to Settings → Authorization → Generate Access Token"
echo "4. Copy your access token and account name"
echo ""
read -p "Press Enter when you've updated the .env file..."

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Validate environment variables
if [ -z "$TENDERLY_ACCESS_KEY" ] || [ -z "$TENDERLY_ACCOUNT_NAME" ]; then
    echo -e "${RED}❌ Please set TENDERLY_ACCESS_KEY and TENDERLY_ACCOUNT_NAME in .env${NC}"
    exit 1
fi

# Login to Tenderly
echo ""
echo "🔐 Logging into Tenderly..."
tenderly login --authentication-method access-key --access-key "$TENDERLY_ACCESS_KEY" > /dev/null 2>&1
echo -e "${GREEN}✅ Logged into Tenderly${NC}"

# Create Tenderly fork
echo ""
echo "🍴 Creating Tenderly fork..."
FORK_OUTPUT=$(tenderly fork create --network mainnet --fork-name oracle-test-fork 2>&1)

# Extract fork ID from output
FORK_ID=$(echo "$FORK_OUTPUT" | grep -oP 'Fork ID: \K[a-f0-9-]+' || echo "")

if [ -z "$FORK_ID" ]; then
    echo -e "${RED}❌ Failed to create fork. Output:${NC}"
    echo "$FORK_OUTPUT"
    exit 1
fi

FORK_RPC_URL="https://rpc.tenderly.co/fork/$FORK_ID"
echo -e "${GREEN}✅ Fork created successfully!${NC}"
echo "Fork ID: $FORK_ID"
echo "RPC URL: $FORK_RPC_URL"

# Update .env with fork URL
sed -i.bak "s|TENDERLY_FORK_RPC_URL=|TENDERLY_FORK_RPC_URL=$FORK_RPC_URL|" .env
rm .env.bak

# Create foundry.toml
echo ""
echo "⚙️  Configuring Foundry..."
cat > foundry.toml << EOF
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.19"

[rpc_endpoints]
tenderly = "$FORK_RPC_URL"

[etherscan]
mainnet = { key = "\${ETHERSCAN_API_KEY}" }

[profile.default.fuzz]
runs = 256

[profile.default.invariant]
runs = 256
depth = 15
EOF

# Create test file
echo "📝 Creating test contract..."
mkdir -p test
cat > test/OracleExploit.t.sol << 'SOLEOF'
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
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ALPHA = 0xa1faa113cbE53436Df28FF0aEe54275c13B40975;
    address constant SUSHI = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
    
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    
    function setUp() public {
        console.log("=================================");
        console.log("ORACLE VULNERABILITY TEST SUITE");
        console.log("=================================");
        console.log("Block number:", block.number);
        console.log("Chain ID:", block.chainid);
        console.log("");
    }
    
    function testCheckLiquidity() public view {
        console.log("TEST 1: LIQUIDITY CHECK");
        console.log("-----------------------");
        
        address alphaPair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(ALPHA, WETH);
        if (alphaPair != address(0)) {
            (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(alphaPair).getReserves();
            address token0 = IUniswapV2Pair(alphaPair).token0();
            
            uint256 alphaReserve = token0 == ALPHA ? reserve0 : reserve1;
            uint256 wethReserve = token0 == ALPHA ? reserve1 : reserve0;
            
            console.log("ALPHA/WETH Pair:", alphaPair);
            console.log("ALPHA Reserve:", alphaReserve / 1e18, "tokens");
            console.log("WETH Reserve:", wethReserve / 1e18, "ETH");
            
            uint256 liquidityUSD = (wethReserve * 2 * 2000) / 1e18;
            console.log("Estimated Liquidity: $", liquidityUSD);
            
            if (liquidityUSD < 10000000) {
                console.log("WARNING: Low liquidity - vulnerable to manipulation!");
            }
        }
        console.log("");
    }
    
    function testPriceManipulation() public {
        console.log("TEST 2: PRICE MANIPULATION");
        console.log("--------------------------");
        
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = ALPHA;
        
        uint256[] memory amountsOut = IUniswapV2Router(UNISWAP_ROUTER).getAmountsOut(1 ether, path);
        uint256 initialPrice = amountsOut[1];
        
        console.log("Initial ALPHA price (per 1 ETH):", initialPrice / 1e18, "tokens");
        
        deal(WETH, address(this), 100 ether);
        IERC20(WETH).approve(UNISWAP_ROUTER, type(uint256).max);
        
        console.log("Executing 50 ETH swap...");
        
        uint256[] memory amounts = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            50 ether,
            0,
            path,
            address(this),
            block.timestamp + 1
        );
        
        console.log("Received:", amounts[1] / 1e18, "ALPHA tokens");
        
        uint256[] memory newAmountsOut = IUniswapV2Router(UNISWAP_ROUTER).getAmountsOut(1 ether, path);
        uint256 manipulatedPrice = newAmountsOut[1];
        
        console.log("New ALPHA price (per 1 ETH):", manipulatedPrice / 1e18, "tokens");
        
        uint256 priceChange = ((initialPrice - manipulatedPrice) * 100) / initialPrice;
        console.log("Price impact:", priceChange, "%");
        
        if (priceChange > 10) {
            console.log("CRITICAL: Price moved >10% - exploit possible!");
        }
        
        console.log("");
    }
    
    function testFlashLoanSimulation() public {
        console.log("TEST 3: FLASH LOAN ATTACK SIMULATION");
        console.log("------------------------------------");
        
        uint256 flashLoanAmount = 1000 ether;
        deal(WETH, address(this), flashLoanAmount);
        
        console.log("Flash loan amount:", flashLoanAmount / 1e18, "ETH");
        
        uint256 initialBalance = IERC20(WETH).balanceOf(address(this));
        
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = ALPHA;
        
        IERC20(WETH).approve(UNISWAP_ROUTER, type(uint256).max);
        
        console.log("Step 1: Buy ALPHA (manipulate price up)");
        uint256[] memory amounts1 = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            flashLoanAmount / 2,
            0,
            path,
            address(this),
            block.timestamp + 1
        );
        
        console.log("ALPHA received:", amounts1[1] / 1e18, "tokens");
        console.log("At this point, vulnerable protocols would allow overborrowing");
        
        console.log("Step 2: Sell ALPHA back (reverse manipulation)");
        path[0] = ALPHA;
        path[1] = WETH;
        
        IERC20(ALPHA).approve(UNISWAP_ROUTER, type(uint256).max);
        
        uint256[] memory amounts2 = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            amounts1[1],
            0,
            path,
            address(this),
            block.timestamp + 1
        );
        
        uint256 finalBalance = IERC20(WETH).balanceOf(address(this));
        uint256 slippageLoss = initialBalance - finalBalance;
        
        console.log("WETH received back:", amounts2[1] / 1e18, "ETH");
        console.log("Slippage loss:", slippageLoss / 1e18, "ETH");
        console.log("Loss percentage:", (slippageLoss * 100) / initialBalance, "%");
        console.log("");
        console.log("NOTE: In real exploit, profit comes from borrowing");
        console.log("against inflated collateral during manipulation window");
        console.log("");
    }
}
SOLEOF

echo -e "${GREEN}✅ Test contract created${NC}"

# Build project
echo ""
echo "🔨 Building project..."
forge build > /dev/null 2>&1
echo -e "${GREEN}✅ Project built successfully${NC}"

# Run tests
echo ""
echo "🧪 Running tests on Tenderly fork..."
echo ""
forge test --fork-url "$FORK_RPC_URL" -vv

# Create README
echo ""
echo "📄 Creating README..."
cat > README.md << 'EOF'
# Tenderly Oracle Vulnerability Tests

This project contains tests for oracle manipulation vulnerabilities on DeFi protocols.

## Setup Complete! ✅

Your testing environment is ready. The tests are running on a Tenderly fork.

## Quick Commands

```bash
# Run all tests
forge test --fork-url $TENDERLY_FORK_RPC_URL -vv

# Run specific test
forge test --match-test testPriceManipulation -vvv

# Run with gas reporting
forge test --gas-report

# View on Tenderly Dashboard
# Go to: https://dashboard.tenderly.co/
```

## Test Suite

1. **testCheckLiquidity** - Checks token liquidity on Uniswap
2. **testPriceManipulation** - Demonstrates price manipulation
3. **testFlashLoanSimulation** - Simulates flash loan attack

## View Results

- **Tenderly Dashboard:** https://dashboard.tenderly.co/
- **Your Fork:** Check the "Forks" section
- **Transactions:** View all test transactions with full details

## Safety

⚠️ All tests run on Tenderly forks - completely safe!
❌ Never run these on mainnet
✅ Use for security research only

## Next Steps

1. Analyze test results on Tenderly dashboard
2. Try modifying parameters (swap amounts, tokens)
3. Test against real protocol contracts
4. Report findings responsibly

## Resources

- Tenderly Docs: https://docs.tenderly.co/
- Foundry Book: https://book.getfoundry.sh/
- Security Scanner: https://github.com/arp123-456/defi-security-scanner
EOF

echo -e "${GREEN}✅ README created${NC}"

# Create run script
cat > run-tests.sh << 'EOF'
#!/bin/bash
source .env
forge test --fork-url $TENDERLY_FORK_RPC_URL -vv
EOF
chmod +x run-tests.sh

# Summary
echo ""
echo "========================================="
echo "🎉 SETUP COMPLETE!"
echo "========================================="
echo ""
echo "Your testing environment is ready!"
echo ""
echo "📁 Project directory: $PROJECT_DIR"
echo "🍴 Fork ID: $FORK_ID"
echo "🔗 RPC URL: $FORK_RPC_URL"
echo ""
echo "📊 View results on Tenderly:"
echo "   https://dashboard.tenderly.co/"
echo ""
echo "🧪 Run tests again:"
echo "   ./run-tests.sh"
echo ""
echo "📚 Read the README:"
echo "   cat README.md"
echo ""
echo "✅ All tests passed! You're ready to start testing."
echo ""
echo "⚠️  REMEMBER: Always test on forks, never on mainnet!"
echo ""
