//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IExchange {
    function ethToTokenSwap(uint256 _minTokens) external payable;

    function ethToTokenTransfer(uint256 _minTokens, address _recipient) external payable;
}

interface IFactory {
    function getExchange(address _tokenAddress) external returns (address);
}

contract Exchange is ERC20 {
    address public tokenAddress; // トークンアドレスを記録
    address public factoryAddress; // factoryアドレスを記録

    constructor(address _token) ERC20('Zuniswap-V1', 'ZUNI-V1') {
        require(_token != address(0), 'invalid token address');

        tokenAddress = _token;
        factoryAddress = msg.sender;
    }

    // 流動性を追加する関数、返り値はもらったLPトークンの量
    function addLiquidity(uint256 _tokenAmount) public payable returns (uint256) {
        if (getReserve() == 0) {
            // もしtokenのリザーブが0の場合、新たなプールとして扱う
            IERC20 token = IERC20(tokenAddress); // トークンのインスタンスを作る
            token.transferFrom(msg.sender, address(this), _tokenAmount); // トークンをコントラクトに送る

            uint256 liquidity = address(this).balance; // LPトークンの量はETHの量と同じにする
            _mint(msg.sender, liquidity); // LPトークンをmint

            return liquidity; // LPトークンの量を返す
        } else {
            // もしリtokenのザーブが0じゃない場合、既存のプールとして扱う
            uint256 ethReserve = address(this).balance - msg.value; // ETHのリザーブはmsg.valueが入る前の残高なので、この計算になる
            uint256 tokenReserve = getReserve(); // トークンのリザーブはgetReserve()で取得できる
            uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve; // トークンの量は、ETHの量とトークンのリザーブから計算し、足りているかをチェック
            require(_tokenAmount >= tokenAmount, 'insufficient token amount');

            IERC20 token = IERC20(tokenAddress); // トークンのインスタンスを作る
            token.transferFrom(msg.sender, address(this), tokenAmount);

            uint256 liquidity = (msg.value * totalSupply()) / ethReserve;
            _mint(msg.sender, liquidity); // LPトークンをmint

            return liquidity; // LPトークンの量を返す
        }
    }

    // 流動性を削除する関数、返り値はETHとトークンの量
    function removeLiquidity(uint256 _amount) public returns (uint256, uint256) {
        require(_amount > 0, 'invalid amount'); // 0より大きい量を指定する必要がある

        // LPトークンの占める割合によってもらう量を計算しておく
        uint256 ethAmount = (address(this).balance * _amount) / totalSupply(); // ETHの量は、コントラクトのETHの残高、持っているLPトークン量、LPトークンのtotalSupply量で計算
        uint256 tokenAmount = (getReserve() * _amount) / totalSupply(); // トークンの量は、トークンのリザーブ、持っているLPトークンの量、LPトークンのtotalSupplyで計算

        _burn(msg.sender, _amount); // LPトークンをburn
        payable(msg.sender).transfer(ethAmount); // ETHをcallerへ送る
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount); // トークンをcallerへ送る

        return (ethAmount, tokenAmount); // ETHとトークンの量を返す
    }

    // 当コントラクトのリザーブをゲット
    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        require(_ethSold > 0, 'ethSold is too small');

        uint256 tokenReserve = getReserve();

        return getAmount(_ethSold, address(this).balance, tokenReserve);
    }

    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0, 'tokenSold is too small');

        uint256 tokenReserve = getReserve();

        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    function ethToToken(uint256 _minTokens, address recipient) private {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(msg.value, address(this).balance - msg.value, tokenReserve);

        require(tokensBought >= _minTokens, 'insufficient output amount');

        IERC20(tokenAddress).transfer(recipient, tokensBought);
    }

    function ethToTokenTransfer(uint256 _minTokens, address _recipient) public payable {
        ethToToken(_minTokens, _recipient);
    }

    function ethToTokenSwap(uint256 _minTokens) public payable {
        ethToToken(_minTokens, msg.sender);
    }

    function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(_tokensSold, tokenReserve, address(this).balance);

        require(ethBought >= _minEth, 'insufficient output amount');

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        payable(msg.sender).transfer(ethBought);
    }

    function tokenToTokenSwap(uint256 _tokensSold, uint256 _minTokensBought, address _tokenAddress) public {
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
        require(exchangeAddress != address(this) && exchangeAddress != address(0), 'invalid exchange address');

        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(_tokensSold, tokenReserve, address(this).balance);

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);

        IExchange(exchangeAddress).ethToTokenTransfer{value: ethBought}(_minTokensBought, msg.sender);
    }

    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, 'invalid reserves');

        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;

        return numerator / denominator;
    }
}
