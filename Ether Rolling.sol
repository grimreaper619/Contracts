
//  $$$$$$$$\ $$$$$$$$\ $$\   $$\ $$$$$$$$\ $$$$$$$\        $$$$$$$\   $$$$$$\  $$\       $$\       $$$$$$\ $$\   $$\  $$$$$$\  
//  $$  _____|\__$$  __|$$ |  $$ |$$  _____|$$  __$$\       $$  __$$\ $$  __$$\ $$ |      $$ |      \_$$  _|$$$\  $$ |$$  __$$\ 
//  $$ |         $$ |   $$ |  $$ |$$ |      $$ |  $$ |      $$ |  $$ |$$ /  $$ |$$ |      $$ |        $$ |  $$$$\ $$ |$$ /  \__|
//  $$$$$\       $$ |   $$$$$$$$ |$$$$$\    $$$$$$$  |      $$$$$$$  |$$ |  $$ |$$ |      $$ |        $$ |  $$ $$\$$ |$$ |$$$$\ 
//  $$  __|      $$ |   $$  __$$ |$$  __|   $$  __$$<       $$  __$$< $$ |  $$ |$$ |      $$ |        $$ |  $$ \$$$$ |$$ |\_$$ |
//  $$ |         $$ |   $$ |  $$ |$$ |      $$ |  $$ |      $$ |  $$ |$$ |  $$ |$$ |      $$ |        $$ |  $$ |\$$$ |$$ |  $$ |
//  $$$$$$$$\    $$ |   $$ |  $$ |$$$$$$$$\ $$ |  $$ |      $$ |  $$ | $$$$$$  |$$$$$$$$\ $$$$$$$$\ $$$$$$\ $$ | \$$ |\$$$$$$  |
//  \________|   \__|   \__|  \__|\________|\__|  \__|      \__|  \__| \______/ \________|\________|\______|\__|  \__| \______/ 
                                                                                                                            

