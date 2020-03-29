import Foundation

extension ShadowEncoder {
    /// Single value container for the CSV shadow encoder.
    struct SingleValueContainer: SingleValueEncodingContainer {
        /// The representation of the encoding process point-in-time.
        private let encoder: ShadowEncoder
        /// The container's target (or level).
        private let focus: Focus
        
        /// Fast initializer that doesn't perform any checks on the coding path (assuming it is valid).
        /// - parameter encoder: The `Encoder` instance in charge of encoding CSV data.
        /// - parameter rowIndex: The CSV row targeted for encoding.
        /// - parameter fieldIndex: The CSV field targeted for encoding.
        init(unsafeEncoder encoder: ShadowEncoder, rowIndex: Int, fieldIndex: Int) {
            self.encoder = encoder
            self.focus = .field(rowIndex, fieldIndex)
        }
        
        /// Creates a single value container only if the passed encoder's coding path is valid.
        /// - parameter encoder: The `Encoder` instance in charge of encoding CSV data.
        init(encoder: ShadowEncoder) throws {
            switch encoder.codingPath.count {
            case 2:
                let key = (row: encoder.codingPath[0], field: encoder.codingPath[1])
                let r = try key.row.intValue ?! CSVEncoder.Error.invalidKey(forRow: key.row, codingPath: encoder.codingPath)
                let f = try encoder.sink.fieldIndex(forKey: key.field, codingPath: encoder.codingPath)
                self.focus = .field(r, f)
            case 1:
                let key = encoder.codingPath[0]
                let r = try key.intValue ?! CSVEncoder.Error.invalidKey(forRow: key, codingPath: encoder.codingPath)
                self.focus = .row(r)
            case 0:
                self.focus = .file
            default:
                throw CSVEncoder.Error.invalidContainerRequest(codingPath: encoder.codingPath)
            }
            self.encoder = encoder
        }
        
        var codingPath: [CodingKey] {
            self.encoder.codingPath
        }
    }
}

extension ShadowEncoder.SingleValueContainer {
    mutating func encode(_ value: String) throws {
        try self.lowlevelEncoding { value }
    }
    
    mutating func encodeNil() throws {
        try self.lowlevelEncoding { String() }
    }
    
    mutating func encode(_ value: Bool) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: Int) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: Int8) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: Int16) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: Int32) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: Int64) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: UInt) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: UInt8) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: UInt16) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: UInt32) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: UInt64) throws {
        try self.lowlevelEncoding { String(value) }
    }
    
    mutating func encode(_ value: Float) throws {
        let strategy = self.encoder.sink.configuration.floatStrategy
        try self.lowlevelEncoding {
            switch strategy {
            case .throw: throw CSVEncoder.Error.invalidFloatingPoint(value, codingPath: self.codingPath)
            case .convert(let positiveInfinity, let negativeInfinity, let nan):
                if value.isNaN {
                    return nan
                } else if value.isInfinite {
                    return (value < 0) ? negativeInfinity : positiveInfinity
                } else { fatalError() }
            }
        }
    }
    
    mutating func encode(_ value: Double) throws {
        let strategy = self.encoder.sink.configuration.floatStrategy
        try self.lowlevelEncoding {
            switch strategy {
            case .throw: throw CSVEncoder.Error.invalidFloatingPoint(value, codingPath: self.codingPath)
            case .convert(let positiveInfinity, let negativeInfinity, let nan):
                if value.isNaN {
                    return nan
                } else if value.isInfinite {
                    return (value < 0) ? negativeInfinity : positiveInfinity
                } else { fatalError() }
            }
        }
    }
    
    mutating func encode<T>(_ value: T) throws where T:Encodable {
        switch value {
        case let date as Date: try self.encode(date)
        case let data as Data: try self.encode(data)
        case let num as Decimal: try self.encode(num)
        case let url as URL: try self.encode(url)
        default: try value.encode(to: self.encoder)
        }
    }
}

internal extension ShadowEncoder.SingleValueContainer {
    /// Encodes a single value of the given type.
    /// - parameter value: The value to encode.
    mutating func encode(_ value: Date) throws {
        switch self.encoder.sink.configuration.dateStrategy {
        case .deferredToDate:
            try value.encode(to: self.encoder)
        case .secondsSince1970:
            try self.encode(value.timeIntervalSince1970)
        case .millisecondsSince1970:
            try self.encode(value.timeIntervalSince1970 * 1_000)
        case .iso8601:
            let string = DateFormatter.iso8601.string(from: value)
            try self.encode(string)
        case .formatted(let formatter):
            let string = formatter.string(from: value)
            try self.encode(string)
        case .custom(let closure):
            try closure(value, self.encoder)
        }
    }

