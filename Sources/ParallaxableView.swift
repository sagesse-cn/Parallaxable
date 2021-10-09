//
//  ParallaxableView.swift
//  Parallaxable
//
//  Created by SAGESSE on 2020/12/30.
//

import UIKit
import SwiftUI


/// A container that split the data arranged into mut page, optionally providing the ability
/// to custom navigation bar/fold content/pinned footer.
///
/// In its simplest form, a parallaxable view creates its contents statically, as shown in the following example:
/// ```
/// var body: some View {
///     ParallaxableView {
///         Text("A Page")
///         Text("A Second Page")
///         Text("A Third Page")
///     }
/// }
/// ```
public struct ParallaxableView: View {

    /// Creates a parallaxable view with the given page content that supports selecting.
    ///
    /// - Parameters:
    ///   - selection: A binding to that identifies selected index.
    ///   - content: The page content of the parallaxable view.
    public init(selection: Binding<Int>? = nil, @ParallaxableBuilder content: () -> ParallaxableContent) {
        self.content = content()
        self.selection = selection
    }

    /// The content of parallaxable view.
    public var body: some View {
        _XCParallaxableViewContainer(content: content, selection: selection, configuration: configuration)
            .transformPreference(_XCParallaxableViewConfiguration.self) {
                $0.append(configuration)
            }
            .onPreferenceChange(_XCParallaxableViewProxy.self) {
                $0.forEach {
                    if $0.configuration == nil {
                        $0.configuration = configuration
                    }
                }
            }
    }

    private let content: ParallaxableContent
    private let selection: Binding<Int>?
    private let configuration: _XCParallaxableViewConfiguration = .init()
}

public extension ParallaxableView {
    
    /// Clips this view and content view to bar/scrollable bounding rectangular frame.
    ///
    /// Use the `clipped(antialiased:)` modifier to hide any content that
    /// extends beyond the layout bounds of the shape.
    ///
    /// By default, a view's bounding frame is used only for layout, so any
    /// content that extends beyond the edges of the frame is still visible.
    ///
    /// - Parameter antialiased: A Boolean value that indicates whether the
    ///   rendering system applies smoothing to the edges of the clipping
    ///   rectangle.
    func parallaxableClipped(antialiased: Bool = false) -> Self {
        _parallaxableConfiguration {
            $0.isClipped = true
            $0.isAntialiased = antialiased
        }
    }
    
    /// Adds an action to perform when the parallaxable view value changes.
    ///
    /// - Parameter action: The action to perform when this parallaxable view value
    ///   changes. The `action` closure's parameter contains the parallaxable view new
    ///   value.
    func onParallaxableChanged(action: @escaping (CGPoint) -> Void) -> Self {
        _parallaxableConfiguration {
            $0.contentOffsetObservers.append(action)
        }
    }

    /// Layers the given views behind navigation bar.
    func parallaxableHeader<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.headerView)
    }
    /// Layers the given foldable views.
    func parallaxableContent<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.contentView)
    }
    /// Layers the given pinned views.
    func parallaxableFooter<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.footerView)
    }

    /// Layers the given views before parallaxable.
    func parallaxableOverlay<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.overlayView)
    }
    /// Layers the given views behind parallaxable.
    func parallaxableBackground<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.backgroundView)
    }

    
    func parallaxableHeader<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableHeader(view())
    }

    func parallaxableContent<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableContent(view())
    }
    func parallaxableFooter<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableFooter(view())
    }

    func parallaxableOverlay<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableOverlay(view())
    }
    func parallaxableBackground<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableBackground(view())
    }

    /// Configures a custom SwiftUI.View to the specified key path.
    private func _parallaxableCustomView<T: View>(_ view: T, for keyPath: ReferenceWritableKeyPath<_XCParallaxableViewCoordinator, UIView?>) -> Self {
        _parallaxableConfiguration {
            $0.handlers[keyPath] = {
                $0.setWrapperView(view, for: keyPath)
            }
        }
    }
    private func _parallaxableConfiguration(block: ( _XCParallaxableViewConfiguration) -> ())  -> Self {
        block(configuration)
        return self
    }
}


// MARK: -


/// A proxy value that supports programmatic scrolling of the scrollable
/// views within a view hierarchy.
///
/// You don't create instances of ``ParallaxableViewProxy`` directly. Instead, your
/// ``ParallaxableViewReader`` receives an instance of ``ParallaxableViewProxy`` in its
/// `content` view builder. You use actions within this view builder, such
/// as button and gesture handlers or the ``ParallaxableView/onParallaxableChanged(action:)``
/// method, to call the proxy's ``ParallaxableViewProxy/scrollTo(_:anchor:)`` method.
public struct ParallaxableViewProxy {
    