pragma solidity 0.6.8;
// SPDX-License-Identifier: NONE

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC777/IERC777.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/introspection/IERC1820Registry.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC777/IERC777Recipient.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract EtherRolling is Ownable {
    using SafeMath for uint8;
    using SafeMath for uint256;
    struct User {
        uint256 cycle;
        address upline;
        uint256 referrals;
        uint256 payouts;
        uint256 direct_bonus;
        uint256 pool_bonus;
        uint256 match_bonus;
        uint256 deposit_amount;
        uint256 deposit_payouts;
        uint40 deposit_time;
        uint256 total_deposits;
        uint256 total_payouts;
        uint256 total_structure;
        bool isWithdrawActive;
    }
    struct matrixInfo{
        address upperLevel;
        uint256 currentPos;
        address[3] matrixRef;
        uint256 matrix_bonus;
        uint8 level;
    }
    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    IERC777 private _token;
    event DoneDeposit(address operator, address from, address to, uint256 amount, bytes userData, bytes operatorData);
    mapping(address => User) public users;
    mapping(address => matrixInfo) public matrixUser;

    uint256[] public cycles;
    uint8 public DAILY = 6; //Daily percentage income
    uint8 LOWER_LIMIT = 0;
    uint8[] public ref_bonuses = [10,10,10,10,10,8,8,8,8,8,5,5,5,5,5];  //referral bonuses        
    uint8[] public matrixBonuses = [7,7,7,7,7,10,10,10,10,10,3,3,3,3,3]; //Matrix bonuses
    uint256[] public pool_bonuses;                    // 1 => 1%
    uint40 public pool_last_draw = uint40(block.timestamp);
    uint256 public pool_cycle;
    uint256 public pool_balance;
    uint256[] public level_bonuses;
    uint8 public firstPool = 40;
    uint8 public secondPool = 30;
    uint8 public thirdPool = 20;
    uint8 public fourthPool = 10;
    address payable public admin1 = 0x231c02e6ADADc34c2eFBD74e013e416b31940d15;
    address payable public admin2 = 0xbBe1B325957fD7A33BC02cDF91a29FdE88bA60E3;
    mapping(uint256 => mapping(address => uint256)) public pool_users_refs_deposits_sum;
    mapping(uint8 => address) public pool_top;

    uint256 public total_withdraw;
    
    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event DirectPayout(address indexed addr, address indexed from, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event PoolPayout(address indexed addr, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);
    event LimitReached(address indexed addr, uint256 amount);

    constructor(address token) public {
        
        for(uint8 i=0;i<9;i++){
             pool_bonuses.push(firstPool.div(9));
        }
        for(uint8 i=0;i<9;i++){
             pool_bonuses.push(secondPool.div(9));
        }
        for(uint8 i=0;i<9;i++){
             pool_bonuses.push(thirdPool.div(9));
        }
        for(uint8 i=0;i<9;i++){
             pool_bonuses.push(fourthPool.div(9));
        }
        
        level_bonuses.push(0.5 ether);
        level_bonuses.push(1 ether);
        level_bonuses.push(3 ether);
        level_bonuses.push(5 ether);
        level_bonuses.push(10 ether);
        level_bonuses.push(20 ether);
        level_bonuses.push(30 ether);
        level_bonuses.push(50 ether);
        level_bonuses.push(70 ether);
        level_bonuses.push(100 ether);

        cycles.push(100 ether);
        cycles.push(300 ether);
        cycles.push(900 ether);
        cycles.push(2700 ether);
        _token = IERC777(token);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    function _setUpline(address _addr, address _upline) private {
        if(users[_addr].upline == address(0) && _upline != _addr && (users[_upline].deposit_time > 0 || _upline == owner())) {
            users[_addr].upline = _upline;
            users[_upline].referrals++;
            emit Upline(_addr, _upline);
            addToMatrix(_addr,_upline);
            for(uint8 i = 0; i < ref_bonuses.length; i++) {
                if(_upline == address(0)) break;

                users[_upline].total_structure++;

                _upline = users[_upline].upline;
            }
        }
    }
    function addToMatrix(address addr, address upline) private {
        address tempadd = upline;
        uint256 temp;
        while(true){
            uint256 pos = matrixUser[tempadd].currentPos;
            if(matrixUser[tempadd].matrixRef[pos] == address(0)){
                matrixUser[tempadd].matrixRef[pos] = addr;
                matrixUser[tempadd].currentPos = (pos + 1).mod(3);
                break;
            }else{
                temp =  matrixUser[tempadd].currentPos;
                matrixUser[tempadd].currentPos = (pos + 1).mod(3);
                tempadd = matrixUser[tempadd].matrixRef[temp];
            }
        }
        matrixUser[addr].upperLevel = tempadd;
    }
    
    function tokensReceived(address operator, address from, address to, uint256 amount, bytes calldata userData, bytes calldata operatorData) external {
        require(msg.sender == address(_token), "Simple777Recipient: Invalid token");
        require(users[from].upline != address(0),"No referral found. ");
        _deposit(from,amount,1);
    }

    function _deposit(address _addr, uint256 _amount, uint8 method) private {
        require(users[_addr].upline != address(0) || _addr == owner(), "No upline");

        if(users[_addr].deposit_time > 0) {
            users[_addr].cycle++;
            
            require(users[_addr].payouts >= this.maxPayoutOf(users[_addr].deposit_amount), "Deposit already exists");
            require(_amount >= users[_addr].deposit_amount && _amount <= cycles[users[_addr].cycle > cycles.length - 1 ? cycles.length - 1 : users[_addr].cycle], "Bad amount");
        }
        else {
            if(method == 0){
            require(_amount >= 0.5 ether && _amount <= cycles[0], "Bad amount");
            }
            else if(method == 1){
                require(_amount >= (5 * 10 ** 17) && _amount <= cycles[0], "Bad amount");
            }else{
                revert();
            }
        }
        users[_addr].payouts = 0;
        users[_addr].deposit_amount = _amount;
        users[_addr].deposit_payouts = 0;
        users[_addr].deposit_time = uint40(block.timestamp);
        users[_addr].total_deposits += _amount;
        users[_addr].isWithdrawActive = true;
        for(uint8 i=0;i<10;i++){
            if(users[_addr].total_deposits >= level_bonuses[i]){
                matrixUser[_addr].level = i+6;
            }
        }
        emit NewDeposit(_addr, _amount);

        if(users[_addr].upline != address(0)) {
            users[users[_addr].upline].direct_bonus += _amount / 10;

            emit DirectPayout(users[_addr].upline, _addr, _amount / 10);
        }

        _poolDeposits(_addr, _amount);

        if(pool_last_draw + 1 days < block.timestamp) {
            _drawPool();
        }
        if(method == 0){
            admin1.transfer(_amount.mul(95).div(1000));
            admin2.transfer(_amount.mul(5).div(1000));
        }else if(method == 1){
            _token.send(admin1,_amount.mul(95).div(1000),"Admin 1 commision");
            _token.send(admin2,_amount.mul(5).div(1000),"Admin 2 commision");
        }else{
            revert();
        }
    }
    
    function _poolDeposits(address _addr, uint256 _amount) private {
        pool_balance += _amount / 33;

        address upline = users[_addr].upline;

        if(upline == address(0)) return;
        
        pool_users_refs_deposits_sum[pool_cycle][upline] += _amount;

        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == upline) break;

            if(pool_top[i] == address(0)) {
                pool_top[i] = upline;
                break;
            }

            if(pool_users_refs_deposits_sum[pool_cycle][upline] > pool_users_refs_deposits_sum[pool_cycle][pool_top[i]]) {
                for(uint8 j = i + 1; j < pool_bonuses.length; j++) {
                    if(pool_top[j] == upline) {
                        for(uint8 k = j; k <= pool_bonuses.length; k++) {
                            pool_top[k] = pool_top[k + 1];
                        }
                        break;
                    }
                }

                for(uint8 j = uint8(pool_bonuses.length - 1); j > i; j--) {
                    pool_top[j] = pool_top[j - 1];
                }

                pool_top[i] = upline;

                break;
            }
        }
    }

    function _refPayout(address _addr, uint256 _amount) private {
        address up = users[_addr].upline;

        for(uint8 i = 0; i < ref_bonuses.length; i++) {
            if(up == address(0)) break;
            
            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount * ref_bonuses[i] / 100;
                
                users[up].match_bonus += bonus;

                emit MatchPayout(up, _addr, bonus);
            }

            up = users[up].upline;
        }
    }

    function _drawPool() private {
        pool_last_draw = uint40(block.timestamp);
        pool_cycle++;

        uint256 draw_amount = pool_balance / 10;

        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == address(0)) break;

            uint256 win = draw_amount * pool_bonuses[i] / 100;

            users[pool_top[i]].pool_bonus += win;
            pool_balance -= win;

            emit PoolPayout(pool_top[i], win);
        }
        
        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            pool_top[i] = address(0);
        }
    }
    function calcMatrixBonus(address addr, uint256 value) private{
        address uplevel = matrixUser[addr].upperLevel;
        uint8 i = 0;
        while(uplevel != address(0) && matrixUser[uplevel].level >= i && i<16){
            matrixUser[uplevel].matrix_bonus += value.mul(matrixBonuses[i]).div(100);
            uplevel = matrixUser[uplevel].upperLevel;
            i++;
        }
    }

    function deposit(address _upline) payable external {
        _setUpline(msg.sender, _upline);
        _deposit(msg.sender, msg.value, 0);
    }

    function withdraw(uint8 coin) external {
        //coin = 1 --> token withdraw
        //coin = 0 --> ether withdraw
        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender);

        // Deposit payout
        if(to_payout > 0) {
            if(users[msg.sender].payouts + to_payout > max_payout) {
                to_payout = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].deposit_payouts += to_payout;
            users[msg.sender].payouts += to_payout;

            _refPayout(msg.sender, to_payout);
        }
        
        // Direct payout
        if(users[msg.sender].payouts < max_payout && users[msg.sender].direct_bonus > 0) {
            uint256 direct_bonus = users[msg.sender].direct_bonus;

            if(users[msg.sender].payouts + direct_bonus > max_payout) {
                direct_bonus = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].direct_bonus -= direct_bonus;
            users[msg.sender].payouts += direct_bonus;
            to_payout += direct_bonus;
        }
        
        // Pool payout
        if(users[msg.sender].payouts < max_payout && users[msg.sender].pool_bonus > 0) {
            uint256 pool_bonus = users[msg.sender].pool_bonus;

            if(users[msg.sender].payouts + pool_bonus > max_payout) {
                pool_bonus = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].pool_bonus -= pool_bonus;
            users[msg.sender].payouts += pool_bonus;
            to_payout += pool_bonus;
        }

        // Match payout
        if(users[msg.sender].payouts < max_payout && users[msg.sender].match_bonus > 0) {
            uint256 match_bonus = users[msg.sender].match_bonus;

            if(users[msg.sender].payouts + match_bonus > max_payout) {
                match_bonus = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].match_bonus -= match_bonus;
            users[msg.sender].payouts += match_bonus;
            to_payout += match_bonus;
        }
        
         // Matrix payout
        if(users[msg.sender].payouts < max_payout && matrixUser[msg.sender].matrix_bonus > 0) {
            if(users[msg.sender].isWithdrawActive){
                uint256 matrix_bonus = matrixUser[msg.sender].matrix_bonus;
                if(users[msg.sender].payouts + matrix_bonus > max_payout) {
                    matrix_bonus = max_payout - users[msg.sender].payouts;
                }
                matrixUser[msg.sender].matrix_bonus -= matrix_bonus;
                users[msg.sender].payouts += matrix_bonus;
                to_payout += matrix_bonus;
            } else{
                matrixUser[msg.sender].matrix_bonus = 0;
            }
        }
        
        require(to_payout > 0, "Zero payout");
        
        users[msg.sender].total_payouts += to_payout;
        total_withdraw += to_payout;
        uint256 matrixbonus = to_payout.mul(20).div(100);
        calcMatrixBonus(msg.sender,matrixbonus);
        to_payout -= to_payout.mul(20).div(100);
        if(coin == 0){
           payable(msg.sender).transfer(to_payout); 
        }
        else if(coin == 1){
            _token.send(msg.sender,to_payout,"Token Withdrawed");
        }
        emit Withdraw(msg.sender, to_payout);

        if(users[msg.sender].payouts >= max_payout) {
            users[msg.sender].isWithdrawActive = false;
            emit LimitReached(msg.sender, users[msg.sender].payouts);
        }
    }
    
    
    function drawPool() external onlyOwner {
        _drawPool();
    }
    function setDaily(uint8 perc) external onlyOwner {
        require(perc >= LOWER_LIMIT,"Invalid daily percentage");
        DAILY = perc;
    }
    function maxPayoutOf(uint256 _amount) pure external returns(uint256) {
        return _amount * 3;
    }

    function payoutOf(address _addr) view external returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxPayoutOf(users[_addr].deposit_amount);
        if(users[_addr].isWithdrawActive){
            
            if(users[_addr].deposit_payouts < max_payout) {
                payout = (users[_addr].deposit_amount * ((block.timestamp - users[_addr].deposit_time) / 1 days).mul(DAILY).div(1000)) - users[_addr].deposit_payouts;
            
                if(users[_addr].deposit_payouts + payout > max_payout) {
                    payout = max_payout - users[_addr].deposit_payouts;
                }
            }
        }else{
            payout = 0;
        }
    }

    function userInfo(address _addr) view external returns(address upline, uint40 deposit_time, uint256 deposit_amount, uint256 payouts, uint256 direct_bonus, uint256 pool_bonus, uint256 match_bonus) {
        return (users[_addr].upline, users[_addr].deposit_time, users[_addr].deposit_amount, users[_addr].payouts, users[_addr].direct_bonus, users[_addr].pool_bonus, users[_addr].match_bonus);
    }

    function userInfoTotals(address _addr) view external returns(uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure) {
        return (users[_addr].referrals, users[_addr].total_deposits, users[_addr].total_payouts, users[_addr].total_structure);
    }
    
    function matrixBonusInfo(address addr) view external returns(address[3] memory direct_downline, uint256 matrix_bonus, uint256 current_level){
        return(matrixUser[addr].matrixRef,matrixUser[addr].matrix_bonus,matrixUser[addr].level);
    }
    
    function contractInfo() view external returns(uint256 _total_withdraw, uint40 _pool_last_draw, uint256 _pool_balance, uint256 _pool_lider) {
        return (total_withdraw, pool_last_draw, pool_balance, pool_users_refs_deposits_sum[pool_cycle][pool_top[0]]);
    }

    function poolTopInfo() view external returns(address[] memory addrs, uint256[] memory deps) {
        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == address(0)) break;

            addrs[i] = pool_top[i];
            deps[i] = pool_users_refs_deposits_sum[pool_cycle][pool_top[i]];
        }
    }
}

//Creator  : Grim Reaper
//Telegram : @grimreaper916