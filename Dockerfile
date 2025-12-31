FROM python:3.10-slim

# 1. 安装基础工具
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    curl \
    gnupg \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 2. 安装 Node.js 20 (为了运行 QwenChat2API)
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update && apt-get install -y nodejs && npm install -g yarn

# ===========================
# 3. 部署 Edge TTS (Python - 端口 5050)
# ===========================
WORKDIR /app/tts
RUN git clone https://github.com/travisvn/openai-edge-tts.git .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# 4. 部署 DeepSeek2API (Python - 端口 5001)
# ===========================
WORKDIR /app/deepseek
RUN git clone https://github.com/iidamie/deepseek2api.git .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# 5. 部署 QwenChat2API (Node.js - 端口改为 3000)
# ===========================
WORKDIR /app/qwen
RUN git clone https://github.com/ckcoding/qwenchat2api.git .
RUN npm install

# ===========================
# 6. 配置 Nginx 和 Supervisor
# ===========================
WORKDIR /app
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 环境变量
ENV PORT=8000
EXPOSE 8000

# 启动
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
