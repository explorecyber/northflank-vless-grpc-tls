# northflank-vless-grpc-tls

这是一个可直接部署到 **Northflank**（或任意支持 Docker 的平台）的 Xray (VLESS + gRPC + TLS) 项目模版。项目包含：

- `Dockerfile`：构建运行镜像
- `entrypoint.sh`：启动时用环境变量渲染配置并启动 xray
- `config.template.json`：服务端 xray 配置模板（gRPC + TLS）
- `client-config-example.json`：给客户端下载的示例配置
- `.dockerignore`
- `README.md`：部署与变量说明

---

## 文件：`Dockerfile`
```Dockerfile
FROM debian:12-slim

# 安装必要工具
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl bash unzip procps gettext-base \
  && rm -rf /var/lib/apt/lists/*

ENV XRAY_VERSION=1.8.6
WORKDIR /opt/xray

# 下载 xray（选择稳定版本号或用 ARG）
RUN curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" -o /tmp/xray.zip \
  && unzip /tmp/xray.zip -d /opt/xray \
  && rm /tmp/xray.zip \
  && chmod +x /opt/xray/xray

# 复制配置模板与启动脚本
COPY config.template.json /etc/xray/config.template.json
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY client-config-example.json /etc/xray/client-config-example.json
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443/tcp

VOLUME ["/etc/xray/certs"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

---

## 文件：`entrypoint.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

# 环境变量（可通过 Northflank 的环境变量 / secret 设置）
: "${UUID?Need UUID (client id)}"
: "${DOMAIN?Need DOMAIN (server name for TLS/SNI)}"
: "${CERT_PATH:-/etc/xray/certs/fullchain.pem}"
: "${KEY_PATH:-/etc/xray/certs/privkey.pem}"
: "${PORT:-443}"
: "${GRPC_SERVICE_NAME:-grpc}"

TEMPLATE=/etc/xray/config.template.json
OUT=/etc/xray/config.json

# 简单替换模板中的占位符
cat "$TEMPLATE" \
  | sed "s#__UUID__#${UUID}#g" \
  | sed "s#__DOMAIN__#${DOMAIN}#g" \
  | sed "s#__PORT__#${PORT}#g" \
  | sed "s#__GRPC_SERVICE_NAME__#${GRPC_SERVICE_NAME}#g" \
  > "$OUT"

# 校验证书文件
if [ ! -f "${CERT_PATH}" ] || [ ! -f "${KEY_PATH}" ]; then
  echo "[WARNING] certificate or key not found at ${CERT_PATH} / ${KEY_PATH}.\nIf you use Cloudflare origin certs, mount them to /etc/xray/certs or set CERT_PATH/KEY_PATH env."
fi

# 启动 xray
exec /opt/xray/xray -config "$OUT"
```

---

## 文件：`config.template.json`
```json
{
  "inbounds": [
    {
      "port": __PORT__,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "__UUID__", "level": 0 }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h2"],
          "certificates": [
            {
              "certificateFile": "__CERT_PATH__",
              "keyFile": "__KEY_PATH__"
            }
          ]
        },
        "grpcSettings": {
          "serviceName": "__GRPC_SERVICE_NAME__"
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} }
  ]
}
```

> **注意**：模板里 `__CERT_PATH__` 和 `__KEY_PATH__` 在 entrypoint 里未替换，以便你直接挂载密钥到容器路径（默认 `/etc/xray/certs`）。如果你需要在模板里替换这些占位符，也可在 entrypoint 中加入替换。

---

## 文件：`client-config-example.json`
```json
{
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "<优选的Cloudflare IP>",
            "port": 443,
            "users": [ { "id": "__UUID__", "encryption": "none" } ]
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "tlsSettings": {
          "serverName": "<你的域名>",
          "alpn": ["h2"]
        },
        "grpcSettings": { "serviceName": "grpc" }
      }
    }
  ]
}
```

---

## 文件：`.dockerignore`
```
tmp
.git
.gitignore
node_modules
```

---

## 文件：`README.md`
```md
# northflank-vless-grpc-tls

基于 Xray 的 VLESS+gRPC+TLS 服务模版，适合部署到 Northflank 或任意 Docker 平台。

## 快速开始

1. 在 GitHub 创建仓库并 push 本项目文件。
2. 在 Northflank 新建服务，选择从 GitHub 部署（或使用自定义 Docker 镜像）。
3. 在 Northflank 的 `Environment Variables / Secrets` 中设置下列变量：
   - `UUID` - Xray 客户端 UUID
   - `DOMAIN` - 你的域名（用于 SNI）
   - 可选：`CERT_PATH`、`KEY_PATH`（容器内路径，默认 `/etc/xray/certs/fullchain.pem` & `/etc/xray/certs/privkey.pem`）。

> 推荐做法：使用 Cloudflare 并为域名启用 `Full (strict)`。将 Cloudflare Origin Certificate 放到 Northflank 的 `certs` 目录并挂载到容器 `/etc/xray/certs`。

## 注意事项
- `config.template.json` 假设你把证书放在容器挂载目录 `/etc/xray/certs`。
- 客户端配置中使用 **优选的 Cloudflare IP**（你已有批量测延迟脚本），并在 `streamSettings.tlsSettings.serverName` 填写真实域名以实现 SNI 伪装。

## 自定义
- 如果需要在容器内动态替换证书路径或更多字段，可在 `entrypoint.sh` 加入相应 `sed` 替换逻辑。

```

---

## 使用建议
- 在 Northflank 的部署设置里把 **容器端口映射** 设置为 `443`。
- 把 Cloudflare 的 DNS 记录设置为 Proxy（橙云）并使用你优选的 IP 直连客户端（客户端无需走域名解析）以避开 GFW 对域名解析的干扰。