    /// The size of the parallaxable view presentation content.
    public var contentSize: CGSize {
        forwarding.contentSize
    }
    
    public var contentOffset: CGPoint {
        get { forwarding.contentOffset }
        nonmutating set { forwarding.contentOffset = newValue }
    }
    
    public func setContentOffset(_ newContentOffset: CGPoint, animated: Bool) {
        forwarding.setContentOffset(newContentOffset, animated: animated)
    }
    
    fileprivate var forwarding: _XCParallaxableViewProxy = .init()
}

/// A view that provides programmatic scrolling, by working with a proxy
/// to scroll to known child views.
///
/// The scroll view reader's content view builder receives a ``ParallaxableViewProxy``
/// instance; you use the proxy's ``ParallaxableViewProxy/scrollTo(_:anchor:)`` to
/// perform scrolling.
///
/// The following example creates a ``ParallaxableView`` containing 100 views that
/// together display a color gradient. It also contains two buttons, one each
/// at the top and bottom. The top button tells the ``ParallaxableViewProxy`` to
/// scroll to the bottom button, and vice versa.
///
///     var body: some View {
///         ParallaxableViewReader { proxy in
///             ParallaxableView {
///                 ScrollView {
///                     VStack(spacing: 0) {
///                         ForEach(0..<100) { i in
///                             color(fraction: Double(i) / 100)
///                                 .frame(height: 32)
///                         }
///                     }
///                 }
///                 .overlay(Button("Move to down") {
///                     withAnimation {
///                         proxy.contentOffset.y += 10
///                     }
///                 })
///             }
///         }
///     }
///
///     func color(fraction: Double) -> Color {
///         Color(red: fraction, green: 1 - fraction, blue: 0.5)
///     }
///
/// > Important: You may not use the ``ParallaxableViewProxy``
/// during execution of the `content` view builder; doing so results in a
/// runtime error. Instead, only actions created within `content` can call
/// the proxy, such as gesture handlers or a view's `onChange(of:perform:)`
/// method.
public struct ParallaxableViewReader<Content: View>: View {
    
    /// The view builder that creates the reader's content.
    public var content: (ParallaxableViewProxy) -> Content

    /// Creates an instance that can perform programmatic scrolling of its
    /// child scroll views.
    ///
    /// - Parameter content: The reader's content, containing one or more
    /// scroll views. This view builder receives a ``ParallaxableViewProxy``
    /// instance that you use to perform scrolling.
    public init(@ViewBuilder content: @escaping (ParallaxableViewProxy) -> Content) {
        self.content = content
    }
    
    /// The content and behavior of the view.
    public var body: some View {
        content(proxy)
            .transformPreference(_XCParallaxableViewProxy.self) {
                $0.append(proxy.forwarding)
            }
            .onPreferenceChange(_XCParallaxableViewConfiguration.self) {
                proxy.forwarding.configuration = $0.last
            }
    }
    
    private var proxy: ParallaxableViewProxy = .init()
}


// MARK: -


public struct ParallaxableContent: View {
    
    public var body: Never {
        fatalError("body has not been implemented")
    }
    
    public init<T: View>(_ view: T) {
        self.init([view])
    }
    public init<T: View>(_ views: [T]) {
        self.builders = views.flatMap { view in
            return (view as? Self)?.builders ?? [{
                return $0.dequeueReusableHostingController(view)
            }]
        }
    }
    public init(_ views: Self...) {
        self.builders = views.flatMap(\.builders)
    }
    
    fileprivate func build(_ coordinator: _XCParallaxableViewCoordinator) -> [UIViewController] {
        return builders.map {
            return $0(coordinator)
        }
    }
    
    private let builders: [(_XCParallaxableViewCoordinator) -> UIViewController]
}


// MARK: -


