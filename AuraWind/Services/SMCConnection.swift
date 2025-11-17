//
//  SMCConnection.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import Foundation
import IOKit

/// SMC连接管理类
/// 负责与macOS System Management Controller的底层通信
final class SMCConnection {
    
    // MARK: - Types
    
    /// SMC数据类型
    enum SMCDataType: String {
        case flt = "flt "  // 浮点数
        case ui8 = "ui8 "  // 8位无符号整数
        case ui16 = "ui16"  // 16位无符号整数
        case ui32 = "ui32"  // 32位无符号整数
        case fpe2 = "fpe2"  // 定点数(14.2格式)
        case sp78 = "sp78"  // 定点数(16.8格式)
        
        var fourCharCode: UInt32 {
            rawValue.fourCharCode
        }
    }
    
    /// SMC键信息
    struct SMCKeyInfo {
        let key: String
        let dataType: SMCDataType
        let dataSize: UInt32
    }
    
    /// SMC值结果
    struct SMCValue {
        let key: String
        let dataType: SMCDataType
        let value: Double
        let bytes: [UInt8]
    }
    
    // MARK: - Properties
    
    /// SMC连接句柄
    private var connection: io_connect_t = 0
    
    /// 连接状态
    private(set) var isConnected: Bool = false
    
    /// SMC服务引用
    private var service: io_service_t = 0
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    /// 连接到SMC服务
    func connect() throws {
        guard !isConnected else { return }
        
        // 获取SMC服务
        service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        
        guard service != 0 else {
            throw AuraWindError.smcServiceNotFound
        }
        
        // 打开服务连接
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        
        if result != kIOReturnSuccess {
            IOObjectRelease(service)
            service = 0
            throw AuraWindError.smcConnectionFailed
        }
        
        isConnected = true
    }
    
    /// 断开SMC连接
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
    
    // MARK: - SMC Operations
    
    /// 读取SMC值
    func readValue(key: String, type: SMCDataType) throws -> SMCValue {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        guard key.count == 4 else {
            throw AuraWindError.invalidConfiguration
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
        
        // 解析数据
        let bytes = extractBytes(from: output, size: Int(output.keyInfo.dataSize))
        let value = parseSMCValue(bytes: bytes, type: type)
        
        return SMCValue(
            key: key,
            dataType: type,
            value: value,
            bytes: bytes
        )
    }
    
    /// 写入SMC值
    func writeValue(key: String, value: Double, type: SMCDataType) throws {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        guard key.count == 4 else {
            throw AuraWindError.invalidConfiguration
        }
        
        // 获取键信息
        var input = SMCKeyData()
        input.key = key.fourCharCode
        input.data8 = SMC_CMD_READ_KEYINFO
        
        var output = SMCKeyData()
        try performSMCCall(input: &input, output: &output)
        
        // 准备写入数据
        let bytes = convertValueToBytes(value: value, type: type, size: Int(output.keyInfo.dataSize))
        
        input.data8 = SMC_CMD_WRITE_BYTES
        input.keyInfo.dataSize = output.keyInfo.dataSize
        
        // 复制数据到结构体
        for (index, byte) in bytes.enumerated() {
            if index < MemoryLayout<SMCBytes>.size {
                input.bytes[index] = byte
            }
        }
        
        try performSMCCall(input: &input, output: &output)
    }
    
    // MARK: - Private Methods
    
    /// 执行SMC调用
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
            throw AuraWindError.smcReadFailed
        }
    }
    
    /// 从输出结构提取字节数据
    private func extractBytes(from data: SMCKeyData, size: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        for i in 0..<min(size, MemoryLayout<SMCBytes>.size) {
            bytes.append(data.bytes[i])
        }
        return bytes
    }
    
    /// 解析SMC值
    private func parseSMCValue(bytes: [UInt8], type: SMCDataType) -> Double {
        guard !bytes.isEmpty else { return 0.0 }
        
        switch type {
        case .flt:
            // 浮点数
            guard bytes.count >= 4 else { return 0.0 }
            return Double(Float(bitPattern: UInt32(bytes: Array(bytes.prefix(4)))))
            
        case .ui8:
            // 8位无符号整数
            return Double(bytes[0])
            
        case .ui16:
            // 16位无符号整数
            guard bytes.count >= 2 else { return 0.0 }
            return Double(UInt16(bytes: Array(bytes.prefix(2))))
            
        case .ui32:
            // 32位无符号整数
            guard bytes.count >= 4 else { return 0.0 }
            return Double(UInt32(bytes: Array(bytes.prefix(4))))
            
        case .fpe2:
            // 14.2定点数
            guard bytes.count >= 2 else { return 0.0 }
            let rawValue = UInt16(bytes: Array(bytes.prefix(2)))
            return Double(rawValue >> 2) + Double(rawValue & 0x3) * 0.25
            
        case .sp78:
            // 16.8定点数
            guard bytes.count >= 2 else { return 0.0 }
            let rawValue = UInt16(bytes: Array(bytes.prefix(2)))
            return Double(Int16(bitPattern: rawValue)) / 256.0
        }
    }
    
    /// 转换值为字节数据
    private func convertValueToBytes(value: Double, type: SMCDataType, size: Int) -> [UInt8] {
        switch type {
        case .flt:
            // 浮点数
            let floatValue = Float(value)
            return floatValue.bitPattern.bytes
            
        case .ui8:
            // 8位无符号整数
            return [UInt8(value)]
            
        case .ui16:
            // 16位无符号整数
            return UInt16(value).bytes
            
        case .ui32:
            // 32位无符号整数
            return UInt32(value).bytes
            
        case .fpe2:
            // 14.2定点数
            let intValue = Int(value)
            let fracValue = Int((value - Double(intValue)) * 4)
            let rawValue = (intValue << 2) | fracValue
            return UInt16(rawValue).bytes
            
        case .sp78:
            // 16.8定点数
            let rawValue = Int16(value * 256)
            return UInt16(bitPattern: rawValue).bytes
        }
    }
}

