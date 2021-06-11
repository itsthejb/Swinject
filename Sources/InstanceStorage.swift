//
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

/// Storage provided by `ObjectScope`. It is used by `Container` to persist resolved instances.
public protocol InstanceStorage: AnyObject {
    func instance<T>() -> T?
    func graphResolutionCompleted()
    func instance<T>(inGraph graph: GraphIdentifier) -> T?
    func setInstance<T>(_ instance: T, inGraph graph: GraphIdentifier?)
    func resetInstance()
}

extension InstanceStorage {
    public func graphResolutionCompleted() {}
    public func instance<T>(inGraph _: GraphIdentifier) -> T? { return instance() }
    func setInstance<T>(_ instance: T) { setInstance(instance, inGraph: nil) }
}

/// Persists storage during the resolution of the object graph
public final class GraphStorage: InstanceStorage {
    private var instances = [GraphIdentifier: Weak<Any>]()
    private var _instance: Any?

    public init() {}

    public func graphResolutionCompleted() {
        resetInstance()
    }

    public func resetInstance() {
        _instance = nil
    }

    public func instance<T>() -> T? {
        _instance as? T
    }

    public func instance<T>(inGraph graph: GraphIdentifier) -> T? {
        return instances[graph]?.value as? T
    }

    public func setInstance<T>(_ instance: T, inGraph graph: GraphIdentifier?) {
        _instance = instance
        guard let graph = graph else { return }
        if instances[graph] == nil { instances[graph] = Weak() }
        instances[graph]?.value = instance
    }
}

/// Persists stored instance until it is explicitly discarded.
public final class PermanentStorage: InstanceStorage {
    private var _instance: Any?
    public func instance<T>() -> T? { _instance as? T }
    public func setInstance<T>(_ instance: T, inGraph graph: GraphIdentifier?) {
        _instance = instance
    }
    public func resetInstance() { _instance = nil }

    public init() {}
}

/// Does not persist stored instance.
public final class TransientStorage: InstanceStorage {
    public func instance<T>() -> T? { nil }
    public func setInstance<T>(_ instance: T, inGraph graph: GraphIdentifier?) {}
    public func resetInstance() {}
    public init() {}
}

/// Does not persist value types.
/// Persists reference types as long as there are strong references to given instance.
public final class WeakStorage: InstanceStorage {
    private var _instance = Weak<Any>()
    public func instance<T>() -> T? { _instance.value as? T }
    public func setInstance<T>(_ instance: T, inGraph graph: GraphIdentifier?) {
        _instance.value = instance
    }
    public func resetInstance() { _instance.value = nil }

    public init() {}
}

/// Combines the behavior of multiple instance storages.
/// Instance is persisted as long as at least one of the underlying storages is persisting it.
public final class CompositeStorage: InstanceStorage {
    private let components: [InstanceStorage]

    public func instance<T>() -> T? {
        #if swift(>=4.1)
        return components.compactMap { $0.instance() }.first
        #else
        return components.flatMap { $0.instance() }.first
        #endif
    }

    public init(_ components: [InstanceStorage]) {
        self.components = components
    }

    public func graphResolutionCompleted() {
        components.forEach { $0.graphResolutionCompleted() }
    }

    public func setInstance<T>(_ instance: T, inGraph graph: GraphIdentifier?) {
        components.forEach { $0.setInstance(instance, inGraph: graph) }
    }

    public func resetInstance() {
        components.forEach { $0.resetInstance() }
    }

    public func instance(inGraph graph: GraphIdentifier) -> Any? {
        #if swift(>=4.1)
            return components.compactMap { $0.instance(inGraph: graph) }.first
        #else
            return components.flatMap { $0.instance(inGraph: graph) }.first
        #endif
    }
}

private class Weak<Wrapped> {
    private weak var object: AnyObject?

    #if os(Linux)
        var value: Wrapped? {
            get {
                guard let object = object else { return nil }
                return object as? Wrapped
            }
            set { object = newValue.flatMap { $0 as? AnyObject } }
        }

    #else
        var value: Wrapped? {
            get {
                guard let object = object else { return nil }
                return object as? Wrapped
            }
            set { object = newValue as AnyObject? }
        }
    #endif
}