/// [@resultBuilder](https://github.com/apple/swift-evolution/blob/main/proposals/0289-result-builders.md)
@resultBuilder
public struct ParallaxableBuilder {

    
    public static func buildBlock() -> ParallaxableContent {
        .init()
    }
    public static func buildBlock<C0: View>(_ c0: C0) -> ParallaxableContent {
        .init(.init(c0))
    }
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> ParallaxableContent {
        .init(.init(c0), .init(c1))
    }
    public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5), .init(c6))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5), .init(c6), .init(c7))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5), .init(c6), .init(c7), .init(c8))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5), .init(c6), .init(c7), .init(c8), .init(c9))
    }

    /// Enables support for `if` statements that do not have an `else`.
    public static func buildOptional<C: View>(_ content: C?) -> C? {
        content // ignore, content is ParallaxableContent already.
    }

    /// With buildEither(first:), enables support for 'if-else' and 'switch'
    /// statements by folding conditional results into a single result.
    public static func buildEither<C: View>(first view: C) -> ParallaxableContent {
        .init(view)
    }
    /// With buildEither(second:), enables support for 'if-else' and 'switch'
    /// statements by folding conditional results into a single result.
    public static func buildEither<C: View>(second view: C) -> ParallaxableContent {
        .init(view)
    }
    
    /// Enables support for 'for..in' loops by combining the
    /// results of all iterations into a single result.
    public static func buildArray<C: View>(_ views: [C]) -> ParallaxableContent {
        .init(views)
    }
}


// MARK: -


fileprivate class _XCParallaxableViewProxy: NSObject, PreferenceKey {
    
    static var defaultValue: [_XCParallaxableViewProxy] = []
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
    
    var contentSize: CGSize {
        parallaxableController?.contentSize ?? .zero
    }
    
    var contentOffset: CGPoint {
        get { parallaxableController?.contentOffset ?? .zero }
        set { parallaxableController?.contentOffset = newValue }
    }
    
    func setContentOffset(_ newContentOffset: CGPoint, animated: Bool) {
        parallaxableController?.setContentOffset(newContentOffset, animated: animated)
    }

    var parallaxableController: XCParallaxableController? {
        return configuration?.coordinator?.parallaxableController
    }

    weak var configuration: _XCParallaxableViewConfiguration?
}

fileprivate class _XCParallaxableViewConfiguration: NSObject, PreferenceKey {

    static var defaultValue: [_XCParallaxableViewConfiguration] = []
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }

    var isClipped: Bool = false
    var isAntialiased: Bool = false
    
    var handlers: [AnyKeyPath: (_XCParallaxableViewCoordinator) -> ()] = [:]
    
    var contentOffsetObservers: [(CGPoint) -> ()] = []
    
    weak var coordinator: _XCParallaxableViewCoordinator?
}


// MARK: -


/// Maybe let ``ParallaxableView`` conforms to ``UIViewControllerRepresentable`` protocol is better,
/// But we don't want to public internal details.
fileprivate struct _XCParallaxableViewContainer: UIViewControllerRepresentable {
    
    /// The all pages content.
    let content: ParallaxableContent
    /// The selected page index.
    let selection: Binding<Int>?
    /// The contianer configuration.
    let configuration: _XCParallaxableViewConfiguration

    /// Build a new coordinator in first rendered.
    func makeCoordinator() -> _XCParallaxableViewCoordinator {
        return .init()
    }

    /// Using shared parallaxable controller.
    func makeUIViewController(context: Context) -> XCParallaxableController {
        return context.coordinator.parallaxableController
    }

    /// Update all pages content in to coordinator of the current context.
    func updateUIViewController(_ viewController: UIViewControllerType, context: Context) {
        context.coordinator.apply(configuration)
        context.coordinator.setContentView(content)
        context.coordinator.setContentSection(selection, animated: !context.transaction.disablesAnimations)
    }
}


// MARK: -


