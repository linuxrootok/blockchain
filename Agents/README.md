## Deploy at address: https://testnet.bscscan.com/address/0x4fE87A9E85a5Bbe74e97b8732E1a9D92862248b1#code
# Descript project 项目合约说明如下
## Name: Tokenvesting 合约：TokenVesting

##### Ready to run this project contract 项目发布后预备工作
* setAgentsTopLevel 合约拥有者调用生成0（顶）级推广者，不计入奖励，只作引入和统计

##### becomeAgent: set a msg.sender to be an agent 前端入口
* becomeAgent 函数接入购买量 token或usdt的数量，并内嵌入统计奖励数据存储，实现了只要购买就写入奖励(包括token和USDT)

##### Important function 重要函数说明
* vestedAmount 函数进行计算并控制就绪代币线性释放的数量，可进行实时查看已就绪的代币数量，任何人可随时查看，增加项目的透明和可预见性

* transferUSDT 函数，用作从另外一个合约帐户发送usdt给参与者，只有参与者的下级代理方能得到相应比例的奖励，Token代币和USDT是同等的奖励比例

* release 函数，目前页面只由合约拥有者在释放周期满后手动释放,按阶段(1-4个月)依照规定的比例进行释放

##### 关键贮存变量：
- rewards 记录每次购买所获得奖励的代币Token数量
- rewardsUsdt记录每次购买所获得奖励的USDT数量
- agents 记录参与者的购买总量(代币Token以入USDT)

## Contract type: Erc20 合约：Erc20
* Only for create token and transfer 仅提供生产代币以及转发

* Set roles 做了权限控制，只有合约拥有者才可以发行货币，并转帐给TokenVesting合约，以作代币释放
