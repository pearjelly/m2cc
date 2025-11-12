#!/bin/bash

# M2CC Docker 容器启动测试脚本
# 快速验证容器能否正常启动

set -e

echo "🧪 测试 M2CC Docker 容器启动..."

# 清理旧的镜像和容器
echo "🧹 清理旧资源..."
docker rmi m2cc-test:latest 2>/dev/null || true
docker rm m2cc-test-temp 2>/dev/null || true

# 构建镜像
echo "🔨 构建 Docker 镜像..."
if docker build -t m2cc-test:latest . > /dev/null 2>&1; then
    echo "✅ 镜像构建成功"
else
    echo "❌ 镜像构建失败"
    exit 1
fi

# 测试容器启动
echo "🚀 测试容器启动..."
if docker run --rm \
    -v "$(pwd)/docker/test-scripts:/workspace/test-scripts:ro" \
    -v "$(pwd)/docker/config:/workspace/config:ro" \
    -v "$(pwd):/workspace:ro" \
    --name "m2cc-test-temp" \
    m2cc-test:latest \
    /workspace/test-scripts/interactive-test.sh --help > /dev/null 2>&1; then
    echo "✅ 容器启动测试通过"
else
    echo "❌ 容器启动测试失败"
    # 尝试查看错误信息
    docker run --rm \
        -v "$(pwd)/docker/test-scripts:/workspace/test-scripts:ro" \
        -v "$(pwd)/docker/config:/workspace/config:ro" \
        -v "$(pwd):/workspace:ro" \
        --name "m2cc-test-temp" \
        m2cc-test:latest \
        ls -la /workspace/test-scripts/ 2>&1 || true
    exit 1
fi

# 清理
echo "🧹 清理测试容器..."
docker rm m2cc-test-temp 2>/dev/null || true

echo "🎉 所有测试通过！Docker 容器现在可以正常启动了。"
echo "💡 现在可以运行: ./docker-test.sh"