/// SwiftUI will retain and manages an coordinator, when a view is rendered, coordinator are reusable.
@dynamicMemberLookup
fileprivate class _XCParallaxableViewCoordinator: XCParallaxableControllerDelegate {
    
    /// The context shared parallaxable controller.
    let parallaxableController: XCParallaxableController
    
        
    var overlayView: UIView?

    var backgroundView: UIView? {
        willSet {
            guard newValue !== backgroundView else {
                return
            }
            backgroundView.map {
                $0.removeFromSuperview()
            }
            newValue.map {
                let parallaxingView = parallaxableController.parallaxingView
                $0.contentMode = .redraw
                parallaxingView.insertSubview($0, at: 0)
                let topConstraint = $0.topAnchor.constraint(equalTo: parallaxingView.topAnchor)
                topConstraint.priority = .defaultHigh
                NSLayoutConstraint.activate([
                    topConstraint,
                    $0.leftAnchor.constraint(equalTo: parallaxingView.leftAnchor),
                    $0.rightAnchor.constraint(equalTo: parallaxingView.rightAnchor),
                    $0.bottomAnchor.constraint(equalTo: parallaxingView.bottomAnchor),
                ])
            }
        }
    }
    

    /// Update the all pages content to shared parallaxable controller.
    func setContentView(_ pages: ParallaxableContent) {
        // Add the current view controllers to the reuse queue, this is a big performance boost.
        reusableHostingControllers = parallaxableController.viewControllers
        
        // The builder will call `dequeueReusableHostingController<T>(_ view: T) -> UIViewController` to a hosting controller,
        // It will reuse the old hosting controller as much as possible.
        parallaxableController.viewControllers = pages.build(self)
        
        // Remove all unused view controllers.
        reusableHostingControllers = nil
    }
    
    func setContentSection(_ selection: Binding<Int>?, animated: Bool) {
        // Prepare the callback context.
        selectedIndexObserver = selection
        // Synchronize the selected index of the selection.
        let newSelectedIndex = selection?.wrappedValue ?? 0
        guard newSelectedIndex != parallaxableController.selectedIndex else {
            return
        }
        parallaxableController.setSelectedIndex(newSelectedIndex, animated: animated)
    }
        
    /// Update new view for parallaxing view.
    func setWrapperView<T: View>(_ view: T, for keyPath: ReferenceWritableKeyPath<_XCParallaxableViewCoordinator, UIView?>) {
        // For `EmptyView` we not need to create a wrapper view.
        if view is EmptyView {
            self[keyPath: keyPath] = nil
            return
        }
        // Try to reuse wrapper view for new content.
        if let wrapper = self[keyPath: keyPath] as? _XCParallaxableHostingWrapperView<T> {
            wrapper.replace(view)
            return
        }
        self[keyPath: keyPath] = _XCParallaxableHostingWrapperView(rootView: view, in: parallaxableController)
    }
    
    func apply(_ configuration: _XCParallaxableViewConfiguration) {
        // Apply configuration to parallaxable controller.
        contentOffsetObservers = configuration.contentOffsetObservers
        parallaxableController.isClipped = configuration.isClipped
        
        // Apply `SwiftUI.View` changes in to subview.
        configuration.coordinator = self
        configuration.handlers.values.forEach {
            $0(self)
        }
        
        // Make sure the backgroundView/overlayView in the right view hierarchy.
        backgroundView.map(self.parallaxingView.sendSubviewToBack)
        overlayView.map(self.parallaxingView.bringSubviewToFront)
    }
    
    ///
    func dequeueReusableHostingController<T>(_ view: T) -> UIViewController where T: View {
        // Get the first reusable host controller of the compatible this content in the reuse queue.
        guard let index = reusableHostingControllers?.firstIndex(where: { $0 is UIHostingController<T> }) else {
            // Unable to find a reusable hosting controller in the reuse queue.
            return UIHostingController(rootView: view)
        }
        // Once a reusable hosting controller is found, remove it from the reuse queue.
        guard let controller = reusableHostingControllers?.remove(at: index) as? UIHostingController<T> else {
            // This is something that should never happen, but if happen create a new hosting controller.
            return UIHostingController(rootView: view)
        }
        // Replace the root view with content.
        controller.rootView = view
        return controller
    }
    
    /// Forward getter to the parallaxable controller.
    subscript<Value>(dynamicMember keyPath: KeyPath<XCParallaxableController, Value>) -> Value {
        get { parallaxableController[keyPath: keyPath] }
    }
    /// Forward setter/getter to the parallaxable controller.
    subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<XCParallaxableController, Value>) -> Value {
        get { parallaxableController[keyPath: keyPath] }
        set { parallaxableController[keyPath: keyPath] = newValue }
    }
    
    func parallaxableController(_ parallaxableController: XCParallaxableController, didSelectItemAt index: Int) {
        // Notifiy selection the selected index is changes.
        guard let selection = selectedIndexObserver, selection.wrappedValue != index else {
            return
        }
        selection.wrappedValue = index
    }
    
    func parallaxableController(_ parallaxableController: XCParallaxableController, didChangeContentOffset contentOffset: CGPoint) {
        // Notifiy observers the content offset is changes.
        contentOffsetObservers.forEach {
            $0(contentOffset)
        }
    }
    
    init() {
        self.parallaxableController = .init()
        self.parallaxableController.delegate = self
    }
    
    private var reusableHostingControllers: [UIViewController]?
    
    private var contentOffsetObservers: [(CGPoint) -> ()] = []
    private var selectedIndexObserver: Binding<Int>?
}


// MARK: -


