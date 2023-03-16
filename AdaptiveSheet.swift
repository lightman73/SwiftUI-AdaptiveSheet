//
//  AdaptiveSheet.swift
//  AdaptiveSheet
//
//  Created by Francesco Marini on 16/06/22.
//

import SwiftUI

struct AdaptiveSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {}
}


// MARK: - AdaptiveSheet
struct AdaptiveSheet<Content: View>: View {
    // MARK: - Constants
    private enum LocalUIConstants {
        static let dismissDragOffsetPercent = 25.0
        static let dismissAnimationDuration = 0.35
        static let dismissAnimationDelay = 0.0
        static let appearAnimationDuration = 0.2
        static let appearAnimationDelay = 0.0
        static let contentBottomPadding = 40.0
        static let sheetCornerRadius = 24.0
        static let dragIndicatorCornerRadius = 20.0
        static let dragIndicatorWidth = 40.0
        static let dragIndicatorHeight = 4.0
    }


    @Binding var isShowingSheet: Bool
    @Binding var shouldDismissSheet: Bool
    var shouldBlurBackground: Bool = true
    var backgroundColor = Color.background
    var avoidBottomPadding: Bool = false
    var maxHeight: CGFloat?
    var sheetCornerRadius: CGFloat = LocalUIConstants.sheetCornerRadius
    var onDismiss: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var sheetHeight: CGFloat = .zero
    @State private var offsetY: CGFloat = .zero {
        didSet {
            let percent = (sheetHeight - offsetY) / sheetHeight
            currentBlurRadius = percent * blurRadius
            currentBackdropOpacity = percent * backdropOpacity
        }
    }
    @State private var currentBlurRadius: CGFloat = .zero
    @State private var currentBackdropOpacity: CGFloat = .zero

    var blurRadius: CGFloat = 3.0
    var backdropOpacity: CGFloat = 0.4
    var defaultBackdropColor = UIColor(red: 4.0 / 255, green: 7.0 / 255, blue: 13.0 / 255, alpha: 0.0)

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: LocalUIConstants.dragIndicatorCornerRadius)
            .fill(.gray)
            .frame(width: LocalUIConstants.dragIndicatorWidth, height: LocalUIConstants.dragIndicatorHeight)
            .onTapGesture {
                isShowingSheet.toggle()
            }
    }

    var body: some View {
        ZStack {
            if shouldBlurBackground {
                BackdropView()
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: currentBlurRadius)
                    .allowsHitTesting(true)
                    .onTapGesture {
                        dismiss()
                    }
            }

            VStack {
                Spacer()

                VStack {
                    dragIndicator
                        .padding()

                    content()
                        .padding(.bottom, avoidBottomPadding ? nil : LocalUIConstants.contentBottomPadding)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: maxHeight)
                .background(backgroundColor)
                .independentCornersRadius(sheetCornerRadius, corners: [.topLeft, .topRight])
                .shadow(radius: 20)
                .getGeometry { geometryProxy in
                    sheetHeight = geometryProxy.frame(in: .global).height
                }
                .transformPreference(AdaptiveSheetHeightPreferenceKey.self) {
                    $0 = sheetHeight
                }
                .offset(y: offsetY)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { gesture in
                            if gesture.translation.width < 50 &&
                                gesture.translation.height > 0 {
                                // Default values: 0.15, 0.86, 0.25
                                withAnimation(.interactiveSpring(response: 0.15,
                                                                 dampingFraction: 0.86,
                                                                 blendDuration: 0.1)) {
                                    offsetY = gesture.translation.height
                                }
                            }
                        }
                        .onEnded { _ in
                            if abs(offsetY) > (sheetHeight * LocalUIConstants.dismissDragOffsetPercent / 100.0) {
                                dismiss()
                            } else {
                                withAnimation(.interactiveSpring(response: 0.15,
                                                                 dampingFraction: 0.86,
                                                                 blendDuration: 0.1)) {
                                    offsetY = .zero
                                }
                            }
                        }
                )
                .onAppear {
                    offsetY = sheetHeight
                    DispatchQueue.main.asyncAfter(deadline: .now() + LocalUIConstants.appearAnimationDelay) {
                        withAnimation(.easeInOut(duration: LocalUIConstants.appearAnimationDuration)) {
                            offsetY = .zero
                        }
                    }
                }
                .onChange(of: shouldDismissSheet) { value in
                    if value == true {
                        dismiss()
                    }
                }
            }
            .ignoresSafeArea()
        }
        .background(Color(uiColor: defaultBackdropColor.withAlphaComponent(currentBackdropOpacity)))
    }

    private func dismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + LocalUIConstants.dismissAnimationDelay) {
            withAnimation(.easeInOut(duration: LocalUIConstants.dismissAnimationDuration)) {
                offsetY = sheetHeight
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + LocalUIConstants.dismissAnimationDelay +
                                      LocalUIConstants.dismissAnimationDuration) {
            let _ = Log.ui.debug("AdaptiveSheet dismissed")

            isShowingSheet = false
            shouldDismissSheet = false
            onDismiss?()
        }
    }
}

// MARK: - AdaptiveSheet_Previews
struct AdaptiveSheet_Previews: PreviewProvider {
    static var previews: some View {
        AdaptiveSheet(isShowingSheet: .constant(true),
                      shouldDismissSheet: .constant(false),
                      onDismiss: nil) {
            VStack {
                Text("Just an example sheet")
                    .font(.brandBody)
                    .fontWeight(.semibold)

                Text("With some text")
                    .font(.brandBody)
                    .padding()
            }
            .padding([.top, .bottom], 35)

            Button {
            } label: {
                Text("Dismiss")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}


// MARK: - BackdropView
struct BackdropView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        let blur = UIBlurEffect(style: .extraLight)
        let animator = UIViewPropertyAnimator()
        animator.addAnimations { view.effect = blur }
        animator.fractionComplete = 0
        animator.stopAnimation(true)
        animator.finishAnimation(at: .start)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}


// MARK: - GeometryGetter
struct GeometryGetter: View {
    private let useGeometry: (GeometryProxy) -> Void
    init(_ useGeometry: @escaping (GeometryProxy) -> Void) {
        self.useGeometry = useGeometry
    }

    var body: some View {
        GeometryReader { proxy in
            Color.clear.onAppear {
                useGeometry(proxy)
            }
        }
    }
}

extension View {
    func getGeometry(_ useGeometry: @escaping (GeometryProxy) -> Void) -> some View {
        background(
            GeometryGetter(useGeometry)
        )
    }
}