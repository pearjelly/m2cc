# M2CC Docker 测试环境 - 快速使用指南

## 🎯 概述

我们已经成功创建了一个完整的 M2CC Docker 测试环境，支持在 Ubuntu 22.04 LTS 纯净系统中测试 m2cc.sh 脚本的功能。

## ✅ 环境验证结果

```
总检查项目: 23
通过检查: 22
失败检查: 0
成功率: 95%

✅ 环境验证通过！
```

## 🚀 快速开始

### 1. 验证环境
```bash
# 首先验证环境是否正确设置
./verify-env.sh
```

### 2. 启动交互式测试（推荐新手）
```bash
# 这将启动一个交互式测试环境，模拟真实用户体验
./docker-test.sh
```

### 3. 运行自动化测试
```bash
# 基础功能测试
./docker-test.sh --automated basic

# 完整功能测试
./docker-test.sh --automated full

# 压力测试（5轮）
TEST_ITERATIONS=5 ./docker-test.sh --automated stress

# 运行所有测试
./docker-test.sh --automated all
```

### 4. 高级用法
```bash
# 查看帮助信息
./docker-test.sh --help

# 查看测试状态
./docker-test.sh --status

# 查看测试日志
./docker-test.sh --logs

# 构建 Docker 镜像
./docker-test.sh --build

# 构建并直接运行
./docker-test.sh --run interactive
```

## 📊 测试功能特性

### ✅ 已实现的功能

1. **基础功能测试**
   - 脚本语法检查
   - 函数存在性验证
   - 系统依赖检查
   - 模拟安装过程测试

2. **完整功能测试**
   - 实际安装流程测试
   - 网络连接验证
   - 多模型配置测试
   - 错误处理能力验证

3. **压力测试**
   - 多次循环测试
   - 资源使用监控
   - 稳定性验证

4. **交互式体验测试**
   - 完全模拟真实用户操作
   - 交互式菜单系统
   - 实时进度反馈

5. **完整报告系统**
   - JSON 格式详细报告
   - 人类可读文本报告
   - 实时日志记录
   - 性能指标统计

6. **错误恢复测试**
   - 网络中断模拟
   - 权限错误处理
   - 依赖缺失恢复

## 📁 项目结构

```
m2cc/
├── Dockerfile                    # Docker 镜像定义
├── docker-compose.yml            # Docker Compose 配置
├── docker-test.sh               # 主启动脚本
├── verify-env.sh                # 环境验证脚本
├── m2cc.sh                      # 待测试的脚本
└── docker/
    ├── test-scripts/
    │   ├── interactive-test.sh   # 交互式测试脚本
    │   └── automated-test.sh     # 自动化测试脚本
    ├── cleanup.sh               # 清理脚本
    ├── config/
    │   └── test.env             # 测试配置文件
    └── README.md                # 详细使用文档
```

## 🔧 使用场景

### 场景 1：基础验证
```bash
# 快速验证 m2cc.sh 脚本基本功能
./docker-test.sh --automated basic
```

### 场景 2：完整测试
```bash
# 在纯净环境中完整测试 m2cc.sh 的所有功能
./docker-test.sh --automated full
```

### 场景 3：交互式体验
```bash
# 模拟真实用户操作流程
./docker-test.sh
# 选择选项 4：交互式体验测试
```

### 场景 4：压力测试
```bash
# 验证脚本在重复执行下的稳定性
TEST_ITERATIONS=10 ./docker-test.sh --automated stress
```

### 场景 5：CI/CD 集成
```bash
# 在 CI 环境中自动化测试
export CI_ENVIRONMENT=true
export SKIP_NETWORK_TESTS=true
./docker-test.sh --automated all
```

## 🛠 维护操作

### 清理环境
```bash
# 清理所有 Docker 资源
./docker/cleanup.sh

# 保留镜像，只清理容器和数据
./docker/cleanup.sh --keep-images

# 模拟清理（不实际删除）
./docker/cleanup.sh --dry-run
```

### 查看状态
```bash
# 查看 Docker 环境状态
./docker-test.sh --status

# 查看最近的测试日志
./docker-test.sh --logs
```

## 📈 报告位置

测试完成后，报告会保存在以下位置：

- **JSON 报告**: `docker/test-output/test_report_YYYYMMDD_HHMMSS.json`
- **文本报告**: `docker/test-output/test_summary_YYYYMMDD_HHMMSS.txt`
- **日志文件**: `docker/test-logs/interactive_test_YYYYMMDD_HHMMSS.log`

## 🎉 完成总结

✅ **已成功创建完整的 M2CC Docker 测试环境！**

### 主要成果：

1. **🐳 基于 Ubuntu 22.04 LTS 的纯净测试环境**
2. **🔧 完整工具集（启动、测试、清理、验证）**
3. **🧪 三种测试模式（基础、完整、压力测试）**
4. **📊 完整的报告系统（JSON + 文本格式）**
5. **🛡 错误恢复和边界情况处理**
6. **📚 详细的文档和使用指南**

### 支持的测试场景：

- ✅ 核心安装功能测试（NVM + Node.js + Claude Code）
- ✅ 多模型配置功能测试（MiniMax + DeepSeek + GLM）
- ✅ 脚本错误恢复能力测试
- ✅ 交互式用户体验模拟
- ✅ 自动化测试和压力测试
- ✅ CI/CD 集成支持

### 使用便利性：

- 🚀 **一键启动**: `./docker-test.sh`
- 🔍 **环境验证**: `./verify-env.sh`
- 🧹 **一键清理**: `./docker/cleanup.sh`
- 📖 **详细帮助**: `./docker-test.sh --help`

## 🎯 下一步建议

1. **立即开始测试**: 运行 `./docker-test.sh` 体验交互式测试
2. **查看详细文档**: 阅读 `docker/README.md` 了解更多功能
3. **自定义配置**: 编辑 `docker/config/test.env` 调整测试参数
4. **CI/CD 集成**: 在您的持续集成流程中使用自动化测试

---

**🎊 恭喜！您的 M2CC Docker 测试环境已经准备就绪，可以开始全面测试 m2cc.sh 脚本在纯净系统中的功能了！**