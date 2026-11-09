import SwiftUI

// Small platform differences, kept out of the screens.

extension View {
    /// Tighter section spacing in lists on iPhone and iPad (not available on the Mac).
    @ViewBuilder
    func compactListSections() -> some View {
        #if os(iOS)
        self.listSectionSpacing(.compact)
        #else
        self
        #endif
    }

    /// Keyboard type for numbers on iPhone; nothing on the Mac.
    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}
