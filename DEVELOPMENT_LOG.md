# AuraWind 开发日志

## 项目概述

AuraWind 是一个 macOS 风扇控制应用，旨在通过读取 SMC (System Management Controller) 数据来监控 Mac 的温度和风扇状态，并提供自定义风扇控制功能。

**开发时间**: 2025年11月  
**开发平台**: macOS (Apple Silicon)  
**技术栈**: SwiftUI, XPC, SMC, Privileged Helper Tool

---

## 开发历程与挑战

### 🎯 项目目标

1. 读取 Mac 的实时温度数据（CPU、GPU、环境温度等）
2. 监控和控制风扇转速
3. 提供美观的用户界面
4. 支持自动和手动风扇控制模式

### 💔 遇到的主要困难

#### 1. SMC 访问权限问题

**问题描述**:  
macOS 的 SMC (System Management Controller) 是一个底层硬件接口，需要特殊权限才能访问。直接访问会遇到权限拒绝。

**尝试的解决方案**:
- ✅ 添加 `com.apple.security.temporary-exception.iokit-user-client-class` entitlement
- ✅ 添加 `com.apple.security.temporary-exception.sbpl` entitlement
- ❌ 但在 Release 构建中仍然无法访问

**结论**: 直接访问 SMC 在沙盒环境下几乎不可能实现。

#### 2. Privileged Helper Tool 架构

**问题描述**:  
为了访问 SMC，需要使用 macOS 的 Privileged Helper Tool 机制，这是一个复杂的架构，涉及：
- XPC (跨进程通信)
- SMJobBless (特权助手安装)
- 代码签名和证书
- Launchd 服务管理

**遇到的具体问题**:

##### 2.1 SMJobBless 与 Ad-hoc 签名不兼容

```
问题: SMJobBless 要求使用正式的 Apple Developer 证书签名
现状: 只有 ad-hoc 签名（免费开发者账号）
结果: SMJobBless 调用失败，返回 "No such process" 错误
```

**解决方案**: 创建手动安装脚本 (`手动安装Helper.sh`)，绕过 SMJobBless，直接将 Helper Tool 安装到系统目录。

##### 2.2 SMC 数据结构大小错误

**最关键的技术问题**:

```
错误信息: SMCC::smcYPCEventCheck ERROR: invalid input structure size:53
期望大小: 80 bytes
实际大小: 53 bytes
```

**问题根源**:  
`SMCConnection.swift` 中的 `SMCKeyData` 结构体定义不正确，与 macOS 内核期望的结构体大小不匹配。

**修复过程**:
```swift
// 原始定义（错误）
private struct SMCKeyData {
    var key: UInt32 = 0                    // 4 bytes
    var vers: (UInt8, UInt8, ...) = ...    // 6 bytes
    // ... 总共只有 53 bytes
}

// 修复后（正确）
private struct SMCKeyData {
    var key: UInt32 = 0                    // 4 bytes
    var vers: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = ...  // 6 bytes
    var pLimitData: (...) = ...            // 16 bytes
    var keyInfo = SMCKeyInfoData()         // 6 bytes
    var result: UInt8 = 0                  // 1 byte
    var status: UInt8 = 0                  // 1 byte
    var data8: UInt8 = 0                   // 1 byte
    var data32: UInt32 = 0                 // 4 bytes
    var bytes = SMCBytes()                 // 32 bytes
    var padding: (...) = ...               // 9 bytes
    // 总共 80 bytes ✅
}
```

##### 2.3 Helper Tool 进程管理问题

**问题**: 
- 旧的 Helper Tool 进程持续运行，导致应用连接到过时的版本
- 即使重新编译和安装，旧进程仍然存在
- `pkill` 命令无法完全清理所有实例

**尝试的解决方案**:
```bash
# 停止 launchd 服务
launchctl unload /Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist

# 强制终止进程
pkill -9 -f "SMCHelper"

# 重新加载
launchctl load /Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist
```

**结果**: 部分有效，但仍有进程残留问题。

##### 2.4 XPC 通信问题

**问题**: 
- 应用与 Helper Tool 之间的 XPC 连接建立成功
- 但数据传输时没有响应
- Helper Tool 的日志完全没有输出

**可能的原因**:
1. XPC 消息格式不匹配
2. Helper Tool 没有被正确调用
3. 异步回调处理有问题
4. 日志系统配置不正确

#### 3. 调试困难

**主要挑战**:

1. **日志难以捕获**:
   - `print()` 语句在 Helper Tool 中不输出
   - `NSLog()` 也无法在系统日志中找到
   - Console.app 过滤困难

2. **构建和测试周期长**:
   ```
   编译 → 打包 → 安装 Helper Tool → 测试 → 发现问题 → 修改代码 → 重复
   每次循环需要 5-10 分钟
   ```

3. **权限问题**:
   - 文件被锁定，无法删除
   - 需要 sudo 权限进行清理
   - 构建目录权限混乱

