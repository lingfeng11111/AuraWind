# SMC Helper Tool 配置指南

本文档说明如何配置 Xcode 项目以使用 SMC Helper Tool 实现真实的硬件访问。

## 架构说明

AuraWind 使用 **特权助手工具 (Privileged Helper Tool)** 架构来访问 SMC 硬件：

```
主应用 (AuraWind.app)
    ↓ XPC 通信
Helper Tool (以 root 权限运行)
    ↓ IOKit
SMC 硬件
```

这是 **Macs Fan Control** 等专业应用使用的标准方案。

## Xcode 项目配置步骤

### 1. 创建 Helper Tool Target

1. 在 Xcode 中，选择 **File > New > Target**
2. 选择 **macOS > Command Line Tool**
3. 配置如下：
   - Product Name: `SMCHelper`
   - Bundle Identifier: `com.aurawind.AuraWind.SMCHelper`
   - Language: Swift

### 2. 配置 Helper Tool Target

在 **SMCHelper** target 的 **Build Settings** 中：

1. **Product Name**: `com.aurawind.AuraWind.SMCHelper`
2. **Skip Install**: `NO`
3. **Installation Directory**: `$(CONTENTS_FOLDER_PATH)/Library/LaunchServices`
4. **Code Signing Identity**: 使用你的开发者证书
5. **Enable Hardened Runtime**: `YES`

### 3. 配置 Info.plist

确保 **SMCHelper/Info.plist** 包含：

```xml
<key>CFBundleIdentifier</key>
<string>com.aurawind.AuraWind.SMCHelper</string>

<key>SMAuthorizedClients</key>
<array>
    <string>identifier "com.aurawind.AuraWind" and anchor apple generic and certificate leaf[subject.CN] = "Apple Development" and certificate 1[field.1.2.840.113635.100.6.2.1] /* exists */</string>
</array>
```

### 4. 配置主应用 Info.plist

确保 **AuraWind/Info.plist** 包含：

```xml
<key>SMPrivilegedExecutables</key>
<dict>
    <key>com.aurawind.AuraWind.SMCHelper</key>
    <string>identifier "com.aurawind.AuraWind.SMCHelper" and anchor apple generic and certificate leaf[subject.CN] = "Apple Development" and certificate 1[field.1.2.840.113635.100.6.2.1] /* exists */</string>
</dict>
```

### 5. 添加 Launchd.plist 到 Helper Tool

1. 将 `SMCHelper/Launchd.plist` 添加到 **SMCHelper** target
2. 在 **Build Phases** 中，添加 **Copy Files** phase：
   - Destination: `Wrapper`
   - Subpath: `Contents/Library/LaunchServices`
   - 添加 `Launchd.plist` 文件

### 6. 链接必要的框架

在 **SMCHelper** target 的 **Build Phases > Link Binary With Libraries** 中添加：

- `IOKit.framework`
- `Security.framework`
- `ServiceManagement.framework`

在 **AuraWind** target 中也添加：

- `ServiceManagement.framework`
- `Security.framework`

### 7. 添加源文件到正确的 Target

确保以下文件属于正确的 target：

**SMCHelper target:**
- `SMCHelper/main.swift`
- `SMCHelper/Info.plist`
- `SMCHelper/Launchd.plist`
- `AuraWind/Services/SMCConnection.swift` (需要共享)
- `AuraWind/Services/HelperTool/HelperToolProtocol.swift` (需要共享)
- `AuraWind/Models/AuraWindError.swift` (需要共享)

**AuraWind target:**
- `AuraWind/Services/HelperTool/HelperToolProtocol.swift`
- `AuraWind/Services/HelperTool/HelperToolManager.swift`
- `AuraWind/Services/SMCServiceWithHelper.swift`

### 8. 配置代码签名

1. 在 **Signing & Capabilities** 中：
   - 两个 target 都使用相同的 **Team**
   - 启用 **Hardened Runtime**
   - 添加必要的 **Capabilities**

2. 对于 **AuraWind** target，添加 entitlements：
   - `com.apple.security.temporary-exception.sbpl`
   - `com.apple.security.temporary-exception.iokit-user-client-class`

### 9. 修改应用启动代码

在 `AuraWindApp.swift` 中，使用新的 SMC 服务：

```swift
// 使用 Helper Tool 版本
let smcService = SMCServiceWithHelper()
```

## 使用方法

### 首次运行

1. 编译并运行应用
2. 应用会自动请求安装 Helper Tool
3. 输入管理员密码授权
4. Helper Tool 安装完成后，应用即可访问 SMC

### 验证安装

可以通过以下命令检查 Helper Tool 是否已安装：

```bash
# 检查 helper tool 文件
ls -la /Library/PrivilegedHelperTools/com.aurawind.AuraWind.SMCHelper

# 检查 launchd plist
ls -la /Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist

# 检查 helper 是否运行
sudo launchctl list | grep aurawind

# 查看 helper 日志
tail -f /var/log/AuraWind.SMCHelper.log
```

### 调试

1. **查看系统日志**：
   ```bash
   log stream --predicate 'process == "com.aurawind.AuraWind.SMCHelper"' --level debug
   ```

2. **使用 Console.app**：
   - 打开 Console.app
   - 搜索 "SMCHelper"
   - 查看实时日志

3. **手动加载 Helper**：
   ```bash
   sudo launchctl load /Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist
   ```

## 常见问题

### Q: Helper Tool 安装失败

**A:** 检查以下几点：
1. Info.plist 中的 Bundle ID 是否匹配
2. 代码签名是否正确
3. SMAuthorizedClients 和 SMPrivilegedExecutables 配置是否匹配
4. 是否有管理员权限

### Q: XPC 连接失败

**A:** 
1. 确认 Helper Tool 已安装并运行
2. 检查 Mach Service 名称是否正确
3. 查看系统日志获取详细错误信息

### Q: SMC 访问被拒绝

**A:**
1. 确认 Helper Tool 以 root 权限运行
2. 检查 entitlements 配置
3. 在 Intel Mac 上可能需要禁用 SIP（不推荐）
4. 在 Apple Silicon Mac 上，某些 SMC 功能可能受限

### Q: 如何卸载 Helper Tool

**A:** 在应用中调用：
```swift
try await HelperToolManager.shared.uninstall()
```

或手动删除：
```bash
sudo launchctl unload /Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist
sudo rm /Library/PrivilegedHelperTools/com.aurawind.AuraWind.SMCHelper
sudo rm /Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist
```

## 发布注意事项

### 公证 (Notarization)

发布应用时，需要对主应用和 Helper Tool **分别进行公证**：

1. 使用 Developer ID 证书签名
2. 创建 .pkg 安装包
3. 提交给 Apple 公证
4. 等待公证完成
5. 将公证票据附加到应用

### 分发

- 推荐使用 .pkg 安装包分发
- 在安装脚本中处理 Helper Tool 的安装
- 提供卸载脚本

## 参考资源

- [Apple: SMJobBless Documentation](https://developer.apple.com/documentation/servicemanagement/1431078-smjobbless)
- [Apple: EvenBetterAuthorizationSample](https://developer.apple.com/library/archive/samplecode/EvenBetterAuthorizationSample/)
- [Macs Fan Control](https://crystalidea.com/macs-fan-control) - 参考实现

## 支持

如有问题，请查看：
1. 系统日志 (`/var/log/AuraWind.SMCHelper.log`)
2. Console.app 中的实时日志
3. Xcode 控制台输出
