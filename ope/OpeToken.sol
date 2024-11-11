// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OPEReflectToken is IERC20, Ownable, ReentrancyGuard {
    string public name = "OPE DAO Token";
    string public symbol = "OPE";
    uint8 public decimals = 18;
    uint256 private _totalSupply = 3000000 * 10 ** uint256(decimals);
    uint256 public taxFee = 10;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _reflectionTotal = (MAX - (MAX % _totalSupply));
    uint256 private _totalFeesDistributed;

    uint256 public constant MIN_HOLDING_FOR_REFLECTION = 1000 * 10 ** 18;

    mapping(address => uint256) private _reflectionBalances;
    mapping(address => uint256) private _tokenBalances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromRewards;

    event TokensReflected(uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {
        _reflectionBalances[initialOwner] = _reflectionTotal;
        _isExcludedFromFee[initialOwner] = true;
        _isExcludedFromRewards[initialOwner] = true;
        emit Transfer(address(0), initialOwner, _totalSupply);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromRewards[account]) return _tokenBalances[account];
        return tokenFromReflection(_reflectionBalances[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function tokenFromReflection(uint256 reflectionAmount) private view returns (uint256) {
        require(reflectionAmount <= _reflectionTotal, "Amount must be less than total reflections");
        return reflectionAmount / _getRate();
    }

    function _getRate() private view returns (uint256) {
        return _reflectionTotal / _totalSupply;
    }

    function _transfer(address sender, address recipient, uint256 amount) private nonReentrant {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 fee = 0;
        if (!_isExcludedFromFee[sender]) {
            fee = (amount * taxFee) / 100;
            _reflectTokens(fee);
            amount -= fee;
        }

        uint256 currentRate = _getRate();
        uint256 reflectionAmount = amount * currentRate;
        uint256 reflectionFee = fee * currentRate;

        _reflectionBalances[sender] -= (amount + fee) * currentRate;
        _reflectionBalances[recipient] += reflectionAmount;

        emit Transfer(sender, recipient, amount);
    }

    function _reflectTokens(uint256 fee) private {
        _reflectionTotal -= fee * _getRate();
        _totalFeesDistributed += fee;
        emit TokensReflected(fee);
    }

    function claimReflection() external nonReentrant {
        require(balanceOf(msg.sender) >= MIN_HOLDING_FOR_REFLECTION, "Minimum holding required to claim reflections");
        uint256 reflection = reflectionOf(msg.sender);
        require(reflection > 0, "No reflection to claim");
        _reflectionBalances[msg.sender] += reflection;
        emit Transfer(address(this), msg.sender, reflection);
    }

    function reflectionOf(address account) public view returns (uint256) {
        uint256 totalSupplyExcludingReflection = _totalSupply - _totalFeesDistributed;
        if (balanceOf(account) < MIN_HOLDING_FOR_REFLECTION || totalSupplyExcludingReflection == 0) {
            return 0;
        }
        return (balanceOf(account) * _totalFeesDistributed) / totalSupplyExcludingReflection;
    }

    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        _isExcludedFromFee[account] = excluded;
    }

    function setExcludedFromRewards(address account, bool excluded) external onlyOwner {
        _isExcludedFromRewards[account] = excluded;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
