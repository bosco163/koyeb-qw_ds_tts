# ==========================================
# 阶段 1: 构建 Gemini (Go)
# ==========================================
FROM golang:1.21-alpine AS go-builder
WORKDIR /build
RUN apk add --no-cache git
# 克隆 Gemini 项目
RUN git clone https://github.com/erxiansheng/gemininixiang.git .
# 修复核心：手动初始化 module 并下载依赖
RUN go mod init gemini && go mod tidy
# 编译成名为 server 的二进制文件
RUN go build -o server .

# ==========================================
# 阶段 2: 构建最终镜像 (基于 Python)
# ==========================================
FROM python:3.10-slim

# 1. 安装基础工具 和 Node.js 20
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    curl \
    gnupg \
    build-essential \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && npm install -g yarn \
    # 清理缓存减小镜像体积
    && rm -rf /var/lib/apt/lists/*

# ===========================
# 2. 部署 TTS (Python) -> 端口 5050
# ===========================
WORKDIR /app/tts
RUN git clone https://github.com/travisvn/openai-edge-tts.git .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# 3. 部署 Gemini (Go) -> 端口 3000
# ===========================
WORKDIR /app/gemini
# 直接从第一阶段把编译好的文件拿过来，不需要在生产环境装 Go
COPY --from=go-builder /build/server .
RUN chmod +x server

# ===========================
# 4. 部署 DeepSeek (Node.js) -> 端口 4000
# ===========================
WORKDIR /app/deepseek
RUN git clone https://github.com/iidamie/deepseek2api.git .
RUN npm install
# 尝试修改默认端口为 4000 (防止冲突)
RUN grep -rl "3000" . | xargs sed -i 's/3000/4000/g' || true

# ===========================
# 5. 配置 Nginx 和 Supervisor
# ===========================
WORKDIR /app
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV PORT=8000
EXPOSE 8000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
