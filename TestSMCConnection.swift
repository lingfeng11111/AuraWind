import Foundation
import IOKit

/// SMC测试工具
class TestSMCConnection {
    
    static func testConnection() {
        print("🧪 开始测试SMC连接...")
        
        do {
            // 测试1: 检查SMC服务是否存在
            print("\n1. 检查SMC服务...")
            let service = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching("AppleSMC")
            )
            
            if service != 0 {
                print("✅ SMC服务找到: \(service)")
                IOObjectRelease(service)
            } else {
                print("❌ SMC服务未找到")
                return
            }
            
            // 测试2: 尝试连接
            print("\n2. 尝试连接SMC...")
            let connection = SMCConnection()
            try connection.connect()
            print("✅ SMC连接成功")
            
            // 测试3: 读取温度
            print("\n3. 读取CPU温度...")
            do {
                let temp = try connection.readValue(key: "TC0D", type: .flt)
                print("✅ CPU温度: \(temp.value)°C")
            } catch {
                print("⚠️ CPU温度读取失败: \(error)")
                
                // 尝试其他温度键
                let tempKeys = ["TC0C", "TC0P", "TC1C", "TG0D", "TG0P", "TA0P"]
                for key in tempKeys {
                    do {
                        let temp = try connection.readValue(key: key, type: .flt)
                        print("✅ 找到温度传感器 \(key): \(temp.value)°C")
                        break
                    } catch {
                        print("⚠️ \(key) 读取失败")
                    }
                }
            }
            
            // 测试4: 读取风扇数量
            print("\n4. 读取风扇信息...")
            do {
                let fanCount = try connection.readValue(key: "FNum", type: .ui8)
                print("✅ 风扇数量: \(Int(fanCount.value))")
                
                // 读取风扇转速
                for i in 0..<Int(fanCount.value) {
                    do {
                        let speed = try connection.readValue(key: "F\(i)Ac", type: .fpe2)
                        print("✅ 风扇\(i)转速: \(Int(speed.value)) RPM")
                    } catch {
                        print("⚠️ 风扇\(i)读取失败: \(error)")
                    }
                }
            } catch {
                print("⚠️ 风扇信息读取失败: \(error)")
            }
            
            // 断开连接
            connection.disconnect()
            print("\n✅ 测试完成，连接已断开")
            
        } catch {
            print("❌ SMC测试失败: \(error)")
        }
    }
}

// 运行测试
TestSMCConnection.testConnection()