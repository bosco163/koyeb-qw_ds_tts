FROM python:3.10-slim

# 1. 安装基础工具
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
    && rm -rf /var/lib/apt/lists/*

# ===========================
# 2. 部署 TTS -> 端口 5050
# ===========================
WORKDIR /app/tts
RUN git clone https://github.com/travisvn/openai-edge-tts.git .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# 3. 部署 Gemini -> 端口 3000 (增强版)
# ===========================
WORKDIR /app/gemini
RUN git clone https://github.com/erxiansheng/gemininixiang.git .
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi
RUN if [ -f package.json ]; then npm install; fi

# [关键] 暴力替换常见端口为 3000
RUN grep -rl "8000" . | xargs sed -i 's/8000/3000/g' || true
RUN grep -rl "8080" . | xargs sed -i 's/8080/3000/g' || true
RUN grep -rl "5000" . | xargs sed -i 's/5000/3000/g' || true

# [关键] 智能启动脚本：区分 FastAPI 和普通脚本
RUN echo '#!/bin/bash\n\
# 优先查找 Python 入口\n\
ENTRY_FILE=""\n\
if [ -f main.py ]; then ENTRY_FILE="main.py"; fi\n\
if [ -z "$ENTRY_FILE" ] && [ -f app.py ]; then ENTRY_FILE="app.py"; fi\n\
\n\
if [ ! -z "$ENTRY_FILE" ]; then\n\
    echo "Found Python entry: $ENTRY_FILE"\n\
    # 检测是否为 FastAPI 项目\n\
    if grep -q "FastAPI" "$ENTRY_FILE"; then\n\
        echo "Detected FastAPI. Starting with uvicorn on port 3000..."\n\
        # 假设 app 对象名为 app，这也是最常见的情况\n\
        exec uvicorn ${ENTRY_FILE%.*}:app --host 0.0.0.0 --port 3000\n\
    else\n\
        echo "Starting standard Python script..."\n\
        exec python3 "$ENTRY_FILE"\n\
    fi\n\
elif [ -f package.json ]; then\n\
    echo "Starting Node.js..."\n\
    exec npm start\n\
else\n\
    echo "Error: No startup file found!"\n\
    ls -R\n\
    sleep 3600\n\
fi' > start.sh && chmod +x start.sh

# ===========================
# 4. 部署 DeepSeek -> 端口 5001
# ===========================
WORKDIR /app/deepseek
RUN git clone https://github.com/iidamie/deepseek2api.git .
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi
RUN if [ -f package.json ]; then npm install; fi

# DeepSeek 保持 5001 端口逻辑
RUN grep -rl "8000" . | xargs sed -i 's/8000/5001/g' || true
RUN grep -rl "3000" . | xargs sed -i 's/3000/5001/g' || true

RUN echo '#!/bin/bash\n\
if [ -f main.py ]; then\n\
    exec python3 main.py\n\
elif [ -f app.py ]; then\n\
    exec python3 app.py\n\
elif [ -f package.json ]; then\n\
    exec npm start\n\
else\n\
    sleep 3600\n\
fi' > start.sh && chmod +x start.sh

# ===========================
# 5. 配置 Nginx 和 Supervisor
# ===========================
WORKDIR /app
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV PORT=8000
EXPOSE 8000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
