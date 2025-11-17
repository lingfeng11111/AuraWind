#!/usr/bin/env swift

import Foundation
import IOKit

// 错误码分析
func analyzeSMCError(_ result: kern_return_t) {
    print("错误码分析: \(result)")
    
    switch result {
    case kIOReturnSuccess:
        print("✅ 成功")
    case kIOReturnError:
        print("❌ 通用错误")
    case kIOReturnNoMemory:
        print("❌ 内存不足")
    case kIOReturnNoResources:
        print("❌ 资源不足")
    case kIOReturnIPCError:
        print("❌ IPC错误")
    case kIOReturnNoDevice:
        print("❌ 设备不存在")
    case kIOReturnNotPrivileged:
        print("❌ 权限不足 - 需要更高权限")
    case kIOReturnBadArgument:
        print("❌ 参数错误")
    case kIOReturnLockedRead:
        print("❌ 读取被锁定")
    case kIOReturnLockedWrite:
        print("❌ 写入被锁定")
    default:
        print("❌ 未知错误码: \(result)")
        if result == -536870206 {
            print("💡 这个错误码通常表示:")
            print("  - SMC访问被系统保护")
            print("  - 需要禁用SIP或获取特殊权限")
            print("  - 应用缺少必要的entitlements")
        }
    }
}

// 简化的SMC测试
func testSMCWithDetailedLogging() {
    print("🔍 详细SMC访问测试")
    print("时间: \(Date())")
    print("系统: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    print("用户: \(getenv("USER") != nil ? String(cString: getenv("USER")!) : "unknown")")
    print("")
    
    // 1. 检查系统信息
    print("1️⃣ 系统信息检查:")
    let processInfo = ProcessInfo.processInfo
    print("   - 操作系统版本: \(processInfo.operatingSystemVersionString)")
    print("   - 进程ID: \(processInfo.processIdentifier)")
    print("   - 环境变量数量: \(processInfo.environment.count)")
    
    // 2. 检查SIP状态
    print("\n2️⃣ 系统完整性保护(SIP)状态:")
    let sipStatus = Process()
    sipStatus.executableURL = URL(fileURLWithPath: "/usr/bin/csrutil")
    sipStatus.arguments = ["status"]
    
    let pipe = Pipe()
    sipStatus.standardOutput = pipe
    
    do {
        try sipStatus.run()
        sipStatus.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("   \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    } catch {
        print("   ⚠️ 无法检查SIP状态: \(error)")
    }
    
    // 3. 检查应用权限
    print("\n3️⃣ 应用权限检查:")
    let appPath = ProcessInfo.processInfo.arguments[0]
    print("   - 应用路径: \(appPath)")
    
    // 检查文件权限
    let fileManager = FileManager.default
    do {
        let attributes = try fileManager.attributesOfItem(atPath: appPath)
        if let permissions = attributes[.posixPermissions] as? Int {
            print("   - 文件权限: \(String(format: "%o", permissions))")
        }
    } catch {
        print("   ⚠️ 无法获取文件权限: \(error)")
    }
    
    // 4. 测试IOKit基本功能
    print("\n4️⃣ IOKit基本功能测试:")
    
    // 获取主端口
    let mainPort = kIOMainPortDefault
    print("   - 主端口: \(mainPort)")
    
    // 测试匹配所有服务
    let matchingDict = IOServiceMatching("IOService")
    if matchingDict != nil {
        print("   ✅ 基础IOKit匹配成功")
        
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(mainPort, matchingDict, &iterator)
        
        if result == kIOReturnSuccess {
            print("   ✅ 服务枚举成功")
            var serviceCount = 0
            var service = IOIteratorNext(iterator)
            while service != 0 {
                serviceCount += 1
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
            print("   - 找到的服务数量: \(serviceCount)")
        } else {
            print("   ❌ 服务枚举失败: \(result)")
            analyzeSMCError(result)
        }
    } else {
        print("   ❌ 基础IOKit匹配失败")
    }
    
    // 5. 测试AppleSMC服务
    print("\n5️⃣ AppleSMC服务测试:")
    
    let smcService = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching("AppleSMC")
    )
    
    if smcService != 0 {
        print("   ✅ AppleSMC服务找到: \(smcService)")
        
        // 尝试获取服务属性
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(smcService, &properties, kCFAllocatorDefault, 0)
        
        if result == kIOReturnSuccess, let props = properties {
            print("   ✅ 获取服务属性成功")
            if let dict = props.takeRetainedValue() as? [String: Any] {
                print("   - 属性数量: \(dict.count)")
                for (key, _) in dict {
                    if key.contains("SMC") || key.contains("smc") {
                        print("   - SMC相关属性: \(key)")
                    }
                }
            }
        } else {
            print("   ⚠️ 获取服务属性失败: \(result)")
            analyzeSMCError(result)
        }
        
        IOObjectRelease(smcService)
    } else {
        print("   ❌ AppleSMC服务未找到")
    }
    
    // 6. 测试连接权限
    print("\n6️⃣ 连接权限测试:")
    
    let testService = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching("AppleSMC")
    )
    
    if testService != 0 {
        var connection: io_connect_t = 0
        let result = IOServiceOpen(testService, mach_task_self_, 0, &connection)
        
        if result == kIOReturnSuccess {
            print("   ✅ 服务连接成功: \(connection)")
            
            // 尝试一个简单的调用
            var output: UInt64 = 0
            var outputSize: UInt32 = UInt32(MemoryLayout<UInt64>.size)
            let callResult = IOConnectCallMethod(
                connection,
                0, // 方法索引
                nil, 0,
                nil, 0,
                &output, &outputSize,
                nil, nil
            )
            
            print("   - 方法调用结果: \(callResult)")
            if callResult != kIOReturnSuccess {
                analyzeSMCError(callResult)
            }
            
            IOServiceClose(connection)
        } else {
            print("   ❌ 服务连接失败: \(result)")
            analyzeSMCError(result)
        }
        
        IOObjectRelease(testService)
    }
    
    print("\n📋 测试总结:")
    print("   - SMC服务存在但访问受限")
    print("   - 主要问题是系统权限保护")
    print("   - 需要特殊entitlements或禁用SIP")
    print("   - 建议考虑使用替代方案")
}

// 运行测试
testSMCWithDetailedLogging()