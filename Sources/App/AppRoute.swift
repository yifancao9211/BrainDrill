import Foundation

enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case training
    case history
    case statistics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .training:
            "开始训练"
        case .history:
            "历史记录"
        case .statistics:
            "统计面板"
        case .settings:
            "设置"
        }
    }

    var subtitle: String {
        switch self {
        case .training:
            "专注完成一轮舒尔特方格训练"
        case .history:
            "回看最近的训练表现"
        case .statistics:
            "观察趋势、最佳成绩与练习密度"
        case .settings:
            "管理默认难度与训练偏好"
        }
    }

    var systemImage: String {
        switch self {
        case .training:
            "square.grid.3x3.fill"
        case .history:
            "clock.arrow.circlepath"
        case .statistics:
            "chart.bar.xaxis"
        case .settings:
            "slider.horizontal.3"
        }
    }
}
