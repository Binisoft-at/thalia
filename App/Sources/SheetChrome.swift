import SwiftUI
import BinisoftKit
import ThaliaCore

// Window chrome shared by every sheet: toasts on the topmost layer (R13), sheet sizes that fit the
// Mac main window (R15), unsaved input that blocks menu commands (R14) and the close button (R73).
// The kit's `.toasts()` and `.sheetFrame()` stay unused in the app (kit unchanged, handbook 22/23).

extension View {
    /// Shows the app's toast on this layer – only while it is the topmost one (window, sheet,
    /// sheet on a sheet …), so a toast never hides behind an open sheet (R13).
    func toastHost(_ app: AppModel) -> some View {
        modifier(ToastHostModifier(app: app))
    }

    /// Mac: a sheet as tall as `height`, but never taller than the main window allows; it scrolls
    /// instead (R15). iPhone/iPad: unchanged.
    func thaliaSheetFrame(width: CGFloat, height: CGFloat) -> some View {
        modifier(ThaliaSheetFrameModifier(width: width, height: height))
    }

    /// Tells the app that this sheet holds typed input that isn't saved yet: menu commands that
    /// open another sheet are disabled meanwhile (R14).
    func unsavedInput(_ isDirty: Bool, in app: AppModel) -> some View {
        modifier(UnsavedInputModifier(isDirty: isDirty, app: app))
    }
}

/// × to close a sheet that confirms nothing; VoiceOver says "Schließen" (R73).
struct SheetCloseButton: View {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("Schließen")
        .help("Schließen")
    }
}

// MARK: Toasts (R13)

private struct ToastHostModifier: ViewModifier {
    let app: AppModel
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = visibleToast {
                    ThaliaToastView(toast: toast) { app.toasts.performUndo() }
                        .padding(.bottom, bottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .onAppear { app.registerToastHost(id) }
            .onDisappear { app.unregisterToastHost(id) }
    }

    /// The current toast, if this layer is the topmost one.
    private var visibleToast: Toast? {
        guard app.toastLevel > 0, app.toastLayer(of: id) == app.toastLevel else { return nil }
        return app.toasts.current
    }

    /// Above the tab bar on the window, close to the edge on sheets.
    private var bottomPadding: CGFloat {
        app.toastLayer(of: id) <= 1 ? 72 : 16
    }
}

/// The kit's toast, with a German Undo button.
private struct ThaliaToastView: View {
    let toast: Toast
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.symbol)
                .foregroundStyle(Brand.accent)
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            if toast.undo != nil {
                Spacer(minLength: 8)
                Button("Widerrufen", action: onUndo)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .floatingGlass(cornerRadius: 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: 520)
        .sensoryFeedback(.success, trigger: toast.id)
    }
}

// MARK: Sheet size (R15)

private struct ThaliaSheetFrameModifier: ViewModifier {
    let width: CGFloat
    let height: CGFloat
    @Environment(AppModel.self) private var app: AppModel?

    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: width, idealWidth: width + 40, maxWidth: .infinity,
                      minHeight: 360, idealHeight: fittingHeight, maxHeight: fittingHeight)
        #else
        content
        #endif
    }

    /// The asked height, at most the main window's height minus a margin (at least 360).
    private var fittingHeight: CGFloat {
        let window: CGFloat = app?.mainWindowHeight ?? 800
        return min(height, max(360, window - 80))
    }
}

// MARK: Unsaved input (R14)

private struct UnsavedInputModifier: ViewModifier {
    let isDirty: Bool
    let app: AppModel

    func body(content: Content) -> some View {
        content
            .onAppear { app.hasUnsavedInput = isDirty }
            .onChange(of: isDirty) { _, dirty in app.hasUnsavedInput = dirty }
            .onDisappear { app.hasUnsavedInput = false }
    }
}
