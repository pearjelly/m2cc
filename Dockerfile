# M2CC 测试环境 - Ubuntu 22.04 LTS
FROM ubuntu:22.04

# 设置非交互式模式
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 安装基础工具
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    jq \
    vim \
    htop \
    tree \
    unzip \
    ca-certificates \
    software-properties-common \
    apt-transport-https \
    gnupg \
    lsb-release \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录和测试用户
WORKDIR /workspace
RUN useradd -m -s /bin/bash testuser && \
    mkdir -p /workspace/test-reports && \
    mkdir -p /workspace/test-logs

# 创建脚本目录结构并复制脚本
RUN mkdir -p /workspace/test-scripts /workspace/config && \
    chown -R testuser:testuser /workspace

# 复制测试脚本和配置文件
COPY docker/test-scripts/ /workspace/test-scripts/
COPY docker/config/ /workspace/config/

# 设置脚本执行权限
RUN chmod +x /workspace/test-scripts/*.sh && \
    chown -R testuser:testuser /workspace



# 切换到测试用户
USER testuser

# 设置环境变量
ENV TEST_HOME=/workspace
ENV LOG_DIR=/workspace/test-logs
ENV REPORT_DIR=/workspace/test-reports
ENV HOST_WORKSPACE=/host-workspace

# 默认启动交互式测试脚本
CMD ["/bin/bash", "-c", "while true; do echo 'M2CC Docker test environment ready. Run: ./docker-test.sh'; sleep 3600; done"]
