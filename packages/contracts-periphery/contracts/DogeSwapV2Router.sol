pragma solidity =0.7.6;

import "@dogeswap/contracts-core/contracts/interfaces/IDogeSwapV2Factory.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./interfaces/IDogeSwapV2Router02.sol";
import "./libraries/DogeSwapV2Library.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWDC.sol";

import "hardhat/console.sol";

contract DogeSwapV2Router is IDogeSwapV2Router02 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WDC;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "DogeSwapV2Router: EXPIRED");
        _;
    }

    constructor(address _factory, address _WDC) {
        console.log("FACTORY: %s", _factory);
        console.log("WDC: %s", _WDC);

        factory = _factory;
        WDC = _WDC;
    }

    receive() external payable {
        assert(msg.sender == WDC); // only accept ETH via fallback from the WDC contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        console.log("ROUTER _addLiquidity");
        // create the pair if it doesn't exist yet
        if (IDogeSwapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            console.log("ROUTER _addLiquidity got pair");
            IDogeSwapV2Factory(factory).createPair(tokenA, tokenB);
            console.log("ROUTER _addLiquidity created pair");
        }
        (uint reserveA, uint reserveB) = DogeSwapV2Library.getReserves(factory, tokenA, tokenB);
        console.log("ROUTER _addLiquidity got reserves");
        if (reserveA == 0 && reserveB == 0) {
            console.log("ROUTER _addLiquidity a and b zero");
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            console.log("ROUTER _addLiquidity a and b not zero");
            uint amountBOptimal = DogeSwapV2Library.quote(amountADesired, reserveA, reserveB);
            console.log("ROUTER _addLiquidity b optimal");
            if (amountBOptimal <= amountBDesired) {
                console.log("ROUTER _addLiquidity b optimal lt b desired");
                require(amountBOptimal >= amountBMin, "DogeSwapV2Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                console.log("ROUTER _addLiquidity b optimal not lt b desired");
                uint amountAOptimal = DogeSwapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "DogeSwapV2Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
        console.log("ROUTER _addLiquidity returning");
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (
            uint amountA,
            uint amountB,
            uint liquidity
        )
    {
        console.log("ROUTER addLiquidity");
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = DogeSwapV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IDogeSwapV2Pair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (
            uint amountToken,
            uint amountETH,
            uint liquidity
        )
    {
        console.log("ROUTER addLiquidityETH");
        (amountToken, amountETH) = _addLiquidity(
            token,
            WDC,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = DogeSwapV2Library.pairFor(factory, token, WDC);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWDC(WDC).deposit{value: amountETH}();
        assert(IWDC(WDC).transfer(pair, amountETH));
        liquidity = IDogeSwapV2Pair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        console.log("ROUTER removeLiquidity");
        address pair = DogeSwapV2Library.pairFor(factory, tokenA, tokenB);
        IDogeSwapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IDogeSwapV2Pair(pair).burn(to);
        (address token0, ) = DogeSwapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "DogeSwapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "DogeSwapV2Router: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        console.log("ROUTER removeLiquidityETH");
        (amountToken, amountETH) = removeLiquidity(
            token,
            WDC,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWDC(WDC).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        console.log("ROUTER removeLiquidityWithPermit");
        address pair = DogeSwapV2Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        IDogeSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        console.log("ROUTER removeLiquidityETHWithPermit");
        address pair = DogeSwapV2Library.pairFor(factory, token, WDC);
        uint value = approveMax ? uint(-1) : liquidity;
        IDogeSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        console.log("ROUTER removeLiquidityETHSupportingFeeOnTransferTokens");
        (, amountETH) = removeLiquidity(token, WDC, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWDC(WDC).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountETH) {
        console.log("ROUTER removeLiquidityETHWithPermitSupportingFeeOnTransferTokens");
        address pair = DogeSwapV2Library.pairFor(factory, token, WDC);
        uint value = approveMax ? uint(-1) : liquidity;
        IDogeSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        console.log("ROUTER _swap");
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = DogeSwapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? DogeSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IDogeSwapV2Pair(DogeSwapV2Library.pairFor(factory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        console.log("ROUTER swapExactTokensForTokens");
        amounts = DogeSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DogeSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DogeSwapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        console.log("ROUTER swapTokensForExactTokens");
        amounts = DogeSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "DogeSwapV2Router: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DogeSwapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint[] memory amounts) {
        console.log("ROUTER swapExactETHForTokens");
        require(path[0] == WDC, "DogeSwapV2Router: INVALID_PATH");
        amounts = DogeSwapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DogeSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWDC(WDC).deposit{value: amounts[0]}();
        assert(IWDC(WDC).transfer(DogeSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        console.log("ROUTER swapTokensForExactETH");
        require(path[path.length - 1] == WDC, "DogeSwapV2Router: INVALID_PATH");
        amounts = DogeSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "DogeSwapV2Router: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DogeSwapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWDC(WDC).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        console.log("ROUTER swapExactTokensForETH");
        require(path[path.length - 1] == WDC, "DogeSwapV2Router: INVALID_PATH");
        amounts = DogeSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DogeSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DogeSwapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWDC(WDC).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint[] memory amounts) {
        console.log("ROUTER swapETHForExactTokens");
        require(path[0] == WDC, "DogeSwapV2Router: INVALID_PATH");
        amounts = DogeSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "DogeSwapV2Router: EXCESSIVE_INPUT_AMOUNT");
        IWDC(WDC).deposit{value: amounts[0]}();
        assert(IWDC(WDC).transfer(DogeSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        console.log("ROUTER _swapSupportingFeeOnTransferTokens");
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = DogeSwapV2Library.sortTokens(input, output);
            IDogeSwapV2Pair pair = IDogeSwapV2Pair(DogeSwapV2Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1, ) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = DogeSwapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? DogeSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        console.log("ROUTER swapExactTokensForTokensSupportingFeeOnTransferTokens");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DogeSwapV2Library.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            "DogeSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) {
        console.log("ROUTER swapExactETHForTokensSupportingFeeOnTransferTokens");
        require(path[0] == WDC, "DogeSwapV2Router: INVALID_PATH");
        uint amountIn = msg.value;
        IWDC(WDC).deposit{value: amountIn}();
        assert(IWDC(WDC).transfer(DogeSwapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            "DogeSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        console.log("ROUTER swapExactTokensForETHSupportingFeeOnTransferTokens");
        require(path[path.length - 1] == WDC, "DogeSwapV2Router: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DogeSwapV2Library.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WDC).balanceOf(address(this));
        require(amountOut >= amountOutMin, "DogeSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWDC(WDC).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) public pure virtual override returns (uint amountB) {
        return DogeSwapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountOut) {
        return DogeSwapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountIn) {
        return DogeSwapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return DogeSwapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return DogeSwapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
