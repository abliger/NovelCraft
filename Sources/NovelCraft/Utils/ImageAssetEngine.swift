import Foundation

/// 图片资源处理引擎
///
/// 负责根据用户设置处理图片：引用原路径、复制本地文件到项目存储库、或下载网络图片到项目存储库。
enum ImageAssetEngine {
    
    /// 图片处理方式枚举
    enum HandlingMode: Int {
        case reference = 0   // 引用原路径
        case copyLocal = 1   // 拷贝本地图片到项目
        case downloadWeb = 2 // 下载网图到项目
    }
    
    /// 返回项目的图片资源目录 URL（storagePath/assets/images/）
    static func assetsDirectory(for project: Project) -> URL {
        let baseURL = URL(fileURLWithPath: project.storagePath)
        let resolved = baseURL.resolvingSymlinksInPath().path
        // 拒绝包含 .. 组件的路径，防止路径遍历
        if resolved.contains("/..") || resolved.hasSuffix("/..") || resolved == ".." {
            fatalError("非法存储路径: \(project.storagePath)")
        }
        return baseURL.appendingPathComponent("assets/images", isDirectory: true)
    }
    
    /// 确保项目的图片资源目录存在
    @discardableResult
    static func ensureAssetsDirectory(for project: Project) -> URL? {
        let dir = assetsDirectory(for: project)
        do {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            return dir
        } catch {
            print("创建图片目录失败: \(error)")
            return nil
        }
    }
    
    /// 生成唯一文件名（UUID + 原扩展名）
    static func generateUniqueFileName(original: String) -> String {
        let uuid = UUID().uuidString.prefix(8)
        let ext = (original as NSString).pathExtension
        if ext.isEmpty {
            return "\(uuid).png"
        }
        return "\(uuid).\(ext)"
    }
    
    /// 复制本地图片到项目存储库
    ///
    /// - Parameters:
    ///   - url: 本地图片文件 URL
    ///   - project: 目标项目
    /// - Returns: 成功返回相对路径（如 `assets/images/xxx.png`），失败返回 nil
    static func copyLocalImage(url: URL, project: Project) -> String? {
        guard ensureAssetsDirectory(for: project) != nil else { return nil }
        let assetsDir = assetsDirectory(for: project)
        let fileName = generateUniqueFileName(original: url.lastPathComponent)
        let destination = assetsDir.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            return "assets/images/\(fileName)"
        } catch {
            print("复制图片失败: \(error)")
            return nil
        }
    }
    
    /// 下载网络图片到项目存储库
    ///
    /// - Parameters:
    ///   - url: 网络图片 URL
    ///   - project: 目标项目
    /// - Returns: 成功返回相对路径（如 `assets/images/xxx.png`），失败返回 nil
    static func downloadWebImage(url: URL, project: Project) async -> String? {
        guard ensureAssetsDirectory(for: project) != nil else { return nil }
        let assetsDir = assetsDirectory(for: project)
        let fileName = generateUniqueFileName(original: url.lastPathComponent)
        let destination = assetsDir.appendingPathComponent(fileName)
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("下载图片 HTTP 状态码异常")
                return nil
            }
            try data.write(to: destination)
            return "assets/images/\(fileName)"
        } catch {
            print("下载图片失败: \(error)")
            return nil
        }
    }
    
    /// 处理图片 URL，根据设置决定引用、拷贝或下载
    ///
    /// - Parameters:
    ///   - url: 图片 URL（本地文件或网络地址）
    ///   - project: 目标项目
    ///   - mode: 处理方式
    /// - Returns: 最终用于 Markdown 的路径字符串
    static func processImage(url: URL, project: Project, mode: HandlingMode) async -> String {
        let isWeb = url.scheme?.hasPrefix("http") == true
        
        switch mode {
        case .reference:
            // 引用原路径
            if isWeb {
                return url.absoluteString
            } else {
                return url.path
            }
            
        case .copyLocal:
            if isWeb {
                // 网络图片在"拷贝本地"模式下也引用原 URL
                return url.absoluteString
            }
            if let relativePath = copyLocalImage(url: url, project: project) {
                return relativePath
            }
            // 复制失败，回退到引用原路径
            return url.path
            
        case .downloadWeb:
            if isWeb {
                if let relativePath = await downloadWebImage(url: url, project: project) {
                    return relativePath
                }
                // 下载失败，回退到引用原 URL
                return url.absoluteString
            }
            // 本地图片在"下载网图"模式下拷贝到项目
            if let relativePath = copyLocalImage(url: url, project: project) {
                return relativePath
            }
            return url.path
        }
    }
    
    /// 判断 URL 是否为图片文件（基于扩展名）
    static func isImageFile(_ url: URL) -> Bool {
        let imageExtensions: Set<String> = [
            "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "heic", "svg"
        ]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}
