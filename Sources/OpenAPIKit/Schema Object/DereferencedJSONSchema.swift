//
//  DereferencedJSONSchema.swift
//  
//
//  Created by Mathew Polzin on 6/17/20.
//

/// A `JSONSchema` type that guarantees none of its
/// nodes are references.
@dynamicMemberLookup
public enum DereferencedJSONSchema: Equatable, JSONSchemaContext {
    public typealias CoreContext<Format: OpenAPIFormat> = JSONSchema.CoreContext<Format>
    public typealias NumericContext = JSONSchema.NumericContext
    public typealias IntegerContext = JSONSchema.IntegerContext
    public typealias StringContext = JSONSchema.StringContext

    case boolean(CoreContext<JSONTypeFormat.BooleanFormat>)
    indirect case object(CoreContext<JSONTypeFormat.ObjectFormat>, ObjectContext)
    indirect case array(CoreContext<JSONTypeFormat.ArrayFormat>, ArrayContext)
    case number(CoreContext<JSONTypeFormat.NumberFormat>, NumericContext)
    case integer(CoreContext<JSONTypeFormat.IntegerFormat>, IntegerContext)
    case string(CoreContext<JSONTypeFormat.StringFormat>, StringContext)
    indirect case one(of: [DereferencedJSONSchema], discriminator: OpenAPI.Discriminator?)
    indirect case any(of: [DereferencedJSONSchema], discriminator: OpenAPI.Discriminator?)
    indirect case not(DereferencedJSONSchema)
    /// This schema does not have a `type` specified. This is allowed
    /// but does not offer much in the way of documenting the schema
    /// so it is represented here as "undefined" with an optional
    /// description.
    case fragment(CoreContext<JSONTypeFormat.AnyFormat>) // This is the "{}" case where not even a type constraint is given.

    /// Get the JSONSchema representation of this
    /// dereferenced schema.
    ///
    /// This will not necessarily be the same schema that
    /// was used to create this dereferenced schema if
    /// there was one.
    ///
    /// It is always possible to represent a
    /// `DereferencedJSONSchema` as a
    /// `JSONSchema`, although the reverse is
    /// not true.
    public var jsonSchema: JSONSchema {
        switch self {
        case .boolean(let context):
            return .boolean(context)
        case .object(let coreContext, let objectContext):
            return .object(coreContext, objectContext.jsonSchemaObjectContext)
        case .array(let coreContext, let arrayContext):
            return .array(coreContext, arrayContext.jsonSchemaArrayContext)
        case .number(let coreContext, let numberContext):
            return .number(coreContext, numberContext)
        case .integer(let coreContext, let integerContext):
            return .integer(coreContext, integerContext)
        case .string(let coreContext, let stringContext):
            return .string(coreContext, stringContext)
        case .one(of: let schemas, discriminator: let discriminator):
            return .one(of: schemas.map { $0.jsonSchema }, discriminator: discriminator)
        case .any(of: let schemas, discriminator: let discriminator):
            return .any(of: schemas.map { $0.jsonSchema }, discriminator: discriminator)
        case .not(let schema):
            return .not(schema.jsonSchema)
        case .fragment(let context):
            return .fragment(context)
        }
    }

    // automatic forwarding where possible
    public subscript<T>(dynamicMember path: KeyPath<JSONSchema, T>) -> T {
        return jsonSchema[keyPath: path]
    }

    // See `JSONSchemaContext`
    public var formatString: String? { jsonSchema.formatString }

    // See `JSONSchemaContext`
    public var required: Bool { jsonSchema.required }

    // See `JSONSchemaContext`
    public var nullable: Bool { jsonSchema.nullable }

    // See `JSONSchemaContext`
    public var title: String? { jsonSchema.title }

    // See `JSONSchemaContext`
    public var description: String? { jsonSchema.description }

    // See `JSONSchemaContext`
    public var discriminator: OpenAPI.Discriminator? { jsonSchema.discriminator }

    // See `JSONSchemaContext`
    public var externalDocs: OpenAPI.ExternalDocumentation? { jsonSchema.externalDocs }

    // See `JSONSchemaContext`
    public var allowedValues: [AnyCodable]? { jsonSchema.allowedValues }

    // See `JSONSchemaContext`
    public var example: AnyCodable? { jsonSchema.example }

    // See `JSONSchemaContext`
    public var readOnly: Bool { jsonSchema.readOnly }

    // See `JSONSchemaContext`
    public var writeOnly: Bool { jsonSchema.writeOnly }

    // See `JSONSchemaContext`
    public var deprecated: Bool { jsonSchema.deprecated }