4. **状态不一致**:
   - 应用显示"所有服务初始化完成"
   - 但实际没有数据
   - 无法确定问题出在哪一层

### 📊 技术架构

```
┌─────────────────────────────────────────┐
│         AuraWind.app (主应用)            │
│  ┌───────────────────────────────────┐  │
│  │   SMCServiceWithHelper            │  │
│  │   HelperToolManager (XPC Client)  │  │
│  └───────────────┬───────────────────┘  │
└──────────────────┼──────────────────────┘
                   │ XPC
                   │ Mach Service
                   ↓
┌─────────────────────────────────────────┐
│  com.aurawind.AuraWind.SMCHelper        │
│  (Privileged Helper Tool)               │
│  ┌───────────────────────────────────┐  │
│  │   XPC Service                     │  │
│  │   SMCConnection                   │  │
│  │   IOKit Driver Interface          │  │
│  └───────────────┬───────────────────┘  │
└──────────────────┼──────────────────────┘
                   │ IOKit
                   ↓
┌─────────────────────────────────────────┐
│         macOS Kernel                    │
│         SMC Driver                      │
│         (AppleSMC.kext)                 │
└─────────────────────────────────────────┘
```

### 🔧 已实现的功能

✅ **基础架构**:
- SwiftUI 用户界面
- MVVM 架构
- 数据持久化
- 温度和风扇监控界面

✅ **Helper Tool 机制**:
- XPC 通信协议定义
- Helper Tool 实现
- 手动安装脚本
- Launchd 配置

✅ **SMC 通信**:
- SMC 连接建立
- 数据结构定义（80 bytes）
- 读写接口

### ❌ 未解决的问题

1. **数据读取失败**: 虽然连接成功，但无法获取实际的温度和风扇数据
2. **Helper Tool 日志缺失**: 无法有效调试 Helper Tool 内部逻辑
3. **进程管理混乱**: 旧进程残留，难以确保使用最新版本
4. **XPC 通信不稳定**: 消息传递可能存在问题

### 💡 经验教训

1. **SMC 访问极其复杂**: 
   - 需要深入了解 macOS 内核接口
   - 数据结构必须精确匹配
   - 权限管理非常严格

2. **Privileged Helper Tool 开发困难**:
   - 需要正式的开发者证书（$99/年）
   - 调试非常困难
   - 文档不完善

3. **替代方案**:
   - 考虑使用现有的开源库（如 `SMCKit`）
   - 或者参考成熟的应用（如 Macs Fan Control）
   - 避免从零开始实现 SMC 访问

### 📚 参考资料

- [Apple Developer: SMJobBless](https://developer.apple.com/documentation/servicemanagement/1431078-smjobbless)
- [Apple Developer: XPC Services](https://developer.apple.com/documentation/xpc)
- [IOKit Fundamentals](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/)
- [Macs Fan Control](https://crystalidea.com/macs-fan-control) - 商业参考实现

### 🎯 未来方向

如果要继续开发，建议：

1. **获取正式的 Apple Developer 证书** ($99/年)
   - 这是使用 SMJobBless 的前提
   - 可以正常签名和分发应用

2. **使用现有的 SMC 库**
   - [SMCKit](https://github.com/beltex/SMCKit)
   - [HWMonitor](https://github.com/kozlek/HWSensors)

3. **简化架构**
   - 考虑不使用 Helper Tool
   - 接受功能限制，只读取公开的 API

4. **寻求社区帮助**
   - macOS 开发论坛
   - Stack Overflow
   - GitHub Issues

---

## 项目文件结构

```
AuraWind/
├── AuraWind/                    # 主应用
│   ├── AuraWindApp.swift       # 应用入口
│   ├── Views/                  # 视图
│   ├── ViewModels/             # 视图模型
│   ├── Models/                 # 数据模型
│   └── Services/
│       ├── SMCServiceWithHelper.swift    # SMC 服务（Helper Tool 版本）
│       ├── SMCConnection.swift           # SMC 底层连接
│       └── HelperTool/
│           ├── HelperToolProtocol.swift  # XPC 协议
│           └── HelperToolManager.swift   # Helper Tool 管理器
├── SMCHelper/                   # Privileged Helper Tool
│   ├── main.swift              # Helper Tool 主程序
│   ├── Info.plist              # Helper Tool 配置
│   └── Launchd.plist           # Launchd 服务配置
├── 手动安装Helper.sh            # 手动安装脚本
├── 打包并安装.sh                # 完整打包脚本
└── DEVELOPMENT_LOG.md          # 本文档
```

---

## 总结

这个项目展示了 macOS 底层硬件访问的复杂性。虽然最终没有完全实现预期功能，但在过程中学到了：

- macOS 安全机制和权限管理
- XPC 跨进程通信
- IOKit 驱动接口
- Privileged Helper Tool 架构
- SMC 数据结构和协议

**这是一次宝贵的学习经历，虽然充满挫折，但也积累了重要的技术经验。** 🚀

---

*最后更新: 2025年11月17日*  
*状态: 暂停开发，等待更好的解决方案*
