import SwiftUI

extension Notification.Name {
    static let dismissKeyboardWithAnimation = Notification.Name("dismissKeyboardWithAnimation")
}

struct MainTabView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var hasHinge = false
    @State private var hasVerticalBar = false
    @State private var keyboardVisible = false
    @State private var toolbarReveal: CGFloat = 0

    static let noteColors: [Color] = [
        Color(red: 0.70, green: 0.45, blue: 0.85),  // Purple
        Color(red: 0.35, green: 0.60, blue: 0.90),  // Blue
        Color(red: 0.40, green: 0.78, blue: 0.45),  // Green
        Color(red: 0.95, green: 0.75, blue: 0.25),  // Yellow
        Color(red: 0.95, green: 0.55, blue: 0.25),  // Orange
        Color(red: 0.90, green: 0.30, blue: 0.35),  // Red
    ]

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                NotePane(noteIndex: notesManager.selectedNoteIndex, showsDotBar: !usesSidebar) { index in
                    notesManager.selectNote(index)
                }

                // Poses where the system shows no vertical bar still get a floating sidebar on iPhone Duo
                if showsOwnSidebar {
                    VStack {
                        if keyboardVisible {
                            // Sit the Done check just above the keyboard
                            Spacer()
                            DoneCheckButton()
                                .padding(.bottom, 8)
                        } else {
                            NoteDotBar(selectedIndex: notesManager.selectedNoteIndex, axis: .vertical, onSelect: notesManager.selectNote)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .onPreferenceChange(NoteToolbarRevealKey.self) { toolbarReveal = $0 }
            .background {
                // Grey from the top edge down to the bottom of the pull-down toolbar, across the
                // full width (status bar and sidebar included) while the toolbar is revealed
                GeometryReader { geometry in
                    Color(uiColor: .secondarySystemBackground)
                        .opacity(toolbarReveal)
                        .frame(height: geometry.safeAreaInsets.top + toolbarReveal * NoteEditorView.toolbarHeight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: [.top, .horizontal])
                }
            }
            .verticalBarControls(
                isEnabled: hasVerticalBar,
                selectedIndex: notesManager.selectedNoteIndex,
                keyboardVisible: keyboardVisible,
                onSelect: notesManager.selectNote
            )
            .toolbar(hasVerticalBar ? .automatic : .hidden, for: .navigationBar)
        }
        .observeHinge(isPresent: $hasHinge)
        .observeVerticalBar(hasVerticalBar: $hasVerticalBar)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        // Rotating or closing the device can drop the keyboard without a hide notification;
        // bring the dots back whenever editing ends
        .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidEndEditingNotification)) { _ in
            keyboardVisible = false
        }
    }

    private var sidebarPlacement: SidebarPlacement {
        SidebarPlacement(hasHinge: hasHinge, hasVerticalBar: hasVerticalBar)
    }

    private var usesSidebar: Bool {
        sidebarPlacement != .none
    }

    private var showsOwnSidebar: Bool {
        sidebarPlacement == .floating
    }
}

// MARK: - SidebarPlacement

/// Where the note dots and keyboard Done check live.
/// iPhone Duo keeps them in a sidebar in every pose.
enum SidebarPlacement: Equatable {
    /// Bottom dot bar and floating Done button (devices without a hinge or vertical bar)
    case none
    /// Hosted in the system vertical bar
    case system
    /// Drawn by the app along the trailing edge when the system shows no vertical bar
    case floating

    init(hasHinge: Bool, hasVerticalBar: Bool) {
        if hasVerticalBar {
            self = .system
        } else if hasHinge {
            self = .floating
        } else {
            self = .none
        }
    }
}