    /// Returns a version of this `JSONSchema` that has the given discriminator.
    public func with(discriminator: OpenAPI.Discriminator) -> DereferencedJSONSchema {
        switch self {
        case .boolean(let context):
            return .boolean(context.with(discriminator: discriminator))
        case .object(let contextA, let contextB):
            return .object(contextA.with(discriminator: discriminator), contextB)
        case .array(let contextA, let contextB):
            return .array(contextA.with(discriminator: discriminator), contextB)
        case .number(let context, let contextB):
            return .number(context.with(discriminator: discriminator), contextB)
        case .integer(let context, let contextB):
            return .integer(context.with(discriminator: discriminator), contextB)
        case .string(let context, let contextB):
            return .string(context.with(discriminator: discriminator), contextB)
        case .one(of: let schemas, discriminator: _):
            return .one(of: schemas, discriminator: discriminator)
        case .any(of: let schemas, discriminator: _):
            return .any(of: schemas, discriminator: discriminator)
        case .fragment(let context):
            return .fragment(context.with(discriminator: discriminator))
        case .not:
            return self
        }
    }
}

extension DereferencedJSONSchema {
    /// Get the context specific to an `object` schema. If not an
    /// object schema, returns `nil`.
    public var objectContext: ObjectContext? {
        guard case .object(_, let context) = self else {
            return nil
        }
        return context
    }

    /// Get the context specific to an `array` schema. If not an
    /// array schema, returns `nil`.
    public var arrayContext: ArrayContext? {
        guard case .array(_, let context) = self else {
            return nil
        }
        return context
    }

    /// The context that only applies to `.array` schemas.
    public struct ArrayContext: Equatable {
        /// A JSON Type Node that describes
        /// the type of each element in the array.
        public let items: DereferencedJSONSchema?

        /// Maximum number of items in array.
        public let maxItems: Int?

        let _minItems: Int?
        /// Minimum number of items in array.
        /// Defaults to 0.
        public var minItems: Int { _minItems ?? 0 }

        let _uniqueItems: Bool?
        /// Setting to true indicates all
        /// elements of the array are expected
        /// to be unique. Defaults to false.
        public var uniqueItems: Bool { _uniqueItems ?? false }

        public init?(_ arrayContext: JSONSchema.ArrayContext) {
            if let otherItems = arrayContext.items {
                guard let dereferencedOtherItems = otherItems.dereferenced() else {
                    return nil
                }
                items = dereferencedOtherItems
            } else {
                items = nil
            }

            maxItems = arrayContext.maxItems
            _minItems = arrayContext._minItems
            _uniqueItems = arrayContext._uniqueItems
        }

        internal init(_ arrayContext: JSONSchema.ArrayContext, resolvingIn components: OpenAPI.Components) throws {
            items = try arrayContext.items.map { try $0.dereferenced(in: components) }
            maxItems = arrayContext.maxItems
            _minItems = arrayContext._minItems
            _uniqueItems = arrayContext._uniqueItems
        }

        internal var jsonSchemaArrayContext: JSONSchema.ArrayContext {
            .init(
                items: items.map { $0.jsonSchema },
                maxItems: maxItems,
                minItems: _minItems,
                uniqueItems: _uniqueItems
            )
        }
    }

    /// The context that only applies to `.object` schemas.
    public struct ObjectContext: Equatable {
        public let maxProperties: Int?
        let _minProperties: Int?
        public let properties: [String: DereferencedJSONSchema]
        public let additionalProperties: Either<Bool, DereferencedJSONSchema>?

        // NOTE that an object's required properties
        // array is determined by looking at its properties'
        // required Bool.
        public var requiredProperties: [String] {
            return Array(properties.filter { (_, schemaObject) in
                schemaObject.required
            }.keys)
        }

        public var optionalProperties: [String] {
            return Array(properties.filter { (_, schemaObject) in
                !schemaObject.required
            }.keys)
        }

        /// The minimum number of properties allowed.
        ///
        /// This might constradict a value explicitly specified on initialization
        /// or when decoding if the number of required properties is greater
        /// than the explicitly set minimum.
        public var minProperties: Int {
            return max(_minProperties ?? 0, requiredProperties.count)
        }

        public init?(_ objectContext: JSONSchema.ObjectContext) {

            var otherProperties = [String: DereferencedJSONSchema]()
            for (name, property) in objectContext.properties {
                guard let dereferencedProperty = property.dereferenced() else {
                    return nil
                }
                otherProperties[name] = dereferencedProperty
            }

            properties = otherProperties
            maxProperties = objectContext.maxProperties
            _minProperties = objectContext._minProperties
            switch objectContext.additionalProperties {
            case .a(let bool):
                additionalProperties = .a(bool)
            case .b(let schema):
                guard let schema = schema.dereferenced() else {
                    return nil
                }
                additionalProperties = .b(schema)
            case nil:
                additionalProperties = nil
            }
        }

