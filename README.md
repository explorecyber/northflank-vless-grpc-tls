
---

## 1. 环境变量说明

| 变量名          | 说明                       | 默认值    | 是否必填 |
| --------------- | -------------------------- | --------- | -------- |
| UUID            | 客户端 UUID                | 无        | 是       |
| DOMAIN          | 服务器域名（仅作参考）     | 无        | 是       |
| PORT            | 监听端口                   | 443       | 否       |
| GRPC_SERVICE_NAME| gRPC 服务名                | grpc      | 否       |

---

## 2. 运行原理

- 服务器端 Xray 不启用 TLS，仅监听纯 TCP gRPC 端口。  
- Northflank 负责 TLS 终端，提供 HTTPS 入口，做流量解密后转发给容器。  
- 客户端通过 Northflank 域名连接，使用 TLS。  

---

## 3. 部署步骤（Northflank）

1. 将本项目上传至 GitHub。  
2. 在 Northflank 创建新服务，连接到该 GitHub 仓库。  
3. 配置环境变量 `UUID`、`DOMAIN`（填写你的域名）、可选的 `PORT` 和 `GRPC_SERVICE_NAME`。  
4. 配置端口映射，监听 443 端口（TCP）。  
5. 开启 Northflank 的自动 TLS 或上传自有证书。  
6. 部署启动。  

---

## 4. 客户端配置示例

```json
{
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "your.domain.com",
            "port": 443,
            "users": [
              {
                "id": "your-uuid-here",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "tlsSettings": {
          "serverName": "your.domain.com",
          "allowInsecure": false,
          "alpn": ["h2"]
        },
        "grpcSettings": {
          "serviceName": "grpc"
        }
      }
    }
  ]
}
