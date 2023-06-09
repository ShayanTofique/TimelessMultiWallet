// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

contract TimelessMultiWallet {
    struct User {
        string email;
        string password;
        string language;
        string seedPhrase;
        bool has2FA;
        bool isRegistered;
    }

    struct Transaction {
        address from;
        address to;
        uint256 amount;
        string currency;
        uint256 timestamp;
    }

    mapping(address => Transaction[]) public transactions;

    uint256[] public balances;
    mapping(address => User) users;
    mapping(address => mapping(string => bool)) connectedWallets;
    mapping(address => mapping(string => uint256)) public walletBalances;
    mapping(address => mapping(address => uint256)) public exchangeRates;

    string[] public walletNames = [
        "Metamask",
        "Trust",
        "Coinbase",
        "Exodus",
        "Binance",
        "Phantom",
        "TimeLess"
    ];

    event NewUserRegistered(address indexed userAddress, string email);
    event UserSignedIn(address indexed userAddress, string email);
    event PaymentSent(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        string indexed cryptocurrency
    );

    function registerUser(
        string memory _email,
        string memory _password,
        string memory _language,
        string memory _seedPhrase
    ) public {
        require(bytes(_email).length > 0, "Email address cannot be empty.");
        require(bytes(_password).length > 0, "Password cannot be empty.");
        require(
            bytes(_language).length > 0,
            "Language selection cannot be empty."
        );
        require(bytes(_seedPhrase).length > 0, "Seed phrase cannot be empty.");
        require(!users[msg.sender].isRegistered, "User already registered.");

        User memory newUser = User({
            email: _email,
            password: _password,
            language: _language,
            seedPhrase: _seedPhrase,
            has2FA: false,
            isRegistered: true
        });

        users[msg.sender] = newUser;

        emit NewUserRegistered(msg.sender, _email);
    }

    function getAllTransactions() public view returns (Transaction[] memory) {
        return transactions[msg.sender];
    }

    function signInUser(
        string memory _email,
        string memory _password,
        bool _has2FA
    ) public {
        require(bytes(_email).length > 0, "Email address cannot be empty.");
        require(bytes(_password).length > 0, "Password cannot be empty.");
        require(users[msg.sender].isRegistered, "User not registered.");
        require(
            keccak256(bytes(users[msg.sender].email)) ==
                keccak256(bytes(_email)),
            "Invalid email or password."
        );
        require(
            keccak256(bytes(users[msg.sender].password)) ==
                keccak256(bytes(_password)),
            "Invalid email or password."
        );
        if (users[msg.sender].has2FA) {
            require(_has2FA, "2-factor authentication code required.");
        }

        emit UserSignedIn(msg.sender, _email);
    }

    function connectWallet(string memory _walletName) public {
        require(users[msg.sender].isRegistered, "User not registered.");
        connectedWallets[msg.sender][_walletName] = true;
    }

    function disconnectWallet(string memory _walletName) public {
        require(users[msg.sender].isRegistered, "User not registered.");
        connectedWallets[msg.sender][_walletName] = false;
    }

    function isWalletConnected(address _userAddress, string memory _walletName)
        public
        view
        returns (bool)
    {
        return connectedWallets[_userAddress][_walletName];
    }

    function enable2FA() public {
        require(users[msg.sender].isRegistered, "User not registered.");
        require(
            !users[msg.sender].has2FA,
            "2-factor authentication already enabled."
        );

        users[msg.sender].has2FA = true;
    }

    function disable2FA() public {
        require(users[msg.sender].isRegistered, "User not registered.");
        require(
            users[msg.sender].has2FA,
            "2-factor authentication not enabled."
        );

        users[msg.sender].has2FA = false;
    }

    function getUser(address _userAddress)
        public
        view
        returns (
            string memory,
            string memory,
            string memory,
            string memory,
            bool,
            bool
        )
    {
        User memory user = users[_userAddress];
        return (
            user.email,
            user.password,
            user.language,
            user.seedPhrase,
            user.has2FA,
            user.isRegistered
        );
    }

    function addBalance(string memory _walletName, uint256 _balance) public {
        walletBalances[msg.sender][_walletName] += _balance;
    }

    function getTotalBalance() public view returns (uint256) {
        uint256 totalBalance;
        for (uint256 i = 0; i < walletNames.length; i++) {
            string memory walletName = walletNames[i];
            if (connectedWallets[msg.sender][walletName]) {
                totalBalance += walletBalances[msg.sender][walletName];
            }
        }
        return totalBalance;
    }

    function getIndividualBalances()
        public
        returns (string[] memory, uint256[] memory)
    {
        for (uint256 i = 0; i < walletNames.length; i++) {
            string memory walletName = walletNames[i];
            if (connectedWallets[msg.sender][walletName]) {
                balances.push(walletBalances[msg.sender][walletName]);
            }
        }
        return (walletNames, balances);
    }

    function setExchangeRate(
        address token1,
        address token2,
        uint256 rate
    ) public {
        exchangeRates[token1][token2] = rate;
    }

    function getExchangeRate(address token1, address token2)
        public
        view
        returns (uint256)
    {
        return exchangeRates[token1][token2];
    }

    // function swapTokens(
    //     address token1,
    //     uint256 amount1,
    //     address token2
    // ) public {
    //     uint256 rate = exchangeRates[token1][token2];
    //     require(rate > 0, "Exchange rate not set");

    //     uint256 amount2 = (amount1 * rate) / 1 ether;
    //     require(
    //         Token(token1).transferFrom(msg.sender, address(this), amount1),
    //         "Token transfer failed"
    //     );
    //     require(
    //         Token(token2).transfer(msg.sender, amount2),
    //         "Token transfer failed"
    //     );
    // }

    function receivePayment(uint256 amount, string calldata cryptocurrency)
        external
    {
        require(
            walletBalances[msg.sender][cryptocurrency] + amount >=
                walletBalances[msg.sender][cryptocurrency],
            "Integer overflow detected"
        );
        walletBalances[msg.sender][cryptocurrency] += amount;
    }

    function sendPayment(
        address recipient,
        uint256 amount,
        string calldata cryptocurrency
    ) external {
        require(
            walletBalances[msg.sender][cryptocurrency] >= amount,
            "Insufficient balance"
        );
        walletBalances[msg.sender][cryptocurrency] -= amount;
        walletBalances[recipient][cryptocurrency] += amount;

        emit PaymentSent(msg.sender, recipient, amount, cryptocurrency);
    }

    function getQRCode(string calldata cryptocurrency)
        external
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    walletBalances[msg.sender][cryptocurrency]
                )
            );
    }
}
