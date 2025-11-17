# AuraWind SMC Helper Tool 使用示例

## 快速开始

### 1. 在 AuraWindApp.swift 中初始化

```swift
import SwiftUI

@main
struct AuraWindApp: App {
    // 使用 Helper Tool 版本的 SMC 服务
    @StateObject private var smcService = SMCServiceWithHelper()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(smcService)
        }
    }
}
```

### 2. 在 ViewModel 中使用

```swift
import Foundation

@MainActor
class MyViewModel: ObservableObject {
    private let smcService: SMCServiceWithHelper
    
    @Published var temperature: Double = 0
    @Published var fanSpeed: Int = 0
    
    init(smcService: SMCServiceWithHelper) {
        self.smcService = smcService
    }
    
    func initialize() async {
        do {
            // 启动 SMC 服务（会自动安装 Helper Tool）
            try await smcService.start()
            
            // 读取温度
            let temp = try await smcService.readTemperature(sensor: .cpu)
            temperature = temp
            
            // 读取风扇信息
            let fans = try await smcService.getAllFans()
            if let firstFan = fans.first {
                fanSpeed = firstFan.currentSpeed
            }
            
        } catch {
            print("初始化失败: \(error)")
        }
    }
    
    func setFanSpeed(to rpm: Int) async {
        do {
            try await smcService.setFanSpeed(index: 0, rpm: rpm)
            print("✅ 风扇转速已设置为 \(rpm) RPM")
        } catch {
            print("❌ 设置失败: \(error)")
        }
    }
    
    func resetToAuto() async {
        do {
            try await smcService.setFanAutoMode(index: 0)
            print("✅ 已切换到自动模式")
        } catch {
            print("❌ 切换失败: \(error)")
        }
    }
}
```

### 3. 在 SwiftUI View 中使用

```swift
import SwiftUI

struct TemperatureView: View {
    @EnvironmentObject var smcService: SMCServiceWithHelper
    @State private var temperature: Double = 0
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            Text("CPU 温度")
                .font(.headline)
            
            Text("\(temperature, specifier: "%.1f")°C")
                .font(.system(size: 48, weight: .bold))
            
            Button("刷新") {
                Task {
                    await refreshTemperature()
                }
            }
        }
        .task {
            await initialize()
        }
    }
    
    private func initialize() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await smcService.start()
            await refreshTemperature()
        } catch {
            print("初始化失败: \(error)")
        }
    }
    
    private func refreshTemperature() async {
        do {
            temperature = try await smcService.readTemperature(sensor: .cpu)
        } catch {
            print("读取温度失败: \(error)")
        }
    }
}
```

### 4. 风扇控制示例

```swift
import SwiftUI

struct FanControlView: View {
    @EnvironmentObject var smcService: SMCServiceWithHelper
    @State private var fanSpeed: Double = 2000
    @State private var currentSpeed: Int = 0
    @State private var minSpeed: Int = 1200
    @State private var maxSpeed: Int = 6000
    
    var body: some View {
        VStack(spacing: 20) {
            Text("风扇控制")
                .font(.headline)
            
            Text("当前转速: \(currentSpeed) RPM")
                .font(.title2)
            
            Slider(value: $fanSpeed, in: Double(minSpeed)...Double(maxSpeed), step: 100)
                .padding()
            
            Text("目标转速: \(Int(fanSpeed)) RPM")
            
            HStack {
                Button("应用") {
                    Task {
                        await applyFanSpeed()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("自动模式") {
                    Task {
                        await resetToAuto()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .task {
            await loadFanInfo()
        }
    }
    
    private func loadFanInfo() async {
        do {
            try await smcService.start()
            
            let fan = try await smcService.getFanInfo(index: 0)
            currentSpeed = fan.currentSpeed
            minSpeed = fan.minSpeed
            maxSpeed = fan.maxSpeed
            fanSpeed = Double(fan.currentSpeed)
            
        } catch {
            print("加载风扇信息失败: \(error)")
        }
    }
    
    private func applyFanSpeed() async {
        do {
            try await smcService.setFanSpeed(index: 0, rpm: Int(fanSpeed))
            currentSpeed = Int(fanSpeed)
            print("✅ 风扇转速已设置")
        } catch {
            print("❌ 设置失败: \(error)")
        }
    }
    
    private func resetToAuto() async {
        do {
            try await smcService.setFanAutoMode(index: 0)
            await loadFanInfo()
            print("✅ 已切换到自动模式")
        } catch {
            print("❌ 切换失败: \(error)")
        }
    }
}
```

## 高级用法

### 监控多个传感器

```swift
class TemperatureMonitor: ObservableObject {
    private let smcService: SMCServiceWithHelper
    @Published var sensors: [TemperatureSensor] = []
    
    private var monitorTask: Task<Void, Never>?
    
    init(smcService: SMCServiceWithHelper) {
        self.smcService = smcService
    }
    
    func startMonitoring() {
        monitorTask = Task {
            while !Task.isCancelled {
                await updateSensors()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            }
        }
    }
    
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }
    
    private func updateSensors() async {
        do {
            sensors = try await smcService.getAllTemperatures()
        } catch {
            print("更新传感器失败: \(error)")
        }
    }
}
```

### 自定义风扇曲线

