import Foundation
#if canImport(Metal)
import Metal
#endif

#if os(macOS)
import Darwin
import MachO

/// 设备统计引擎，负责采集 CPU、内存、GPU 与网络的使用数据。
///
/// 通过定时采样（默认 5 秒间隔）计算差值，提供实时使用率与速率。
@MainActor
final class DeviceStatsEngine: ObservableObject {
    /// 当前 CPU 使用率（0-100%）
    @Published var cpuUsage: Double = 0
    /// 当前内存使用量（字节）
    @Published var memoryUsed: UInt64 = 0
    /// 总物理内存（字节）
    @Published var memoryTotal: UInt64 = 0
    /// 内存压力百分比（0-100%）
    @Published var memoryPressure: Double = 0
    /// GPU 名称
    @Published var gpuName: String = "未知"
    /// 网络发送速率（字节/秒）
    @Published var networkSentPerSec: UInt64 = 0
    /// 网络接收速率（字节/秒）
    @Published var networkRecvPerSec: UInt64 = 0
    /// 累计网络发送（字节）
    @Published var networkTotalSent: UInt64 = 0
    /// 累计网络接收（字节）
    @Published var networkTotalRecv: UInt64 = 0
    /// 采样时间戳
    @Published var lastUpdateTime: Date = Date()
    
    private var timer: Timer?
    private var previousCPUInfo: host_cpu_load_info_data_t?
    private var previousNetworkStats: (sent: UInt64, recv: UInt64)?
    private var previousSampleTime: Date?
    
    init() {
        fetchStaticInfo()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    /// 开始定时采样。
    func startMonitoring(interval: TimeInterval = 5.0) {
        stopMonitoring()
        // 延迟首次采样，避免在 SwiftUI view update 中发布状态变化
        DispatchQueue.main.async { [weak self] in
            self?.sample()
        }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
    }
    
    /// 停止采样。
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        previousCPUInfo = nil
        previousNetworkStats = nil
        previousSampleTime = nil
    }
    
    // MARK: - 单次采样
    
    private func sample() {
        let now = Date()
        sampleCPU()
        sampleMemory()
        sampleNetwork(currentTime: now)
        lastUpdateTime = now
    }
    
    // MARK: - CPU
    
    private func sampleCPU() {
        var cpuLoadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        if let prev = previousCPUInfo {
            let userDiff = cpuLoadInfo.cpu_ticks.0 &- prev.cpu_ticks.0
            let sysDiff  = cpuLoadInfo.cpu_ticks.1 &- prev.cpu_ticks.1
            let idleDiff = cpuLoadInfo.cpu_ticks.2 &- prev.cpu_ticks.2
            let niceDiff = cpuLoadInfo.cpu_ticks.3 &- prev.cpu_ticks.3
            let totalDiff = userDiff &+ sysDiff &+ idleDiff &+ niceDiff
            
            if totalDiff > 0 {
                let usedDiff = userDiff &+ sysDiff &+ niceDiff
                cpuUsage = Double(usedDiff) / Double(totalDiff) * 100.0
            }
        }
        
        previousCPUInfo = cpuLoadInfo
    }
    
    // MARK: - 内存
    
    private func sampleMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let _         = UInt64(stats.free_count) * pageSize
        let active    = UInt64(stats.active_count) * pageSize
        let wired     = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        
        memoryUsed = active + wired + compressed
        memoryPressure = memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) * 100.0 : 0
    }
    
    // MARK: - 静态信息
    
    private func fetchStaticInfo() {
        // 总物理内存
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var size = MemoryLayout<UInt64>.size
        var totalMemory: UInt64 = 0
        sysctl(&mib, 2, &totalMemory, &size, nil, 0)
        memoryTotal = totalMemory
        
        // GPU 名称
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            gpuName = device.name
        }
        #endif
    }
    
    // MARK: - 网络
    
    private func sampleNetwork(currentTime: Date) {
        let current = fetchNetworkRawStats()
        networkTotalSent = current.sent
        networkTotalRecv = current.recv
        
        if let prev = previousNetworkStats, let prevTime = previousSampleTime {
            let dt = currentTime.timeIntervalSince(prevTime)
            if dt > 0 {
                let sentDiff = current.sent >= prev.sent ? current.sent - prev.sent : 0
                let recvDiff = current.recv >= prev.recv ? current.recv - prev.recv : 0
                networkSentPerSec = UInt64(Double(sentDiff) / dt)
                networkRecvPerSec = UInt64(Double(recvDiff) / dt)
            }
        }
        
        previousNetworkStats = current
        previousSampleTime = currentTime
    }
    
    private func fetchNetworkRawStats() -> (sent: UInt64, recv: UInt64) {
        var ifaddrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrList) == 0, let firstAddr = ifaddrList else { return (0, 0) }
        defer { freeifaddrs(ifaddrList) }
        
        var totalSent: UInt64 = 0
        var totalRecv: UInt64 = 0
        
        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            if let data = interface.ifa_data, isPhysicalInterface(interface.ifa_name) {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                totalSent += UInt64(networkData.ifi_obytes)
                totalRecv += UInt64(networkData.ifi_ibytes)
            }
            guard let next = interface.ifa_next else { break }
            ptr = next
        }
        
        return (totalSent, totalRecv)
    }
    
    private func isPhysicalInterface(_ name: UnsafePointer<Int8>?) -> Bool {
        guard let name = name else { return false }
        let interfaceName = String(cString: name)
        // 排除 lo0（回环）和虚拟接口
        return interfaceName != "lo0" && !interfaceName.hasPrefix("utun") && !interfaceName.hasPrefix("llw")
    }
}

// MARK: - 格式化辅助

extension DeviceStatsEngine {
    /// 将字节数格式化为人类可读的字符串（如 1.5 GB）。
    static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// 将速率格式化为人类可读的字符串（如 1.5 MB/s）。
    static func formatSpeed(_ bytesPerSec: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        let base = formatter.string(fromByteCount: Int64(bytesPerSec))
        return "\(base)/s"
    }
}

#endif
