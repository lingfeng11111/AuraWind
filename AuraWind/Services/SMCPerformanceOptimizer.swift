//
//  SMCPerformanceOptimizer.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import Foundation

/// SMC性能优化器
/// 负责优化SMC访问性能和资源管理
final class SMCPerformanceOptimizer {
    
    // MARK: - Types
    
    /// 连接池配置
    struct ConnectionPoolConfig {
        let maxConnections: Int
        let connectionTimeout: TimeInterval
        let idleTimeout: TimeInterval
        let cleanupInterval: TimeInterval
        
        static let `default` = ConnectionPoolConfig(
            maxConnections: 3,
            connectionTimeout: 5.0,
            idleTimeout: 30.0,
            cleanupInterval: 60.0
        )
    }
    
    /// 缓存配置
    struct CacheConfig {
        let maxSize: Int
        let expirationTime: TimeInterval
        let cleanupInterval: TimeInterval
        
        static let `default` = CacheConfig(
            maxSize: 1000,
            expirationTime: 5.0,
            cleanupInterval: 30.0
        )
    }
    
    // MARK: - Properties
    
    /// 连接池
    private var connectionPool: [SMCConnection] = []
    
    /// 连接池配置
    private let poolConfig: ConnectionPoolConfig
    
    /// 缓存配置
    private let cacheConfig: CacheConfig
    
    /// SMC值缓存
    private var valueCache: [String: CachedSMCValue] = [:]
    
    /// 访问统计
    private var accessStats: [String: AccessStat] = [:]
    
    /// 清理定时器
    private var cleanupTimer: Timer?
    
    /// 访问队列
    private let accessQueue = DispatchQueue(label: "com.aurawind.smc.optimizer", qos: .userInitiated)
    
    /// 统计队列
    private let statsQueue = DispatchQueue(label: "com.aurawind.smc.stats", qos: .utility)
    
    // MARK: - Initialization
    
    init(poolConfig: ConnectionPoolConfig = .default, cacheConfig: CacheConfig = .default) {
        self.poolConfig = poolConfig
        self.cacheConfig = cacheConfig
        setupCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
        cleanupConnections()
    }
    
    // MARK: - Connection Management
    
    /// 获取连接
    func getConnection() throws -> SMCConnection {
        return try accessQueue.sync {
            // 查找可用连接
            if let connection = connectionPool.first(where: { !$0.isConnected }) {
                try connection.connect()
                return connection
            }
            
            // 创建新连接（如果未达到最大数量）
            if connectionPool.count < poolConfig.maxConnections {
                let connection = SMCConnection()
                try connection.connect()
                connectionPool.append(connection)
                return connection
            }
            
            // 等待可用连接
            throw AuraWindError.smcConnectionFailed
        }
    }
    
    /// 释放连接
    func releaseConnection(_ connection: SMCConnection) {
        accessQueue.async { [weak self] in
            guard self != nil else { return }
            
            // 断开连接但不移除，以便重用
            connection.disconnect()
        }
    }
    
