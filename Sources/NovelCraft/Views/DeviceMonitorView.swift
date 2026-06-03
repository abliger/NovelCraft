import SwiftUI

#if os(macOS)

/// 设备监控面板视图，实时展示 CPU、内存与网络的使用情况。
struct DeviceMonitorView: View {
    @StateObject private var engine = DeviceStatsEngine()
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding([.horizontal, .top])
            
            Divider()
                .padding(.vertical, 10)
            
            VStack(spacing: 10) {
                CPUMonitorCard(usage: engine.cpuUsage)
                MemoryMonitorCard(used: engine.memoryUsed, total: engine.memoryTotal, pressure: engine.memoryPressure)
                NetworkMonitorCard(sent: engine.networkSentPerSec, recv: engine.networkRecvPerSec, totalSent: engine.networkTotalSent, totalRecv: engine.networkTotalRecv)
            }
            .padding(.horizontal)
            
            Spacer(minLength: 0)
        }
        .frame(width: 360, height: 460)
        .onAppear {
            engine.startMonitoring()
        }
        .onDisappear {
            engine.stopMonitoring()
        }
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text("设备监控")
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
        }
    }
}

// MARK: - CPU 卡片

struct CPUMonitorCard: View {
    let usage: Double
    
    var body: some View {
        MonitorCard(icon: "cpu", title: "CPU", color: .orange) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("使用率")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", usage))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(usageColor)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(usageColor)
                            .frame(width: geo.size.width * min(CGFloat(usage) / 100.0, 1.0), height: 6)
                            .animation(.easeInOut(duration: 0.5), value: usage)
                    }
                }
                .frame(height: 6)
            }
        }
    }
    
    private var usageColor: Color {
        if usage < 50 { return .green }
        if usage < 80 { return .orange }
        return .red
    }
}

// MARK: - 内存卡片

struct MemoryMonitorCard: View {
    let used: UInt64
    let total: UInt64
    let pressure: Double
    
    var body: some View {
        MonitorCard(icon: "memorychip", title: "内存", color: .blue) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("已用 / 总计")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(DeviceStatsEngine.formatBytes(used)) / \(DeviceStatsEngine.formatBytes(total))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(pressureColor)
                            .frame(width: geo.size.width * min(CGFloat(pressure) / 100.0, 1.0), height: 6)
                            .animation(.easeInOut(duration: 0.5), value: pressure)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Spacer()
                    Text(String(format: "%.1f%%", pressure))
                        .font(.caption)
                        .foregroundStyle(pressureColor)
                }
            }
        }
    }
    
    private var pressureColor: Color {
        if pressure < 60 { return .green }
        if pressure < 85 { return .orange }
        return .red
    }
}

// MARK: - 网络卡片

struct NetworkMonitorCard: View {
    let sent: UInt64
    let recv: UInt64
    let totalSent: UInt64
    let totalRecv: UInt64
    
    var body: some View {
        MonitorCard(icon: "network", title: "网络", color: .teal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("上传", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(DeviceStatsEngine.formatSpeed(sent))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Label("下载", systemImage: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(DeviceStatsEngine.formatSpeed(recv))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                    }
                    
                    Spacer(minLength: 0)
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("累计上传")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(DeviceStatsEngine.formatBytes(totalSent))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("累计下载")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(DeviceStatsEngine.formatBytes(totalRecv))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - 通用监控卡片容器

struct MonitorCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(10)
    }
}

#endif
