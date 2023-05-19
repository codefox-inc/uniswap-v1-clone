//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

import './Exchange.sol'; // Exchange.solをインポートして、継承はしない

contract Factory {
    mapping(address => address) public tokenToExchange; // toekn -> Exchangeのマッピング、factoryにてExchangeのアドレスを記録している

    function createExchange(address _tokenAddress) public returns (address) {
        // Exchangeをデプロイする関数
        require(_tokenAddress != address(0), 'invalid token address'); // 引数のバリデート、0アドレスは無効
        require(tokenToExchange[_tokenAddress] == address(0), 'exchange already exists'); // すでにExchangeが存在する場合は複数デプロイしない

        Exchange exchange = new Exchange(_tokenAddress); // Exchangeコントラクトをデプロイする、createを使っている
        tokenToExchange[_tokenAddress] = address(exchange); // マッピングにExchangeのアドレスを記録

        return address(exchange); // デプロイしたExchangeのアドレスを返す
    }

    function getExchange(address _tokenAddress) public view returns (address) {
        return tokenToExchange[_tokenAddress]; // マッピングからExchangeのアドレスを取得
    }
}