// MARK: - SMC数据结构

/// SMC键数据结构 (80 bytes total)
private struct SMCKeyData {
    var key: UInt32 = 0                    // 4 bytes
    var vers: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0)  // 6 bytes
    var pLimitData: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                     UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0,
                                                                                  0, 0, 0, 0, 0, 0, 0, 0)  // 16 bytes
    var keyInfo = SMCKeyInfoData()         // 6 bytes
    var result: UInt8 = 0                  // 1 byte
    var status: UInt8 = 0                  // 1 byte
    var data8: UInt8 = 0                   // 1 byte
    var data32: UInt32 = 0                 // 4 bytes
    var bytes = SMCBytes()                 // 32 bytes
    var padding: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0, 0)  // 9 bytes
}

/// SMC键信息数据结构 (6 bytes total)
private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0               // 4 bytes
    var dataType: UInt32 = 0               // 4 bytes (但只用低 2 bytes)
    var dataAttributes: UInt8 = 0          // 1 byte
    var padding: UInt8 = 0                 // 1 byte padding
}

/// SMC字节数组
private struct SMCBytes {
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
            case 4: return bytes.4
            case 5: return bytes.5
            case 6: return bytes.6
            case 7: return bytes.7
            case 8: return bytes.8
            case 9: return bytes.9
            case 10: return bytes.10
            case 11: return bytes.11
            case 12: return bytes.12
            case 13: return bytes.13
            case 14: return bytes.14
            case 15: return bytes.15
            case 16: return bytes.16
            case 17: return bytes.17
            case 18: return bytes.18
            case 19: return bytes.19
            case 20: return bytes.20
            case 21: return bytes.21
            case 22: return bytes.22
            case 23: return bytes.23
            case 24: return bytes.24
            case 25: return bytes.25
            case 26: return bytes.26
            case 27: return bytes.27
            case 28: return bytes.28
            case 29: return bytes.29
            case 30: return bytes.30
            case 31: return bytes.31
            default: return 0
            }
        }
        set {
            switch index {
            case 0: bytes.0 = newValue
            case 1: bytes.1 = newValue
            case 2: bytes.2 = newValue
            case 3: bytes.3 = newValue
            case 4: bytes.4 = newValue
            case 5: bytes.5 = newValue
            case 6: bytes.6 = newValue
            case 7: bytes.7 = newValue
            case 8: bytes.8 = newValue
            case 9: bytes.9 = newValue
            case 10: bytes.10 = newValue
            case 11: bytes.11 = newValue
            case 12: bytes.12 = newValue
            case 13: bytes.13 = newValue
            case 14: bytes.14 = newValue
            case 15: bytes.15 = newValue
            case 16: bytes.16 = newValue
            case 17: bytes.17 = newValue
            case 18: bytes.18 = newValue
            case 19: bytes.19 = newValue
            case 20: bytes.20 = newValue
            case 21: bytes.21 = newValue
            case 22: bytes.22 = newValue
            case 23: bytes.23 = newValue
            case 24: bytes.24 = newValue
            case 25: bytes.25 = newValue
            case 26: bytes.26 = newValue
            case 27: bytes.27 = newValue
            case 28: bytes.28 = newValue
            case 29: bytes.29 = newValue
            case 30: bytes.30 = newValue
            case 31: bytes.31 = newValue
            default: break
            }
        }
    }
}

// MARK: - SMC命令常量

private let KERNEL_INDEX_SMC: UInt32 = 2
private let SMC_CMD_READ_KEYINFO: UInt8 = 9
private let SMC_CMD_READ_BYTES: UInt8 = 5
private let SMC_CMD_WRITE_BYTES: UInt8 = 6

// MARK: - 扩展辅助方法

private extension String {
    /// 将4字符字符串转换为FourCharCode
    var fourCharCode: UInt32 {
        var code: UInt32 = 0
        for char in self.utf8.prefix(4) {
            code = (code << 8) + UInt32(char)
        }
        return code
    }
}

private extension UInt16 {
    /// 从字节数组初始化
    init(bytes: [UInt8]) {
        self = 0
        if bytes.count >= 2 {
            self = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        }
    }
    
    /// 转换为字节数组
    var bytes: [UInt8] {
        return [UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}

private extension UInt32 {
    /// 从字节数组初始化
    init(bytes: [UInt8]) {
        self = 0
        if bytes.count >= 4 {
            self = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        }
    }
    
    /// 转换为字节数组
    var bytes: [UInt8] {
        return [
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF)
        ]
    }
}
