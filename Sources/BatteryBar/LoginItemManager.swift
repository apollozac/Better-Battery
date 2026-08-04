import ServiceManagement

enum LoginItemIndicator: Equatable {
    case off
    case on
    case approvalRequired
    case unavailable
}

enum LoginItemAction: Equatable {
    case register
    case unregister
    case openSettings
    case none
}

struct LoginItemPresentation: Equatable {
    let title: String
    let indicator: LoginItemIndicator
    let action: LoginItemAction
}

struct LoginItemManager {
    private let service = SMAppService.mainApp

    var presentation: LoginItemPresentation {
        Self.presentation(for: service.status)
    }

    func performToggle() throws {
        switch presentation.action {
        case .register:
            try service.register()
        case .unregister:
            try service.unregister()
        case .openSettings:
            SMAppService.openSystemSettingsLoginItems()
        case .none:
            break
        }
    }

    static func presentation(
        for status: SMAppService.Status
    ) -> LoginItemPresentation {
        switch status {
        case .notRegistered:
            LoginItemPresentation(
                title: "Open at Login",
                indicator: .off,
                action: .register
            )
        case .enabled:
            LoginItemPresentation(
                title: "Open at Login",
                indicator: .on,
                action: .unregister
            )
        case .requiresApproval:
            LoginItemPresentation(
                title: "Open at Login — Approval Required",
                indicator: .approvalRequired,
                action: .openSettings
            )
        case .notFound:
            LoginItemPresentation(
                title: "Open at Login",
                indicator: .off,
                action: .register
            )
        @unknown default:
            LoginItemPresentation(
                title: "Open at Login — Unavailable",
                indicator: .unavailable,
                action: .none
            )
        }
    }
}
