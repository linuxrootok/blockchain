// SPDX-License-Identifier: MIT
// Tyler
pragma solidity 0.8.20;

import "./Erc20.sol";

/**
 * @title ERC20代币线性释放
 * @dev 这个合约会将ERC20代币线性释放给受益人
 * 受益人为所有拥有下级代理购买行为的人
 * 合约上的代币都会遵循线性释放周期，并且需要管理者调用`release()`函数提取。
 * Token的购买与USDT的购买是同等的奖励规则
 */
contract TokenVesting {
    // 事件
    event ERC20Released(address indexed token, uint256 amount); // 提币事件
    event USDTSent(address indexed token, uint256 amount); //发送USDT事件

    // 状态变量
    mapping(address => uint256) public erc20Released; // 代币地址->释放数量的映射，记录当前就绪待释放代币数量

    uint256 public immutable _start; // when start
    uint256[5] public start; // 归属期起始时间戳
    uint256[5] public duration; // 归属期 (秒)
    address public immutable owner; // Owner

    // 是否指定一级代理
    bool private isDefineTopLevel = false;

    // 定义推广收入比例
    uint8[4] public rewardPercentages = [0, 11, 6, 3];

    // 定义用户个数
    uint256 public nums; //用户个数
    // 定义USDT发送记录及个数
    address[] public addressUsdt;
    uint256[] public amountUsdt;

    // 定义用户结构
    struct Agent {
        uint8 level;
        address user;
        uint256 value; //token数量
        uint256 usdtAmount; //usdt数量    
    }
    // 定义代理结构
    struct AgentsIndex {
        uint256 k; //对应Agent的key值
        address referrer; //上级代理地址
        address userAddr; //自己的地址 
    }
    // 定义奖励结构
    mapping(address => uint256) public rewards; //token奖励数据
    mapping(address => uint256) public rewardsUsdt; //usdt奖励数据
    // 存储每个地址的代理信息
    mapping(uint256 => Agent) public agents;

    // 存储代理KEY
    mapping(address => AgentsIndex) public agentsIndex;
    /**
     * @dev 初始化释放周期(秒), 起始时间戳(当前区块链时间戳)
     */
    constructor(
 
    ) {
        _start = block.timestamp;
        uint256 _start1 = _start+(24*3600*30);
        uint256 _start2 = _start+(24*3600*60);
        uint256 _start3 = _start+(24*3600*90);
        uint256 _start4 = _start+(24*3600*120);
        start = [0, _start1, _start2, _start3, _start4];
        duration = [0, 10, 20, 30, 40];
        owner = msg.sender;
    }
    // only owner
    modifier onlyOwner(){
        require(msg.sender == owner, "Only owner for action");
        _;
    }
    /**
     * @dev 写入0级推广者的额度，不参与活动，无奖励，通常应该为项目发起人，只为统计和查找线索
     * @param _level 由管理员指定的等级，通过为0级，其他从此引出的推广者皆为0+1＝1级
     * @param _addr 指定推广者的地址
     * @param _value 指定推广者初始Token数量值
     * @param _usdtValue 指定推广者的初始USDT数量值
     */
    function setAgentsTopLevel (uint8 _level, address _addr, uint256 _value, uint256 _usdtValue) public onlyOwner returns(bool){
        require(_level == 0, "Only 0 level");
        require(_addr != msg.sender, "Not self loop");
        agents[nums+1] = Agent(_level, _addr, _value, _usdtValue);
        nums +=1;
        agentsIndex[_addr].k = nums;
        agentsIndex[_addr].userAddr = _addr;
        return true;
    }

    /**
     * @dev 成为代理的方法 2级代理或者以下3级代理 只允许管理员运行
     * @param _Referrer 上级推广者地址
     * @param _Value 此推广者的Token的购买数量
     * @param _UsdtValue 此推广者的USDT的购买数量
    */
    function becomeAgent(address _Referrer, uint256  _Value, uint256 _UsdtValue) public returns(bool){
        require(_Referrer != msg.sender, "No loop!");
        uint256 agentsKey = agentsIndex[_Referrer].k;
        // 同一个用户只允许成为仅一个推广者的下级
        //require(agentsIndex[msg.sender].k == 0, "Only be one owner");
        uint8 _level = 0;
        // 判断是否指定一级代理
        if(isDefineTopLevel){
            require(agentsKey != 0, "No referrer");
        }
        // 增加判断是否已存在，是则更新信息，累积token,否则运行新分支
        if (agentsIndex[msg.sender].k == 0){
            // referrer等级
            uint8 agentLevel = agents[agentsKey].level;

            // 确定代理级别
            _level = agentLevel + 1;

            if (_level > 3) {
                _level = 3;
            }
            // 更新代理信息
            agents[nums+1] = Agent(_level, msg.sender, _Value, _UsdtValue);
            agentsIndex[msg.sender] = AgentsIndex(nums+1, _Referrer, msg.sender);
            nums += 1;
        }
        else{
            if (_UsdtValue > 0){
                // 累加usdt token数目
                agents[agentsIndex[msg.sender].k].usdtAmount += _UsdtValue;
            }
            if (_Value > 0){
                // 累加token数目
                agents[agentsIndex[msg.sender].k].value += _Value;
            }
        }
        if (_Value > 0){
            setShareReferralReward(msg.sender, _Value, 1);
        }
        if(_UsdtValue > 0){
            setShareReferralReward(msg.sender, _UsdtValue, 2);
        }
        
        return true;
    }

    /**
     * @dev 获取奖励返回额度,从下级往上匹配返回,给所有比其等级高的推广者奖励
     * @param _address: 推广者地址
     * #param _count: 推广者购买的额度
     * #param _remark: 0指定为token类型资产 1指定为USDT类型资产
     */
    function setShareReferralReward(address _address, uint256 _count, uint8 _remark) internal {
        require(_remark == 1 || _remark == 2 , "Bad param");
        // 计算二级，返给1级推广者
        // 获取当前用户的key值
        //uint256 kk = agentsIndex[_address].k;
        // 初始化返回额度为0
        uint256 tNum = 0;
        // 获取到上级的地址
        address a = agentsIndex[_address].referrer;
        // 查找上级的key值
        uint256 b = agentsIndex[a].k;
        // 判断上级是否为1级或者低于1级代理，数字越大代理级别越低
        if (agents[b].level > 0){
            // 获取当前参数地址的token数
            // 上级推广者获得的比例 x 当前用户的token数，即为奖励
            tNum = (rewardPercentages[agents[b].level] * _count) / 100;
        }
        // 如果有奖励，则累加进相应推广者的帐户
        if (tNum > 0){
            if (_remark == 1){
                // token累加
                rewards[a] += tNum;
            }else if(_remark == 2){
                // usdt累加
                rewardsUsdt[a] += tNum;
            }
            
        }
        // 如果还有上级推广者，则继续做同样的事
        if (agents[b].level > 1){
            setShareReferralReward(a, _count, _remark);
        }
        else{
            return;
        }

    }

    /**
     * @dev 返回获取到指定用户的奖励值.必先运行 setShareReferralReward
     * @param _address: 指定用户帐户
     */
    function getPorsonShareReferralReward(address _address) public view returns(uint256[2] memory res){   
        res = [rewards[_address], rewardsUsdt[_address]];
    }

    /**
     * @dev 计算已释放的代币。只会在足够代币可以支付的情况下才会释放至推广者，一旦到达指定释放周期，将完全释放
     * 调用vestedAmount()函数计算可提取的代币数量，然后transfer给受益人。
     * 释放 {ERC20Released} 事件.
     * @param token为Token合约布署后的地址
     * @param _stepMonth为阶段性释放参数 1为1月，以此类推 1－4个月
     */
    function release(address payable token, uint8 _stepMonth) onlyOwner public{

        require(nums > 0, "Nobody joined");
        uint256 nowThisBalance = IERC20(token).balanceOf(address(this));
        require(nowThisBalance > 0, 'No enougth token');
        require(_stepMonth > 0 && _stepMonth <= 4, "Not fix release for 4 month");
        uint256 currentBalance = vestedAmount(token, uint256(block.timestamp), _stepMonth);
        require(currentBalance != 0, "Time limit that not yet release token");
        // 调用vestedAmount()函数计算可提取的代币数量
        uint256 releasable = currentBalance - erc20Released[token];
        // 更新已释放代币数量   
        erc20Released[token] += releasable; 
        
        uint256 i = 1;
        while(i <= nums){
            // 验证该用户是否已经提到足够的币
            uint256 diffVal = agents[i].value - IERC20(token).balanceOf(agents[i].user);
            // 只有在未提足够币的情况下，才释放给相应的用户
            if (diffVal > 0){
                if (erc20Released[token] > diffVal){
                    // 转代币给受益人
                    emit ERC20Released(token, releasable);
                    IERC20(token).transfer(agents[i].user, diffVal);
                }      
            }           
            i++;        
        }   
    }

    /**
     * @dev 根据线性释放公式，计算已经释放的数量。开发者可以通过修改这个函数，自定义释放方式。
     * @param token: 代币地址
     * @param timestamp: 查询的时间戳
     * @param stepMonth: 按月释放，1为此合约布署后的第1个月
     */
    function vestedAmount(address token, uint256 timestamp, uint8 stepMonth) public view returns (uint256) {
        require(stepMonth > 0 && stepMonth <= 4, "All the Token will be release in 4 month");
        // 合约里总共收到了多少代币（当前余额 + 已经提取）
        uint256 totalAllocation = (IERC20(token).balanceOf(address(this))* duration[stepMonth]) / 100 + erc20Released[token];
        // 根据线性释放公式，计算已经释放的数量
        if (timestamp < _start) {
            return 0;
        } else if (timestamp > start[stepMonth]) {
            return totalAllocation;
        } else {
            //return 0;
            if (stepMonth == 1){
                return (totalAllocation * (timestamp - _start)) / (24*3600*90);
            }
            else{
                return (totalAllocation * (timestamp - start[stepMonth-1])) / (24*3600*90);
            }         
        }
    }

    /**
     * @dev 使用外部合约发送USDT奖励
     * @param usdtContractAddress 外部合约地址
     * @param userAddress 获奖用户地址
     * @param amount 奖励USDT数量
     */
    function transferUSDT(address usdtContractAddress, address userAddress, uint256 amount) public onlyOwner{
        // Event sent usdt log
        emit USDTSent(userAddress, amount);
        // Call the usdt contract's transfer function
        ERC20(usdtContractAddress).transfer(userAddress, amount);
        // Update the record
        addressUsdt.push(userAddress);
        amountUsdt.push(amount);
    }
}