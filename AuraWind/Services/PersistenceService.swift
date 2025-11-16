//
//  PersistenceService.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import Foundation

/// 数据持久化服务协议
protocol PersistenceServiceProtocol {
    /// 保存对象到 UserDefaults
    func save<T: Codable>(_ object: T, forKey key: String) throws
    
    /// 从 UserDefaults 加载对象
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    
    /// 删除 UserDefaults 中的对象
    func delete(forKey key: String)
    
    /// 保存对象到文件
    func saveToFile<T: Codable>(_ object: T, filename: String) throws
    
    /// 从文件加载对象
    func loadFromFile<T: Codable>(_ type: T.Type, filename: String) throws -> T?
    
    /// 删除文件
    func deleteFile(filename: String) throws
}

/// 数据持久化服务实现
final class PersistenceService: PersistenceServiceProtocol {
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        
        // 配置编码器
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        
        // 配置解码器
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - UserDefaults 操作
    
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        do {
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
            userDefaults.synchronize()
        } catch {
            throw AuraWindError.encodingError(error)
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AuraWindError.decodingError(error)
        }
    }
    
    func delete(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
    }
    
    // MARK: - 文件操作
    
    func saveToFile<T: Codable>(_ object: T, filename: String) throws {
        let url = try getDocumentDirectory().appendingPathComponent(filename)
        
        do {
            let data = try encoder.encode(object)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch let error as EncodingError {
            throw AuraWindError.encodingError(error)
        } catch {
            throw AuraWindError.fileWriteError(error)
        }
    }
    
    func loadFromFile<T: Codable>(_ type: T.Type, filename: String) throws -> T? {
        let url = try getDocumentDirectory().appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch let error as DecodingError {
            throw AuraWindError.decodingError(error)
        } catch {
            throw AuraWindError.fileReadError(error)
        }
    }
    
    func deleteFile(filename: String) throws {
        let url = try getDocumentDirectory().appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw AuraWindError.fileWriteError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func getDocumentDirectory() throws -> URL {
        guard let url = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AuraWindError.documentDirectoryNotFound
        }
        
        // 创建应用专属目录
        let appDirectory = url.appendingPathComponent(Constants.App.bundleIdentifier)
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(
                at: appDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        return appDirectory
    }
}

// MARK: - 便捷方法

extension PersistenceService {
    /// 保存曲线配置
    func saveCurveProfile(_ profile: CurveProfile) throws {
        try save(profile, forKey: "\(Constants.UserDefaultsKeys.savedProfiles)_\(profile.id.uuidString)")
    }
    
    /// 加载曲线配置
    func loadCurveProfile(id: UUID) throws -> CurveProfile? {
        return try load(CurveProfile.self, forKey: "\(Constants.UserDefaultsKeys.savedProfiles)_\(id.uuidString)")
    }
    
    /// 删除曲线配置
    func deleteCurveProfile(id: UUID) {
        delete(forKey: "\(Constants.UserDefaultsKeys.savedProfiles)_\(id.uuidString)")
    }
    
    /// 保存所有曲线配置列表
    func saveCurveProfiles(_ profiles: [CurveProfile]) throws {
        try save(profiles, forKey: Constants.UserDefaultsKeys.savedProfiles)
    }
    
    /// 加载所有曲线配置
    func loadCurveProfiles() throws -> [CurveProfile] {
        return try load([CurveProfile].self, forKey: Constants.UserDefaultsKeys.savedProfiles) ?? []
    }
    
    /// 保存激活的曲线配置 ID
    func saveActiveCurveProfileId(_ id: UUID?) throws {
        if let id = id {
            try save(id, forKey: Constants.UserDefaultsKeys.activeCurveProfile)
        } else {
            delete(forKey: Constants.UserDefaultsKeys.activeCurveProfile)
        }
    }
    
    /// 加载激活的曲线配置 ID
    func loadActiveCurveProfileId() throws -> UUID? {
        return try load(UUID.self, forKey: Constants.UserDefaultsKeys.activeCurveProfile)
    }
    
    /// 保存自动启动设置
    func saveAutoStartEnabled(_ enabled: Bool) throws {
        userDefaults.set(enabled, forKey: Constants.UserDefaultsKeys.autoStartEnabled)
    }
    
    /// 加载自动启动设置
    func loadAutoStartEnabled() -> Bool {
        return userDefaults.bool(forKey: Constants.UserDefaultsKeys.autoStartEnabled)
    }
}