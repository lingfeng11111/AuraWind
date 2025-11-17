# 配置 Embed Helper Tool

## 问题
在 Debug 模式下运行时，Helper Tool 没有被打包到应用中，导致无法安装。

## 解决步骤

### 1. 添加 Target Dependency

1. 在 Xcode 中选择项目文件（蓝色图标）
2. 选择 **AuraWind** target
3. 点击 **Build Phases** 标签
4. 展开 **Dependencies** 部分
5. 点击 `+` 按钮
6. 选择 **SMCHelper**
7. 点击 **Add**

### 2. 添加 Copy Files Phase（复制 Helper Tool）

1. 在 **Build Phases** 标签中
2. 点击左上角的 `+` 按钮
3. 选择 **New Copy Files Phase**
4. 配置这个 Copy Files Phase：
   - **Destination**: 选择 `Wrapper`
   - **Subpath**: 输入 `Contents/Library/LaunchServices`
   - **勾选** `Code Sign On Copy`
5. 点击下方的 `+` 按钮
6. 在 **Products** 文件夹中选择 **SMCHelper**（不是 SMCHelper 文件夹，是编译产物）
7. 点击 **Add**

### 3. 验证配置

编译后，检查应用包内容：

```bash
# 在终端运行
ls -la "/Users/lingfeng/Library/Developer/Xcode/DerivedData/AuraWind-*/Build/Products/Debug/AuraWind.app/Contents/Library/LaunchServices/"
```

应该能看到：
- `com.aurawind.AuraWind.SMCHelper`（可执行文件）
- `Launchd.plist`

### 4. 重新编译运行

1. 清理项目：`⌘ + Shift + K`
2. 重新编译：`⌘ + B`
3. 运行应用：`⌘ + R`

## 预期结果

应用启动后，会在控制台看到：

```
连接到 Helper Tool...
Helper Tool 未安装
尝试安装 Helper Tool...
[系统弹出授权对话框]
✅ Helper Tool 安装成功
```

## 如果还是不行

可能需要手动打包测试：

```bash
# 1. 编译 Release 版本
xcodebuild -project AuraWind.xcodeproj -scheme AuraWind -configuration Release build

# 2. 检查应用包
open "/Users/lingfeng/Library/Developer/Xcode/DerivedData/AuraWind-*/Build/Products/Release/AuraWind.app"
```

## 调试技巧

在 `HelperToolManager.swift` 的 `install()` 方法开始处添加日志：

```swift
func install() async throws {
    print("🔍 开始安装 Helper Tool...")
    
    // 检查 Helper Tool 是否在应用包中
    let helperPath = Bundle.main.bundleURL
        .appendingPathComponent("Contents/Library/LaunchServices/com.aurawind.AuraWind.SMCHelper")
    
    print("🔍 Helper Tool 路径: \(helperPath.path)")
    print("🔍 Helper Tool 存在: \(FileManager.default.fileExists(atPath: helperPath.path))")
    
    // ... 原有代码
}
```

这样可以看到 Helper Tool 是否被正确打包。