extension View {
    /// Tracks whether the device has a hinge (iPhone Duo). Always false on devices without a hinge.
    @ViewBuilder
    func observeHinge(isPresent: Binding<Bool>) -> some View {
        #if compiler(>=6.4.2)
        if #available(iOS 27.1, *) {
            onHingeChange { _, newContext in
                isPresent.wrappedValue = newContext.hinge != nil
            }
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Tracks whether the system places a vertical bar (iPhone Duo sidebar). Always false elsewhere.
    @ViewBuilder
    func observeVerticalBar(hasVerticalBar: Binding<Bool>) -> some View {
        #if compiler(>=6.4.2)
        if #available(iOS 27.1, *) {
            background(VerticalBarReader(hasVerticalBar: hasVerticalBar))
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Puts the note dots and the keyboard Done button in the vertical bar
    @ViewBuilder
    func verticalBarControls(
        isEnabled: Bool,
        selectedIndex: Int,
        keyboardVisible: Bool,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        #if compiler(>=6.4.2)
        // Branch only on availability (never isEnabled) so toggling the vertical bar
        // doesn't change view identity and recreate the editor, dropping the keyboard
        if #available(iOS 27.1, *) {
            toolbar {
                if isEnabled {
                    if keyboardVisible {
                        // Bottom of the vertical bar, next to the keyboard
                        ToolbarItem(placement: .bottomBar) {
                            DoneCheckButton()
                        }
                        .sharedBackgroundVisibility(.hidden)
                        .axisBehavior(.verticalPreferred)
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            NoteDotBar(selectedIndex: selectedIndex, axis: .vertical, onSelect: onSelect)
                        }
                        .sharedBackgroundVisibility(.hidden)
                        .axisBehavior(.verticalPreferred)
                    }
                }
            }
            .toolbarVerticalCompressionBehavior(.prefersToolbarItems)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if compiler(>=6.4.2)
@available(iOS 27.1, *)
private struct VerticalBarReader: UIViewRepresentable {
    @Binding var hasVerticalBar: Bool

    func makeUIView(context: Context) -> VerticalBarReaderView {
        let view = VerticalBarReaderView()
        view.isUserInteractionEnabled = false
        view.onChange = { hasVerticalBar = $0 }
        return view
    }

    func updateUIView(_ uiView: VerticalBarReaderView, context: Context) {
        uiView.onChange = { hasVerticalBar = $0 }
    }
}

@available(iOS 27.1, *)
private final class VerticalBarReaderView: UIView {
    var onChange: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (view: VerticalBarReaderView, _) in
            view.report()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        report()
    }

    private func report() {
        let hasVerticalBar = traitCollection.verticalBarEdge != .unspecified
        DispatchQueue.main.async { [weak self] in
            self?.onChange?(hasVerticalBar)
        }
    }
}
#endif

// MARK: - DoneCheckButton

/// Dismisses the keyboard; replaces the dots in the sidebar while the keyboard is up
struct DoneCheckButton: View {
    var body: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            NotificationCenter.default.post(name: .dismissKeyboardWithAnimation, object: nil)
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
    }
}

// MARK: - NotePane

struct NotePane: View {
    let noteIndex: Int
    var showsDotBar = true
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Note editor (no swipe navigation)
            NoteEditorView(noteIndex: noteIndex, showsDoneButton: showsDotBar)
                .id(noteIndex)

            if showsDotBar {
                NoteDotBar(selectedIndex: noteIndex, onSelect: onSelect)
            }
        }
    }
}

// MARK: - NoteDot

struct NoteDot: View {
    let index: Int
    let isSelected: Bool
    var settleOffset: CGFloat = 0
    @EnvironmentObject var notesManager: NotesManager

    var body: some View {
        let noteColor = MainTabView.noteColors[index]
        ZStack {
            // Outer ring
            if isSelected {
                Circle()
                    .stroke(noteColor.opacity(0.4), lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
            // Inner dot
            Circle()
                .fill(isSelected ? noteColor : (notesManager.hasContent(at: index) ? noteColor.opacity(0.6) : noteColor.opacity(0.2)))
                .frame(width: 12, height: 12)
                .offset(y: isSelected ? settleOffset : 0)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - NoteDotBar

struct NoteDotBar: View {
    let selectedIndex: Int
    /// Vertical when floating in the vertical bar
    var axis: Axis = .horizontal
    let onSelect: (Int) -> Void
    @State private var dotSettleOffset: CGFloat = 0
    @State private var keyboardVisible = false

    var body: some View {
        let layout = axis == .vertical ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 24))
        let bar = layout {
            ForEach(0..<6, id: \.self) { index in
                Button {
                    // Dismiss keyboard first, then switch tabs
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                    if keyboardVisible {
                        // Keyboard is up - disable animations to prevent interference
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            dotSettleOffset = -12
                            onSelect(index)
                        }
                    } else {
                        // No keyboard - animate the upward movement too
                        onSelect(index)
                        withAnimation(.easeOut(duration: 0.15)) {
                            dotSettleOffset = -12
                        }
                    }

                    // Animate bounce after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                            dotSettleOffset = 0
                        }
                    }
                } label: {
                    NoteDot(index: index, isSelected: selectedIndex == index, settleOffset: dotSettleOffset)
                        .transaction { t in t.disablesAnimations = true }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Note \(index + 1)")
            }
        }
        .transaction { t in t.disablesAnimations = true }

        Group {
            if axis == .vertical {
                bar
            } else {
                bar
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .systemBackground))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissKeyboardWithAnimation)) { _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dotSettleOffset = -12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    dotSettleOffset = 0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = context.coordinator.completionHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        context.coordinator.onComplete = onComplete
    }

    class Coordinator {
        var onComplete: ((Bool) -> Void)?

        init(onComplete: ((Bool) -> Void)?) {
            self.onComplete = onComplete
        }

        lazy var completionHandler: UIActivityViewController.CompletionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            self?.onComplete?(completed)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(NotesManager())
}
