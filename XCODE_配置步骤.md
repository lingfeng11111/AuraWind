# Xcode 项目配置步骤（简化版）

## 📌 重要提示

由于 Xcode 项目配置比较复杂，我为你准备了**最简单的配置方法**。

## 🚀 方法一：使用现有项目（推荐）

如果你的 Xcode 项目已经有 `SMCHelper` target，跳过创建步骤，直接：

### 1. 添加文件到 SMCHelper Target

在 Xcode 中：

1. 选中这些文件（在左侧文件列表中）：
   - `SMCHelper/main.swift`
   - `SMCHelper/Info.plist`
   - `SMCHelper/Launchd.plist`

2. 打开右侧的 **File Inspector**（文件检查器）
   - 快捷键：`⌘ + Option + 1`
   - 或点击右上角的 📄 图标

3. 在 **Target Membership** 部分：
   - ✅ 勾选 `SMCHelper`

### 2. 共享文件到两个 Target

这些文件需要同时属于 `AuraWind` 和 `SMCHelper`：

1. 选中以下文件：
   - `AuraWind/Services/SMCConnection.swift`
   - `AuraWind/Services/HelperTool/HelperToolProtocol.swift`
   - `AuraWind/Models/AuraWindError.swift`

2. 在 **File Inspector** 的 **Target Membership** 中：
   - ✅ 勾选 `AuraWind`
   - ✅ 勾选 `SMCHelper`

### 3. 添加框架（Frameworks）

#### 对于 SMCHelper target：

1. 选择项目文件（最上面的蓝色图标）
2. 选择 **SMCHelper** target
3. 点击 **Build Phases** 标签
4. 展开 **Link Binary With Libraries**
5. 点击 `+` 按钮，添加：
   - `IOKit.framework`
   - `Security.framework`
   - `ServiceManagement.framework`

#### 对于 AuraWind target：

同样的步骤，添加：
   - `ServiceManagement.framework`
   - `Security.framework`
   - `IOKit.framework`（如果还没有）

### 4. 配置 Build Settings（关键！）

#### 对于 SMCHelper target：

1. 选择 **SMCHelper** target
2. 点击 **Build Settings** 标签
3. 在搜索框输入 `Product Name`
   - 设置为：`com.aurawind.AuraWind.SMCHelper`

4. 搜索 `Skip Install`
   - 设置为：`NO`

5. 搜索 `Installation Directory`
   - 设置为：`$(CONTENTS_FOLDER_PATH)/Library/LaunchServices`

6. 搜索 `Code Signing Identity`
   - 选择你的开发者证书

7. 搜索 `Enable Hardened Runtime`
   - 设置为：`YES`

### 5. 配置 Info.plist

#### SMCHelper/Info.plist

已经配置好了，确认包含：
```xml
<key>CFBundleIdentifier</key>
<string>com.aurawind.AuraWind.SMCHelper</string>

<key>SMAuthorizedClients</key>
<array>
    <string>identifier "com.aurawind.AuraWind" and anchor apple generic and certificate leaf[subject.CN] = "Apple Development" and certificate 1[field.1.2.840.113635.100.6.2.1] /* exists */</string>
</array>
```

#### AuraWind/Info.plist

已经更新，确认包含：
```xml
<key>SMPrivilegedExecutables</key>
<dict>
    <key>com.aurawind.AuraWind.SMCHelper</key>
    <string>identifier "com.aurawind.AuraWind.SMCHelper" and anchor apple generic and certificate leaf[subject.CN] = "Apple Development" and certificate 1[field.1.2.840.113635.100.6.2.1] /* exists */</string>
</dict>
```

### 6. 添加 Launchd.plist 到构建

1. 选择 **SMCHelper** target
2. 点击 **Build Phases** 标签
3. 点击左上角的 `+` 按钮
4. 选择 **New Copy Files Phase**
5. 配置这个 Copy Files Phase：
   - **Destination**: `Wrapper`
   - **Subpath**: `Contents/Library/LaunchServices`
   - 点击 `+` 添加 `Launchd.plist`

---

## 🚀 方法二：从零创建（如果没有 SMCHelper target）

### 步骤 1: 创建 Helper Tool Target

1. 在 Xcode 中，点击菜单：**File > New > Target...**
2. 选择 **macOS** 标签
3. 选择 **Command Line Tool**
4. 点击 **Next**
5. 填写信息：
   - **Product Name**: `SMCHelper`
   - **Language**: `Swift`
   - **Bundle Identifier**: `com.aurawind.AuraWind.SMCHelper`
6. 点击 **Finish**

### 步骤 2: 删除自动生成的 main.swift

Xcode 会自动创建一个 `main.swift`，删除它（我们已经有自己的了）。

### 步骤 3: 按照方法一的步骤配置

从"添加文件到 SMCHelper Target"开始。

---

## ✅ 验证配置

### 检查清单：

- [ ] SMCHelper target 存在
- [ ] `main.swift` 属于 SMCHelper target
- [ ] `SMCConnection.swift` 同时属于两个 target
- [ ] `HelperToolProtocol.swift` 同时属于两个 target
- [ ] 两个 target 都链接了必要的框架
- [ ] Build Settings 配置正确
- [ ] Launchd.plist 在 Copy Files Phase 中

### 测试编译：

1. 选择 **SMCHelper** scheme
2. 按 `⌘ + B` 编译
3. 应该编译成功，无错误

---

## 🐛 常见问题

### Q: 找不到 SMCConnection 或 HelperToolProtocol

**A:** 确保这些文件同时属于两个 target。选中文件，在右侧 File Inspector 中勾选两个 target。

### Q: 编译错误："No such module 'IOKit'"

**A:** 在 Build Phases > Link Binary With Libraries 中添加 `IOKit.framework`。

### Q: 找不到 Build Settings 中的选项

**A:** 
1. 确保选择了正确的 target（SMCHelper）
2. 在 Build Settings 顶部，选择 **All** 而不是 **Basic**
3. 使用搜索框搜索设置名称

### Q: Launchd.plist 没有被复制

**A:** 
1. 检查 Build Phases > Copy Files
2. 确保 Destination 是 `Wrapper`
3. 确保 Subpath 是 `Contents/Library/LaunchServices`

---

## 📞 需要帮助？

如果遇到问题，告诉我：
1. 具体的错误信息
2. 你在哪一步卡住了
3. 截图（如果可以）

我会帮你解决！