```swift
class FanCurveController {
    private let smcService: SMCServiceWithHelper
    
    struct CurvePoint {
        let temperature: Double
        let fanSpeed: Int
    }
    
    let curve: [CurvePoint] = [
        CurvePoint(temperature: 40, fanSpeed: 1500),
        CurvePoint(temperature: 50, fanSpeed: 2000),
        CurvePoint(temperature: 60, fanSpeed: 3000),
        CurvePoint(temperature: 70, fanSpeed: 4000),
        CurvePoint(temperature: 80, fanSpeed: 5500),
    ]
    
    init(smcService: SMCServiceWithHelper) {
        self.smcService = smcService
    }
    
    func applyFanCurve(currentTemp: Double, fanIndex: Int) async {
        let targetSpeed = interpolateSpeed(for: currentTemp)
        
        do {
            try await smcService.setFanSpeed(index: fanIndex, rpm: targetSpeed)
        } catch {
            print("应用风扇曲线失败: \(error)")
        }
    }
    
    private func interpolateSpeed(for temperature: Double) -> Int {
        // 找到温度区间
        for i in 0..<(curve.count - 1) {
            let lower = curve[i]
            let upper = curve[i + 1]
            
            if temperature >= lower.temperature && temperature <= upper.temperature {
                // 线性插值
                let ratio = (temperature - lower.temperature) / (upper.temperature - lower.temperature)
                let speed = Double(lower.fanSpeed) + ratio * Double(upper.fanSpeed - lower.fanSpeed)
                return Int(speed)
            }
        }
        
        // 超出范围
        if temperature < curve.first!.temperature {
            return curve.first!.fanSpeed
        } else {
            return curve.last!.fanSpeed
        }
    }
}
```

## 错误处理

### 检查 Helper Tool 状态

```swift
func checkHelperStatus() async {
    let manager = HelperToolManager.shared
    
    if !manager.isInstalled {
        print("⚠️ Helper Tool 未安装")
        
        do {
            try await manager.install()
            print("✅ Helper Tool 安装成功")
        } catch {
            print("❌ 安装失败: \(error)")
        }
    }
    
    if !manager.isConnected {
        do {
            try await manager.connect()
            print("✅ 已连接到 Helper Tool")
        } catch {
            print("❌ 连接失败: \(error)")
        }
    }
    
    // 检查详细状态
    do {
        let status = try await manager.checkStatus()
        print("Helper Tool 状态:")
        print("  版本: \(status["version"] ?? "未知")")
        print("  已连接: \(status["isConnected"] ?? false)")
    } catch {
        print("获取状态失败: \(error)")
    }
}
```

### 优雅的错误处理

```swift
enum SMCError: Error {
    case notInitialized
    case helperNotInstalled
    case accessDenied
    case operationFailed(String)
}

class SMCManager {
    private let service: SMCServiceWithHelper
    private var isInitialized = false
    
    init(service: SMCServiceWithHelper) {
        self.service = service
    }
    
    func ensureInitialized() async throws {
        guard !isInitialized else { return }
        
        do {
            try await service.start()
            isInitialized = true
        } catch {
            throw SMCError.notInitialized
        }
    }
    
    func readTemperatureSafely() async -> Double? {
        do {
            try await ensureInitialized()
            return try await service.readTemperature(sensor: .cpu)
        } catch {
            print("读取温度失败: \(error)")
            return nil
        }
    }
    
    func setFanSpeedSafely(index: Int, rpm: Int) async -> Bool {
        do {
            try await ensureInitialized()
            try await service.setFanSpeed(index: index, rpm: rpm)
            return true
        } catch {
            print("设置风扇转速失败: \(error)")
            return false
        }
    }
}
```

## 调试技巧

### 启用详细日志

```swift
// 在 AppDelegate 或 App 初始化时
func enableDebugLogging() {
    // 设置环境变量
    setenv("SMC_DEBUG", "1", 1)
    
    // 或者在代码中添加日志
    print("🔧 调试模式已启用")
}
```

### 查看 Helper Tool 日志

```bash
# 实时查看日志
tail -f /var/log/AuraWind.SMCHelper.log

# 或使用 Console.app
open -a Console
# 然后搜索 "SMCHelper"
```

### 测试 XPC 连接

```swift
func testXPCConnection() async {
    let manager = HelperToolManager.shared
    
    do {
        try await manager.connect()
        print("✅ XPC 连接成功")
        
        let status = try await manager.checkStatus()
        print("Helper 状态: \(status)")
        
    } catch {
        print("❌ XPC 连接失败: \(error)")
    }
}
```

## 性能优化

### 使用缓存减少 XPC 调用

```swift
class CachedSMCService {
    private let service: SMCServiceWithHelper
    private var cache: [String: (value: Double, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 1.0
    
    init(service: SMCServiceWithHelper) {
        self.service = service
    }
    
    func readTemperatureCached(sensor: TemperatureSensorType) async throws -> Double {
        let key = sensor.rawValue
        
        if let cached = cache[key],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return cached.value
        }
        
        let value = try await service.readTemperature(sensor: sensor)
        cache[key] = (value, Date())
        return value
    }
}
```

## 注意事项

1. **首次运行需要管理员密码** - Helper Tool 安装需要授权
2. **Apple Silicon 限制** - 某些 SMC 功能在 Apple Silicon Mac 上可能受限
3. **SIP 影响** - 系统完整性保护可能影响某些操作
4. **风扇安全** - 设置过低的转速可能导致过热，建议设置最低限制
5. **电池影响** - 高转速会增加电池消耗

## 完整示例项目

参考 `AuraWind` 主项目中的实现：

- `FanControlViewModel.swift` - 风扇控制逻辑
- `TemperatureMonitorViewModel.swift` - 温度监控
- `PerformanceMonitorViewModel.swift` - 性能监控

这些 ViewModel 展示了如何在实际应用中使用 SMC Helper Tool。
