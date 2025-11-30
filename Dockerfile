FROM python:3.11-slim

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    cron \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# 复制项目文件
COPY pyproject.toml uv.lock ./
COPY utils/ ./utils/
COPY checkin.py ./

# 安装 Python 依赖
RUN uv sync --frozen

# 安装 Playwright 及 Chromium 浏览器
RUN uv run playwright install chromium --with-deps

# 创建数据目录并链接余额文件
RUN mkdir -p /app/data && \
    ln -sf /app/data/balance_hash.txt /app/balance_hash.txt

# 设置 cron 任务（每6小时运行一次）
RUN echo "0 */6 * * * cd /app && /root/.local/bin/uv run checkin.py >> /var/log/checkin.log 2>&1" > /etc/cron.d/checkin \
    && chmod 0644 /etc/cron.d/checkin \
    && crontab /etc/cron.d/checkin

# 创建启动脚本
RUN echo '#!/bin/bash\n\
# 将环境变量写入 cron 可读取的文件\n\
printenv | grep -E "^(ANYROUTER|PROVIDERS|DINGDING|EMAIL|PUSHPLUS|SERVERPUSHKEY|FEISHU|WEIXIN|TELEGRAM|GOTIFY)" >> /etc/environment\n\
\n\
# 启动时先执行一次签到\n\
echo "[$(date)] Starting initial check-in..."\n\
cd /app && uv run checkin.py\n\
\n\
# 启动 cron 并保持容器运行\n\
echo "[$(date)] Starting cron daemon..."\n\
cron -f\n\
' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
