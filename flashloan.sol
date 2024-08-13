// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Pool 接口
interface IPancakeV3Pool {
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

interface IBEP20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IPancakeRouter {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IWBNB is IBEP20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract FlashLoanExample {
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB 地址
    address private constant POOL = 0x36696169C63e42cd08ce11f5deeBbCeBae652050; // PancakeSwap V3 流动性池地址
    address private constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E ; // PancakeRouter 地址

    address private admin;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    function executeFlashLoan(uint256 amount0, uint256 amount1) external onlyAdmin {
        IPancakeV3Pool pool = IPancakeV3Pool(POOL);
        bytes memory data = abi.encode(WBNB, amount0, amount1);
        
        // 发起闪电贷
        pool.flash(address(this), amount0, amount1, data);
    }
      //闪电贷回调函数
    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
 

        (address tokenBorrowed, uint256 amount0Expected, uint256 amount1Expected) = abi.decode(data, (address, uint256, uint256));



        // 计算手续费
        uint256 fee = (amount1Expected * 5) / 10000; // 0.05% 的手续费
        uint256 amountToRepay = amount1Expected + fee;


        // 检查合约中的 WBNB 是否足够
        uint256 wbnbBalance = IBEP20(WBNB).balanceOf(address(this));
        require(wbnbBalance >= amountToRepay, "Insufficient WBNB balance to repay");

        // 归还贷款
        bool success = IBEP20(WBNB).transfer(POOL, amountToRepay);
        require(success, "Repayment failed");
    }

    // 提款功能
    function withdraw() external onlyAdmin {
        // 提取合约中的所有 BNB
        payable(admin).transfer(address(this).balance);

        // 提取合约中的所有 WBNB
        uint256 tokenBalance = IBEP20(WBNB).balanceOf(address(this));
        if (tokenBalance > 0) {
            bool success = IBEP20(WBNB).transfer(admin, tokenBalance);
            require(success, "Withdrawal failed");
        }
    }

    // 允许合约接收 BNB
    receive() external payable {}
}
