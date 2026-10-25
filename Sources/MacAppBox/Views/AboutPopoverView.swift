import AppKit
import SwiftUI

struct AboutPopoverView: View {
    let version: String
    let build: String?
    let accentColor: Color
    let fontColor: Color
    let chineseFontName: String
    let latinFontName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("MacApp Box")
                        .font(AppTypography.font(
                            named: latinFontName,
                            size: 17,
                            weight: .semibold
                        ))
                        .foregroundStyle(fontColor)
                    Text("应用启动与分类工具")
                        .font(AppTypography.font(
                            named: chineseFontName,
                            size: 10.5,
                            weight: .medium
                        ))
                        .foregroundStyle(fontColor.opacity(0.5))
                }
            }

            Rectangle()
                .fill(fontColor.opacity(0.08))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Label("功能", systemImage: "sparkles")
                    .font(AppTypography.font(
                        named: chineseFontName,
                        size: 11,
                        weight: .semibold
                    ))
                    .foregroundStyle(accentColor)

                Text("按 macOS / Windows 独立分类管理应用，支持搜索、文件夹、拖动排序、多项选择、布局快照、自动分类与深度卸载。")
                    .font(AppTypography.font(
                        named: chineseFontName,
                        size: 10.5,
                        weight: .regular
                    ))
                    .foregroundStyle(fontColor.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                aboutRow(
                    title: "版本号",
                    value: build.map { "\(version) (\($0))" } ?? version
                )
                aboutRow(title: "开发者", value: "williamgvyan")
            }
        }
        .padding(18)
        .frame(width: 310)
        .background(.regularMaterial)
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(fontColor.opacity(0.52))
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(AppTypography.font(
                    named: latinFontName,
                    size: 11,
                    weight: .medium
                ))
                .foregroundStyle(fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(AppTypography.font(
            named: chineseFontName,
            size: 10.5,
            weight: .medium
        ))
    }
}
