# DisputeGame DApp前端

这是一个基于以太坊Sepolia测试网的DApp前端项目，用于与DisputeGame智能合约进行交互。

## 技术栈

- React + TypeScript
- Vite 构建工具
- wagmi + ethers.js/viem 进行区块链交互
- RainbowKit 钱包连接
- Tailwind CSS 样式

## 功能

- 连接以太坊钱包
- 验证Token地址
- 查看Withdraw请求列表
- 与合约交互(发起争议等)

## 开始使用

1. 安装Node.js (推荐使用v16或更高版本)

2. 安装项目依赖
```bash
npm install
```

3. 在`.env`文件中配置Alchemy API密钥和WalletConnect项目ID
```
VITE_ALCHEMY_API_KEY=您的Alchemy API密钥
VITE_WALLETCONNECT_PROJECT_ID=您的WalletConnect项目ID
```

4. 启动开发服务器
```bash
npm run dev
```

5. 构建生产版本
```bash
npm run build
```

## 合约地址

- DisputeResolver合约地址: `0x1ebAbed3057e4C53F1d7E002046b3b832a330852`
- 注册Token地址: `0x1df44B5C1160fca5AE1d9430D221A6c39CCEd00D`

## 注意事项

- 本DApp仅在Sepolia测试网上运行
- 请确保您的钱包已连接到Sepolia测试网
- 您可以从水龙头获取Sepolia测试网ETH 