/// An hosting wrapper view.
///
/// The hosting views content and heights should changes frequently, direct using hosting view is a bad idea.
fileprivate class _XCParallaxableHostingWrapperView<Content: View>: UIView {
    
    
    required init(rootView: Content, in viewController: UIViewController) {
        super.init(frame: .zero)
        
        // Build all hosting view height constraints.
        self.translatesAutoresizingMaskIntoConstraints = false
        self.viewController = viewController
        self.hostingViewHeight = (
            heightAnchor.constraint(lessThanOrEqualToConstant: 0),
            heightAnchor.constraint(equalToConstant: 0),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        )

        // Replace hosting view with the specified content.
        self.replace(rootView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        hostingView?.performWithoutContentChangesIfNeeded {
            updateHeightConstraintsIfNeeded()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return hostingViewSize ?? super.intrinsicContentSize
    }
    
    
    /// Replace hosting view with the specified content.
    func replace(_ content: Content)  {
        // Clean invaild hosting view.
        hostingView?.removeFromSuperview()
        
        // If `_UIHostingView` supports repleace we can using reusable version.
        let newValue = _XCParallaxableHostingView(rootView: content)
        newValue.frame = bounds
        newValue.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(newValue)
        hostingView = newValue
    }
    
    func updateHeightConstraintsIfNeeded() {
        // Update the constraints of the current view when the estimated size changes.
        guard let (minHeight, maxHeight, height) = estimatedSize(), hostingEstimatedSize?.0 != minHeight || hostingEstimatedSize?.1 != maxHeight else {
            return
        }
        hostingEstimatedSize = (minHeight, maxHeight)
        
        // The final hosting view height consists on multiple (le, eq, ge) height constraints.
        hostingViewHeight.map {
            // The equalTo(eq) constraint is calculate from the minSize and maxSize.
            $0.le.constant = maxHeight
            $0.eq.constant = height
            $0.ge.constant = minHeight
            // The equalTo(eq) constraint is activate only when the hosting view explicitly specified a size.
            $0.le.isActive = true
            $0.eq.isActive = minHeight == maxHeight
            $0.ge.isActive = true
        }
        //print("\(Content.self).\(#function) => \(minHeight) - \(height) - \(maxHeight)")
        
        // When the equalTo(eq) constraint is not active, the constraint engine requrired evaluates
        // the final size based on the content size.
        hostingViewSize = CGSize(width: UIView.noIntrinsicMetric, height: height)
        super.invalidateIntrinsicContentSize()
    }
    
    
    private func estimatedSize() -> (CGFloat, CGFloat, CGFloat)? {
        // There is no need to estimate the size when the view is not ready.
        guard let hostingView = hostingView, let width = viewController?.viewIfLoaded?.bounds.width ?? window?.bounds.width else {
            return nil
        }
        var height = CGFloat(0)
        
        // Calculate the min size of the hosting view content.
        let compressedSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let minHeight = pixelate(hostingView.sizeThatFits(compressedSize).height)
        if minHeight != compressedSize.height {
            height = max(minHeight, height)
        }

        // Calculate the max size of the hosting view content.
        let expandedSize = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        let maxHeight = pixelate(hostingView.sizeThatFits(expandedSize).height)
        if maxHeight != expandedSize.height {
            height = max(maxHeight, height)
        }

        return (minHeight, maxHeight, height)
    }

    private func pixelate(_ value: CGFloat) -> CGFloat {
        return trunc(value * 10) / 10
    }
    
        
    private var hostingView: _XCParallaxableHostingView<Content>?
    private var hostingViewSize: CGSize?
    private var hostingViewHeight: (le: NSLayoutConstraint, eq: NSLayoutConstraint, ge: NSLayoutConstraint)?
    private var hostingEstimatedSize: (CGFloat, CGFloat)?

    private weak var viewController: UIViewController?
}


// MARK: -


/// An `_UIHostingView` compatible view.
///
/// It is not recommended to use `_UIHostingView` directly.
/// Once Apple removed `_UIHostingView`, we should replace implementation with `UIHostingController`.
fileprivate class _XCParallaxableHostingView<Content: View>: _UIHostingView<Content> {
    
     func performWithoutContentChangesIfNeeded(_ actions: () -> Void) {
        let oldValue = isLockedConentChanges
        isLockedConentChanges = true
        actions()
        isLockedConentChanges = oldValue
    }

    override func setNeedsLayout() {
        super.setNeedsLayout()
        guard !isLockedConentChanges, superview?.contentMode != .redraw else {
            return
        }
        superview?.setNeedsUpdateConstraints()
    }
    
    private var isLockedConentChanges: Bool = false
}