        internal init(_ objectContext: JSONSchema.ObjectContext, resolvingIn components: OpenAPI.Components) throws {
            properties = try objectContext.properties.mapValues { try $0.dereferenced(in: components) }
            maxProperties = objectContext.maxProperties
            _minProperties = objectContext._minProperties
            switch objectContext.additionalProperties {
            case .a(let bool):
                additionalProperties = .a(bool)
            case .b(let schema):
                additionalProperties = .b(try schema.dereferenced(in: components))
            case nil:
                additionalProperties = nil
            }
        }

        internal var jsonSchemaObjectContext: JSONSchema.ObjectContext {
            let underlyingAdditionalProperties: Either<Bool, JSONSchema>?
            switch additionalProperties {
            case .a(let bool):
                underlyingAdditionalProperties = .a(bool)
            case .b(let schema):
                underlyingAdditionalProperties = .b(schema.jsonSchema)
            case nil:
                underlyingAdditionalProperties = nil
            }

            return .init(
                properties: properties.mapValues { $0.jsonSchema },
                additionalProperties: underlyingAdditionalProperties,
                maxProperties: maxProperties,
                minProperties: _minProperties
            )
        }
    }
}

extension JSONSchema: LocallyDereferenceable {

    /// Returns a dereferenced schema object if all references in
    /// this schema object can be found in the Components Object.
    ///
    /// Dereferencing a `JSONSchema` currently relies on resolving
    /// `all(of:)` schemas (thus removing all `JSONSchemaFragments`).
    /// All fragments are combined into a new schema if possible and an error
    /// is thrown if no valid schema can be created.
    ///
    /// - Important: Local dereferencing will `throw` if any
    ///     `JSONReferences` point to other files or to
    ///     locations within the same file other than the
    ///     Components Object. It will also fail if any components
    ///     are missing from the Components Object.
    ///
    /// - Throws: `ReferenceError.cannotLookupRemoteReference` or
    ///     `ReferenceError.missingOnLookup(name:key:)` depending
    ///     on whether an unresolvable reference points to another file or just points to a
    ///     component in the same file that cannot be found in the Components Object.
    public func dereferenced(in components: OpenAPI.Components) throws -> DereferencedJSONSchema {
        switch self {
        case .reference(let reference):
            return try reference.dereferenced(in: components)
        case .boolean(let context):
            return .boolean(context)
        case .object(let coreContext, let objectContext):
            return try .object(
                coreContext,
                DereferencedJSONSchema.ObjectContext(objectContext, resolvingIn: components)
            )
        case .array(let coreContext, let arrayContext):
            return try .array(
                coreContext,
                DereferencedJSONSchema.ArrayContext(arrayContext, resolvingIn: components)
            )
        case .number(let coreContext, let numberContext):
            return .number(coreContext, numberContext)
        case .integer(let coreContext, let integerContext):
            return .integer(coreContext, integerContext)
        case .string(let coreContext, let stringContext):
            return .string(coreContext, stringContext)
        case .all(of: let fragments, discriminator: let discriminator):
            let resolvedFragments = try fragments.resolved(against: components)
            return discriminator.map { resolvedFragments.with(discriminator: $0) } ?? resolvedFragments
        case .one(of: let jsonSchemas, discriminator: let discriminator):
            let schemas = try jsonSchemas.map { try $0.dereferenced(in: components) }
            return .one(of: schemas, discriminator: discriminator)
        case .any(of: let jsonSchemas, discriminator: let discriminator):
            let schemas = try jsonSchemas.map { try $0.dereferenced(in: components) }
            return .any(of: schemas, discriminator: discriminator)
        case .not(let jsonSchema):
            return .not(try jsonSchema.dereferenced(in: components))
        case .fragment(let context):
            return .fragment(context)
        }
    }

    /// Returns a dereferenced schema object if this schema object
    /// already does not contain any references.
    ///
    /// To create a dereferenced schema object from a schema object
    /// that does have references, use `dereferenced(in:)`.
    ///
    /// - Important: Dereferencing an `all(of:)` schema will
    ///     also attempt to resolve it and fail if it cannot. Resolving
    ///     an `all(of:)` schema involves combining the fragments
    ///     of the `all(of:)` into one schema and failing if no
    ///     valid schema can be created.
    public func dereferenced() -> DereferencedJSONSchema? {
        return try? dereferenced(in: .noComponents)
    }
}