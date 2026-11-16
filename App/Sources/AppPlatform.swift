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

    /// iPhone: a bar above the number pad with one button ("Fertig" or "Weiter"), only while
    /// `isActive` (R31). The Mac has Return.
    @ViewBuilder
    func keypadButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        #if os(iOS)
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isActive {
                    Spacer()
                    Button(title, action: action)
                        .fontWeight(.semibold)
                }
            }
        }
        #else
        self
        #endif
    }
}
