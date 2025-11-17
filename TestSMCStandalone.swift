#!/usr/bin/env swift

import Foundation
import IOKit

// SMC数据结构
struct SMCKeyData {
    var key: UInt32 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var keyInfo = SMCKeyInfoData()
    var bytes = SMCBytes()
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCBytes {
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0,
                                                                              0, 0, 0, 0, 0, 0, 0, 0,
                                                                              0, 0, 0, 0, 0, 0, 0, 0,
                                                                              0, 0, 0, 0, 0, 0, 0, 0)
    
    subscript(index: Int) -> UInt8 {
        get {
            switch index {
            case 0: return bytes.0
            case 1: return bytes.1
            case 2: return bytes.2
            case 3: return bytes.3
            default: return 0
            }
        }
        set {
            switch index {
            case 0: bytes.0 = newValue
            case 1: bytes.1 = newValue
            case 2: bytes.2 = newValue
            case 3: bytes.3 = newValue
            default: break
            }
        }
    }
}

// SMC常量
let KERNEL_INDEX_SMC: UInt32 = 2
let SMC_CMD_READ_KEYINFO: UInt8 = 9
let SMC_CMD_READ_BYTES: UInt8 = 5

// 扩展
extension String {
    var fourCharCode: UInt32 {
        var code: UInt32 = 0
        for char in self.utf8.prefix(4) {
            code = (code << 8) + UInt32(char)
        }
        return code
    }
}

// SMC连接类
class SimpleSMCConnection {
    private var connection: io_connect_t = 0
    private var service: io_service_t = 0
    private var isConnected: Bool = false
    
    func connect() throws {
        guard !isConnected else { return }
        
        // 获取SMC服务
        service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        
        guard service != 0 else {
            throw NSError(domain: "SMC", code: 1, userInfo: [NSLocalizedDescriptionKey: "SMC服务未找到"])
        }
        
        // 打开服务连接
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        
        if result != kIOReturnSuccess {
            IOObjectRelease(service)
            service = 0
            throw NSError(domain: "SMC", code: 2, userInfo: [NSLocalizedDescriptionKey: "SMC连接失败"])
        }
        
        isConnected = true
        print("✅ SMC连接成功")
    }
    
    func disconnect() {
        guard isConnected else { return }
        
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
        
        if service != 0 {
            IOObjectRelease(service)
            service = 0
        }
        
        isConnected = false
    }
    
    func readValue(key: String) throws -> Double {
        guard isConnected else {
            throw NSError(domain: "SMC", code: 3, userInfo: [NSLocalizedDescriptionKey: "SMC未连接"])
        }
        
        guard key.count == 4 else {
            throw NSError(domain: "SMC", code: 4, userInfo: [NSLocalizedDescriptionKey: "无效的SMC键"])
        }
        
        // 准备输入结构
        var input = SMCKeyData()
        input.key = key.fourCharCode
        input.data8 = SMC_CMD_READ_KEYINFO
        
        // 获取键信息
        var output = SMCKeyData()
        try performSMCCall(input: &input, output: &output)
        
        // 读取实际数据
        input.data8 = SMC_CMD_READ_BYTES
        input.keyInfo.dataSize = output.keyInfo.dataSize
        try performSMCCall(input: &input, output: &output)
        
        // 解析数据（简化版本）
        let bytes = extractBytes(from: output, size: Int(output.keyInfo.dataSize))
        return parseSMCValue(bytes: bytes)
    }
    
    private func performSMCCall(input: inout SMCKeyData, output: inout SMCKeyData) throws {
        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size
        
        let result = IOConnectCallStructMethod(
            connection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            inputSize,
            &output,
            &outputSize
        )
        
        if result != kIOReturnSuccess {
            throw NSError(domain: "SMC", code: 5, userInfo: [NSLocalizedDescriptionKey: "SMC调用失败: \(result)"])
        }
    }
    
    private func extractBytes(from data: SMCKeyData, size: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        for i in 0..<min(size, 32) {
            bytes.append(data.bytes[i])
        }
        return bytes
    }
    
    private func parseSMCValue(bytes: [UInt8]) -> Double {
        guard !bytes.isEmpty else { return 0.0 }
        
        // 简化的解析 - 假设是16位整数
        if bytes.count >= 2 {
            let value = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(value)
        }
        
        return Double(bytes[0])
    }
}

// 测试函数
func testSMC() {
    print("🧪 开始测试SMC连接...")
    
    let connection = SimpleSMCConnection()
    
    do {
        // 测试连接
        try connection.connect()
        
        // 测试读取风扇数量
        print("\n📊 测试风扇数量...")
        do {
            let fanCount = try connection.readValue(key: "FNum")
            print("✅ 风扇数量: \(Int(fanCount))")
        } catch {
            print("⚠️ 风扇数量读取失败: \(error)")
        }
        
        // 测试读取温度
        print("\n🌡️ 测试温度读取...")
        let tempKeys = ["TC0D", "TC0C", "TC0P", "TG0D", "TA0P"]
        for key in tempKeys {
            do {
                let temp = try connection.readValue(key: key)
                print("✅ \(key): \(temp/100)°C") // 假设需要除以100
                break // 找到第一个有效的就停止
            } catch {
                print("⚠️ \(key) 读取失败")
            }
        }
        
        // 测试读取风扇转速
        print("\n🌀 测试风扇转速...")
        do {
            let fan0Speed = try connection.readValue(key: "F0Ac")
            print("✅ 风扇0转速: \(Int(fan0Speed)) RPM")
        } catch {
            print("⚠️ 风扇0转速读取失败: \(error)")
        }
        
        connection.disconnect()
        print("\n✅ 测试完成")
        
    } catch {
        print("❌ SMC连接失败: \(error)")
        
        // 提供更详细的错误信息
        if let nsError = error as NSError? {
            print("错误详情:")
            print("  域: \(nsError.domain)")
            print("  代码: \(nsError.code)")
            print("  描述: \(nsError.localizedDescription)")
            
            if nsError.domain == "SMC" && nsError.code == 2 {
                print("\n💡 可能的原因:")
                print("  1. 应用缺少必要的entitlements")
                print("  2. 系统完整性保护(SIP)阻止访问")
                print("  3. 需要管理员权限")
                print("  4. SMC服务被其他进程占用")
            }
        }
    }
}

// 运行测试
print("=== SMC连接测试工具 ===")
print("时间: \(Date())")
print("系统: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("")

testSMC()