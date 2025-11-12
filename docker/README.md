# M2CC Docker 测试环境使用指南

## 快速开始

### 1. 基础使用

```bash
# 启动交互式测试环境 (推荐新手)
./docker-test.sh

# 运行基础自动化测试
./docker-test.sh --automated basic

# 运行完整自动化测试
./docker-test.sh --automated full

# 运行压力测试 (5轮)
TEST_ITERATIONS=5 ./docker-test.sh --automated stress
```

### 2. 构建和管理镜像

```bash
# 构建 Docker 镜像
./docker-test.sh --build

# 构建并运行交互式测试
./docker-test.sh --run interactive

# 构建并运行自动化测试
./docker-test.sh --run automated

# 查看环境状态
./docker-test.sh --status

# 查看测试日志
./docker-test.sh --logs
```

### 3. 清理环境

```bash
# 清理所有资源
./docker/cleanup.sh

# 保留镜像，只清理容器和数据
./docker/cleanup.sh --keep-images

# 模拟清理过程 (不实际删除)
./docker/cleanup.sh --dry-run

# 只清理容器和镜像
./docker/cleanup.sh --containers --images
```

## 测试模式详解

### 基础功能测试
- **语法检查**: 验证脚本语法正确性
- **函数检查**: 确认所有必要函数存在
- **依赖检查**: 检查系统依赖是否完整
- **快速安装**: 模拟安装过程 (不实际安装)

### 完整功能测试
- **实际安装**: 完整执行 m2cc.sh 安装流程
- **网络测试**: 验证外部网络连接
- **配置测试**: 测试多模型配置功能
- **错误处理**: 验证错误恢复能力

### 压力测试
- **循环测试**: 多次运行基础测试
- **资源监控**: 监控内存和磁盘使用
- **稳定性验证**: 验证脚本在重复执行下的稳定性

### 交互式测试
- **模拟用户体验**: 完全模拟真实用户操作流程
- **手动验证**: 用户可以手动执行和验证每个步骤
- **实时反馈**: 提供详细的进度和状态反馈

## 高级使用

### 环境变量配置

```bash
# 设置测试模式
export TEST_MODE="full"

# 设置压力测试迭代次数
export TEST_ITERATIONS="5"

# 跳过网络测试 (用于离线环境)
export SKIP_NETWORK_TESTS="true"

# 保留镜像，不在清理时删除
export KEEP_IMAGES="true"
```

### 使用 Docker Compose

```bash
# 启动交互式测试
docker-compose up m2cc-test

# 启动自动化测试
docker-compose --profile automated up m2cc-automated

# 后台运行
docker-compose up -d m2cc-automated
```

### 自定义配置

编辑 `docker/config/test.env` 文件来自定义测试参数:

```bash
# 修改测试超时时间
INSTALL_TEST_TIMEOUT=600

# 修改网络测试 URL
NETWORK_TEST_URLS="https://your-custom-url.com"

# 启用调试模式
DEBUG_MODE=true
```

## 报告和日志

### 报告文件位置

- **JSON 报告**: `docker/test-output/test_report_YYYYMMDD_HHMMSS.json`
- **文本报告**: `docker/test-output/test_summary_YYYYMMDD_HHMMSS.txt`
- **日志文件**: `docker/test-logs/interactive_test_YYYYMMDD_HHMMSS.log`

### 报告内容

JSON 报告包含:
- 测试会话信息 (时间、主机、操作系统等)
- 详细测试结果 (测试名称、状态、持续时间等)
- 性能指标 (执行时间、资源使用等)
- 错误信息 (如果有)
- 统计摘要 (总数、通过数、失败数、成功率)

### 查看报告

```bash
# 使用 jq 查看 JSON 报告
cat docker/test-output/test_report_*.json | jq '.summary'

# 查看最近的测试日志
tail -f docker/test-logs/interactive_test_*.log

# 查看测试摘要
cat docker/test-output/test_summary_*.txt
```

## 故障排除

### 常见问题

1. **Docker 不可用**
   ```bash
   # 检查 Docker 是否安装
   docker --version
   
   # 检查 Docker 守护进程
   docker info
   
   # 启动 Docker (Linux)
   sudo systemctl start docker
   ```

2. **镜像构建失败**
   ```bash
   # 清理 Docker 缓存
   docker system prune -a
   
   # 重新构建
   ./docker-test.sh --build
   ```

3. **权限问题**
   ```bash
   # 修复脚本权限
   chmod +x docker-test.sh
   chmod +x docker/test-scripts/*.sh
   chmod +x docker/cleanup.sh
   ```

4. **网络连接问题**
   ```bash
   # 跳过网络测试
   export SKIP_NETWORK_TESTS=true
   ./docker-test.sh --automated basic
   ```

### 调试模式

```bash
# 启用调试模式
export DEBUG_MODE=true
./docker-test.sh --automated basic

# 使用详细日志
export LOG_LEVEL=DEBUG
./docker-test.sh --automated basic
```

### 容器内调试

```bash
# 进入运行中的容器
docker exec -it m2cc-test-interactive /bin/bash

# 查看容器日志
docker logs m2cc-test-interactive

# 查看资源使用
docker stats m2cc-test-interactive
```

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: M2CC Docker Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run M2CC Docker Tests
        run: |
          chmod +x docker-test.sh
          ./docker-test.sh --automated basic
          ./docker-test.sh --automated stress
```

### Jenkins Pipeline 示例

```groovy
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh 'chmod +x docker-test.sh'
                sh './docker-test.sh --automated full'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'docker/test-output/**', fingerprint: true
                }
            }
        }
    }
}
```

## 性能优化

### 加速构建

```bash
# 使用 BuildKit
export DOCKER_BUILDKIT=1
./docker-test.sh --build

# 并行构建
docker build --parallel -t m2cc-test:latest .
```

### 资源限制

```bash
# 限制容器内存使用
docker run --memory=1g --cpus=1.0 m2cc-test:latest

# 使用资源限制运行测试
docker run --memory=512m --cpus=0.5 m2cc-test:latest /workspace/test-scripts/automated-test.sh
```

### 缓存优化

```bash
# 挂载缓存目录
docker run -v /tmp/m2cc-cache:/workspace/.cache m2cc-test:latest

# 使用持久化卷
docker volume create m2cc-cache
docker run -v m2cc-cache:/workspace/.cache m2cc-test:latest
```

## 扩展和自定义

### 添加新的测试

1. 在 `docker/test-scripts/` 目录创建新脚本
2. 修改 `interactive-test.sh` 和 `automated-test.sh` 添加新测试
3. 更新 `Dockerfile` 如果需要新的依赖

### 自定义测试报告

修改 `automated-test.sh` 中的 `generate_report()` 函数来自定义报告格式。

### 添加新的容器配置

在 `docker-compose.yml` 中添加新的服务定义。

## 安全注意事项

1. **API Key 安全**: 测试中使用的 API Key 都是模拟的，不会泄露真实密钥
2. **权限隔离**: 容器内使用非 root 用户运行测试
3. **网络隔离**: 可以通过 `SKIP_NETWORK_TESTS=true` 避免外网连接
4. **数据清理**: 测试完成后及时清理敏感数据

## 许可证

本测试环境遵循与主项目相同的许可证。

## 支持

如遇到问题，请:

1. 查看此文档的故障排除部分
2. 检查测试日志文件
3. 在 GitHub 上提交 Issue
4. 查看 Docker 和容器相关文档