    /// Encodes a single value of the given type.
    /// - parameter value: The value to encode.
    mutating func encode(_ value: Data) throws {
        switch self.encoder.sink.configuration.dataStrategy {
        case .deferredToData:
            try value.encode(to: self.encoder)
        case .base64:
            try self.encode(value.base64EncodedString())
        case .custom(let closure):
            try closure(value, self.encoder)
        }
    }

    /// Encodes a single value of the given type.
    /// - parameter value: The value to encode.
    mutating func encode(_ value: Decimal) throws {
        switch self.encoder.sink.configuration.decimalStrategy {
        case .locale(let locale):
            var number = value
            let string = NSDecimalString(&number, locale)
            try self.encode(string)
        case .custom(let closure):
            try closure(value, self.encoder)
        }
    }

    /// Encodes a single value of the given type.
    /// - parameter value: The value to encode.
    func encode(_ value: URL) throws {
        try self.lowlevelEncoding { value.path }
    }
}

// MARK: -

extension ShadowEncoder.SingleValueContainer {
    /// CSV keyed container focus (i.e. where the container is able to operate on).
    private enum Focus {
        /// The container represents the whole CSV file and each encoding operation outputs a row/record.
        case file
        /// The container represents a CSV row and each encoding operation writes a field.
        case row(Int)
        /// The container represents a CSV field and there can only be one encoding operation.
        case field(Int,Int)
    }
    
    /// Encodes a value by transforming it into a `String` through the closure and then passing it to the sink.
    private func lowlevelEncoding(transform: () throws -> String) throws {
        let sink = self.encoder.sink
        let rowIndex, fieldIndex: Int
        
        switch self.focus {
        case .field(let r, let f):
            (rowIndex, fieldIndex) = (r, f)
        case .row(let r):
            // Values are only allowed to be encoded directly from a single value container in "row level" if the CSV has single column rows.
            guard sink.numExpectedFields == 1 else { throw CSVEncoder.Error.invalidSingleFieldEncoding(codingPath: self.codingPath) }
            (rowIndex, fieldIndex) = (r, 0)
        case .file:
            // Values are only allowed to be encoded directly from a single value container in "file level" if the CSV file has a single row with a single column.
            guard sink.numEncodedRows == 0, sink.numExpectedFields == 1 else { throw CSVEncoder.Error.invalidSingleRowFieldEncoding(codingPath: self.codingPath) }
            (rowIndex, fieldIndex) = (0, 0)
        }
        
        let string = try transform()
        try sink.fieldValue(string, rowIndex, fieldIndex)
    }
}

fileprivate extension CSVEncoder.Error {
    /// Error raised when a coding key representing a row within the CSV file cannot be transformed into an integer value.
    /// - parameter codingPath: The whole coding path, including the invalid row key.
    static func invalidKey(forRow key: CodingKey, codingPath: [CodingKey]) -> CSVError<CSVEncoder> {
        .init(.invalidPath,
              reason: "The coding key identifying a CSV row couldn't be transformed into an integer value.",
              help: "The provided coding key identifying a CSV row must implement `intValue`.",
              userInfo: ["Coding path": codingPath])
    }
    /// Error raised when a single value container is requested on an invalid coding path.
    /// - parameter codingPath: The full chain of containers which generated this error.
    static func invalidContainerRequest(codingPath: [CodingKey]) -> CSVError<CSVEncoder> {
        .init(.invalidPath,
              reason: "CSV doesn't support more than two nested encoding container.",
              help: "Don't ask for a single value encoding container on this coding path.",
              userInfo: ["Coding path": codingPath])
    }
    /// Error raised when a value is encoded from a top-level container, but a nested container is expected.
    static func invalidSingleFieldEncoding(codingPath: [CodingKey]) -> CSVError<CSVEncoder> {
        .init(.invalidPath,
              reason: "A field is being encoded at row level.",
              help: "Get a nested container representing a CSV row.",
              userInfo: ["Coding path": codingPath])
    }
    /// Error raised when a value is encoded from a top-level container, but a nested container is expected.
    static func invalidSingleRowFieldEncoding(codingPath: [CodingKey]) -> CSVError<CSVEncoder> {
        .init(.invalidPath,
              reason: "A field is being encoded at file level.",
              help: "Get a nested container representing the CSV file and then another one representing a CSV row.",
              userInfo: ["Coding path": codingPath])
    }
    /// Error raised when a non-conformant floating-point is being encoded and there is no support.
    static func invalidFloatingPoint<T:BinaryFloatingPoint>(_ value: T, codingPath: [CodingKey]) -> EncodingError {
        .invalidValue(value, .init(
            codingPath: codingPath,
            debugDescription: "The value is a non-conformant floating-point.")
        )
    }
}