    /// 清理连接池
    private func cleanupConnections() {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            for connection in self.connectionPool {
                // 这里可以添加更复杂的清理逻辑
                connection.disconnect()
            }
            self.connectionPool.removeAll()
        }
    }
    
    // MARK: - Cache Management
    
    /// 获取缓存值
    func getCachedValue(for key: String) -> Double? {
        return accessQueue.sync {
            guard let cached = valueCache[key],
                  cached.isValid(expirationTime: cacheConfig.expirationTime) else {
                return nil
            }
            return cached.value
        }
    }
    
    /// 设置缓存值
    func setCachedValue(_ value: Double, for key: String) {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查缓存大小
            if self.valueCache.count >= self.cacheConfig.maxSize {
                self.cleanupCache()
            }
            
            self.valueCache[key] = CachedSMCValue(value: value, timestamp: Date())
        }
    }
    
    /// 清理缓存
    private func cleanupCache() {
        let expiredKeys = valueCache.filter { !$0.value.isValid(expirationTime: cacheConfig.expirationTime) }.map { $0.key }
        
        for key in expiredKeys {
            valueCache.removeValue(forKey: key)
        }
        
        // 如果仍然过大，移除最旧的条目
        if valueCache.count > cacheConfig.maxSize {
            let sortedEntries = valueCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(valueCache.count - cacheConfig.maxSize)
            
            for (key, _) in entriesToRemove {
                valueCache.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Performance Statistics
    
    /// 记录访问
    func recordAccess(for key: String, duration: TimeInterval, success: Bool) {
        statsQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.accessStats[key] == nil {
                self.accessStats[key] = AccessStat()
            }
            
            self.accessStats[key]?.recordAccess(duration: duration, success: success)
        }
    }
    
    /// 获取访问统计
    func getAccessStats(for key: String) -> AccessStat? {
        return statsQueue.sync {
            return accessStats[key]
        }
    }
    
    /// 获取性能报告
    func getPerformanceReport() -> PerformanceReport {
        return statsQueue.sync {
            let totalAccesses = accessStats.values.reduce(0) { $0 + $1.totalAccesses }
            let successfulAccesses = accessStats.values.reduce(0) { $0 + $1.successfulAccesses }
            let totalDuration = accessStats.values.reduce(0.0) { $0 + $1.totalDuration }
            let averageDuration = totalAccesses > 0 ? totalDuration / Double(totalAccesses) : 0.0
            
            let cacheHitRate = calculateCacheHitRate()
            let connectionPoolUtilization = Double(connectionPool.count) / Double(poolConfig.maxConnections)
            
            return PerformanceReport(
                totalAccesses: totalAccesses,
                successfulAccesses: successfulAccesses,
                averageDuration: averageDuration,
                cacheHitRate: cacheHitRate,
                connectionPoolUtilization: connectionPoolUtilization,
                cacheSize: valueCache.count,
                activeConnections: connectionPool.filter { $0.isConnected }.count
            )
        }
    }
    
    /// 计算缓存命中率
    private func calculateCacheHitRate() -> Double {
        let totalCacheAccesses = accessStats.values.reduce(0) { $0 + $1.cacheHits + $1.cacheMisses }
        let cacheHits = accessStats.values.reduce(0) { $0 + $1.cacheHits }
        
        return totalCacheAccesses > 0 ? Double(cacheHits) / Double(totalCacheAccesses) : 0.0
    }
    
    // MARK: - Optimization Suggestions
    
    /// 获取优化建议
    func getOptimizationSuggestions() -> [OptimizationSuggestion] {
        let report = getPerformanceReport()
        var suggestions: [OptimizationSuggestion] = []
        
        if report.cacheHitRate < 0.5 {
            suggestions.append(OptimizationSuggestion(
                type: .cache,
                priority: .high,
                description: "缓存命中率较低(\(String(format: "%.1f", report.cacheHitRate * 100))%)，建议增加缓存时间或优化访问模式"
            ))
        }
        
        if report.connectionPoolUtilization > 0.8 {
            suggestions.append(OptimizationSuggestion(
                type: .connectionPool,
                priority: .medium,
                description: "连接池利用率较高(\(String(format: "%.1f", report.connectionPoolUtilization * 100))%)，建议增加最大连接数"
            ))
        }
        
        if report.averageDuration > 0.1 {
            suggestions.append(OptimizationSuggestion(
                type: .performance,
                priority: .medium,
                description: "平均访问时间较长(\(String(format: "%.3f", report.averageDuration))秒)，建议检查SMC响应时间"
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Private Methods
    
    /// 设置清理定时器
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cacheConfig.cleanupInterval, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    /// 执行清理
    private func performCleanup() {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 清理过期缓存
            self.cleanupCache()
            
            // 清理空闲连接
            let idleConnections = self.connectionPool.filter { !$0.isConnected }
            
            // 保留最小连接数
            let connectionsToRemove = max(0, idleConnections.count - 1)
            for _ in 0..<connectionsToRemove {
                if let connection = idleConnections.first {
                    connection.disconnect()
                    if let index = self.connectionPool.firstIndex(where: { $0 === connection }) {
                        self.connectionPool.remove(at: index)
                    }
                }
            }
        }
    }
}

// MARK: - 辅助类型

/// 缓存的SMC值
private struct CachedSMCValue {
    let value: Double
    let timestamp: Date
    
    func isValid(expirationTime: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) < expirationTime
    }
}

/// 访问统计
struct AccessStat {
    var totalAccesses: Int = 0
    var successfulAccesses: Int = 0
    var failedAccesses: Int = 0
    var totalDuration: TimeInterval = 0.0
    var cacheHits: Int = 0
    var cacheMisses: Int = 0
    
    mutating func recordAccess(duration: TimeInterval, success: Bool) {
        totalAccesses += 1
        totalDuration += duration
        
        if success {
            successfulAccesses += 1
        } else {
            failedAccesses += 1
        }
    }
    
    var averageDuration: TimeInterval {
        return totalAccesses > 0 ? totalDuration / Double(totalAccesses) : 0.0
    }
    
    var successRate: Double {
        return totalAccesses > 0 ? Double(successfulAccesses) / Double(totalAccesses) : 0.0
    }
}

/// 性能报告
struct PerformanceReport {
    let totalAccesses: Int
    let successfulAccesses: Int
    let averageDuration: TimeInterval
    let cacheHitRate: Double
    let connectionPoolUtilization: Double
    let cacheSize: Int
    let activeConnections: Int
    
    var successRate: Double {
        return totalAccesses > 0 ? Double(successfulAccesses) / Double(totalAccesses) : 0.0
    }
}

/// 优化建议类型
enum OptimizationSuggestionType {
    case cache
    case connectionPool
    case performance
    case configuration
}

/// 优化建议优先级
enum OptimizationPriority {
    case low
    case medium
    case high
}

/// 优化建议
struct OptimizationSuggestion {
    let type: OptimizationSuggestionType
    let priority: OptimizationPriority
    let description: String
}