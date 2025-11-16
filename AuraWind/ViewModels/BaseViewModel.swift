//
//  BaseViewModel.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import Foundation
import Combine

/// 基础 ViewModel 协议
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    
    /// 当前状态
    var state: State { get }
    
    /// 错误信息
    var error: AuraWindError? { get set }
    
    /// 是否正在加载
    var isLoading: Bool { get set }
}

/// 基础 ViewModel 类
@MainActor
class BaseViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// 错误信息
    @Published var error: AuraWindError?
    
    /// 是否正在加载
    @Published var isLoading: Bool = false
    
    // MARK: - Properties
    
    /// Combine 订阅集合
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Methods
    
    /// 设置数据绑定（子类可重写）
    open func setupBindings() {
        // 子类实现具体的绑定逻辑
    }
    
    /// 处理错误
    /// - Parameter error: 错误对象
    func handleError(_ error: Error) {
        if let auraWindError = error as? AuraWindError {
            self.error = auraWindError
        } else {
            self.error = .unknownError(error)
        }
    }
    
    /// 清除错误
    func clearError() {
        error = nil
    }
    
    /// 执行异步任务（带加载状态）
    /// - Parameter task: 异步任务
    func performTask(_ task: @escaping () async throws -> Void) async {
        isLoading = true
        clearError()
        
        do {
            try await task()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    /// 执行异步操作（不带加载状态）
    /// - Parameter operation: 异步操作
    func performAsyncOperation(_ operation: @escaping () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            handleError(error)
        }
    }
}

// MARK: - 状态管理扩展

extension BaseViewModel {
    /// 安全地更新状态（确保在主线程）
    /// - Parameter update: 更新闭包
    func updateState(_ update: @escaping () -> Void) {
        Task { @MainActor in
            update()
        }
    }
}