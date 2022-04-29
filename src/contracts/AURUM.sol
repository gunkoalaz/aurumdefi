// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AURUM is IERC20 {

    // --- Auth -----------------------
    // rely, deny => set permission of specific address (AURUMController contract) to mint AURUM
    mapping (address => uint) public wards;
    function rely(address guy) external auth { wards[guy] = 1; } //allowed
    function deny(address guy) external auth { wards[guy] = 0; } //not allowed
    modifier auth {
        require(wards[msg.sender] == 1, "AURUM/not-authorized");
        _;
    }
    //--------------------------------

    //ERC20 token standard
    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;
    
    // address _owner;  :: no need owner variable

    constructor() {
      _name = "Gold AURUM";
      _symbol = "AURUM";
      _decimals = 18;
      wards[msg.sender] = 1;  // same as set ownership

      // _owner = msg.sender;
    }

    /**
    * @dev Returns the token owner.
    * This function turn off because using wards variable instead
    */
    // function getOwner() external view returns (address) {  //@dev Contract deployer
    //   return _owner;
    // }

    /**
    * @dev Returns the token decimals.
    */
    function decimals() external view returns (uint8) {
      return _decimals;
    }

    /**
    * @dev Returns the token symbol.
    */
    function symbol() external view returns (string memory) {
      return _symbol;
    }

    /**
    * @dev Returns the token name.
    */
    function name() external view returns (string memory) {
      return _name;
    }

    /**
    * @dev See {BEP20-totalSupply}.
    */
    function totalSupply() external view returns (uint256) {
      return _totalSupply;
    }

    /**
    * @dev See {BEP20-balanceOf}.
    */
    function balanceOf(address account) external view returns (uint256) {
      return _balances[account];
    }
      //-----------------------
      //----ACTION CONTRACT----
      //-----------------------
    function transfer(address recipient, uint256 amount) external returns (bool) {
      _transfer(msg.sender, recipient, amount);
      return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
      return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
      _approve(msg.sender, spender, amount);
      return true;
    }

    function transferFrom(address sender, address recipient, uint amount)
        public returns (bool)
    {
        require(_balances[sender] >= amount, "AURUM/insufficient-balance");
        uint senderBalance = _balances[sender] - amount;
        uint recipientBalance = _balances[recipient] + amount;
        if (sender != msg.sender && _allowances[sender][msg.sender] != maxUINT()) {
            require(_allowances[sender][msg.sender] >= amount, "AURUM/insufficient-allowance");
            _allowances[sender][msg.sender] -= amount;
        }
        _balances[sender] = senderBalance;
        _balances[recipient] = recipientBalance;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
      _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
      return true;
    }

    /**
    * @dev Atomically decreases the allowance granted to `spender` by the caller.
    *
    * This is an alternative to {approve} that can be used as a mitigation for
    * problems described in {BEP20-approve}.
    *
    * Emits an {Approval} event indicating the updated allowance.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    * - `spender` must have allowance for the caller of at least
    * `subtractedValue`.
    */

    // Return maximum number of uint256
    // Compiler 0.8.0 Can't use syntax uint(-1)
      function maxUINT() internal pure returns(uint256){
          uint256 number = type(uint256).max;
          return number;
      }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
      _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
      return true;
    }
      // MINT function only `wards` address is allowed to use
      function mint(address usr, uint wad) external auth {
          _balances[usr] += wad;
          _totalSupply += wad;
          emit Transfer(address(0), usr, wad);
      }

      function burn(address usr, uint wad) external {
          require(_balances[usr] >= wad, "AURUM/insufficient-balance");

          //If user allow msg.sender to manipulate AURUM (this case for `wards` address)
          if (usr != msg.sender && _allowances[usr][msg.sender] != maxUINT()) {
              require(_allowances[usr][msg.sender] >= wad, "AURUM/insufficient-allowance");
              _allowances[usr][msg.sender] -= wad;
          }
          _balances[usr] -= wad;
          _totalSupply -= wad;
          emit Transfer(usr, address(0), wad);
      }

    /**
    * @dev Moves tokens `amount` from `sender` to `recipient`.
    *
    * This is internal function is equivalent to {transfer}, and can be used to
    * e.g. implement automatic token fees, slashing mechanisms, etc.
    *
    * Emits a {Transfer} event.
    *
    * Requirements:
    *
    * - `sender` cannot be the zero address.
    * - `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `amount`.
    */
    function _transfer(address sender, address recipient, uint256 amount) internal {
      require(sender != address(0), "transfer from the zero address");
      require(recipient != address(0), "transfer to the zero address");

      _balances[sender] -= amount;
      _balances[recipient] += amount;
      emit Transfer(sender, recipient, amount);
    }

    /**
    * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
    *
    * This is internal function is equivalent to `approve`, and can be used to
    * e.g. set automatic allowances for certain subsystems, etc.
    *
    * Emits an {Approval} event.
    *
    * Requirements:
    *
    * - `owner` cannot be the zero address.
    * - `spender` cannot be the zero address.
    */
    function _approve(address owner, address spender, uint256 amount) internal {
      require(owner != address(0), "approve from the zero address");
      require(spender != address(0), "approve to the zero address");

      _allowances[owner][spender] = amount;
      emit Approval(owner, spender, amount);
    }

    //Transfer owner to public  :: turn off due to using 'wards' variable
    // function transferOwnership (address _to) onlyOwner external{
    //   _owner = _to;
    // }
}
