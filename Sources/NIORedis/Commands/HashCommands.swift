import NIO

// MARK: Static Helpers

extension RedisClient {
    @usableFromInline
    static func _mapHashResponse(_ values: [String]) -> [String: String] {
        guard values.count > 0 else { return [:] }

        var result: [String: String] = [:]

        var index = 0
        repeat {
            let field = values[index]
            let value = values[index + 1]
            result[field] = value
            index += 2
        } while (index < values.count)

        return result
    }
}

// MARK: General

extension RedisClient {
    /// Removes the specified fields from a hash.
    ///
    /// See [https://redis.io/commands/hdel](https://redis.io/commands/hdel)
    /// - Parameters:
    ///     - fields: The list of field names that should be removed from the hash.
    ///     - key: The key of the hash to delete from.
    /// - Returns: The number of fields that were deleted.
    @inlinable
    public func hdel(_ fields: [String], from key: String) -> EventLoopFuture<Int> {
        guard fields.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }

        return send(command: "HDEL", with: [key] + fields)
            .mapFromRESP()
    }

    /// Checks if a hash contains the field specified.
    ///
    /// See [https://redis.io/commands/hexists](https://redis.io/commands/hexists)
    /// - Parameters:
    ///     - field: The field name to look for.
    ///     - key: The key of the hash to look within.
    /// - Returns: `true` if the hash contains the field, `false` if either the key or field do not exist.
    @inlinable
    public func hexists(_ field: String, in key: String) -> EventLoopFuture<Bool> {
        return send(command: "HEXISTS", with: [key, field])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Gets the number of fields contained in a hash.
    ///
    /// See [https://redis.io/commands/hlen](https://redis.io/commands/hlen)
    /// - Parameter key: The key of the hash to get field count of.
    /// - Returns: The number of fields in the hash, or `0` if the key doesn't exist.
    @inlinable
    public func hlen(of key: String) -> EventLoopFuture<Int> {
        return send(command: "HLEN", with: [key])
            .mapFromRESP()
    }

    /// Gets the string length of a hash field's value.
    ///
    /// See [https://redis.io/commands/hstrlen](https://redis.io/commands/hstrlen)
    /// - Parameters:
    ///     - field: The field name whose value is being accessed.
    ///     - key: The key of the hash.
    /// - Returns: The string length of the hash field's value, or `0` if the field or hash do not exist.
    @inlinable
    public func hstrlen(of field: String, in key: String) -> EventLoopFuture<Int> {
        return send(command: "HSTRLEN", with: [key, field])
            .mapFromRESP()
    }

    /// Gets all field names in a hash.
    ///
    /// See [https://redis.io/commands/hkeys](https://redis.io/commands/hkeys)
    /// - Parameter key: The key of the hash.
    /// - Returns: A list of field names stored within the hash.
    @inlinable
    public func hkeys(in key: String) -> EventLoopFuture<[String]> {
        return send(command: "HKEYS", with: [key])
            .mapFromRESP()
    }

    /// Gets all values stored in a hash.
    ///
    /// See [https://redis.io/commands/hvals](https://redis.io/commands/hvals)
    /// - Parameter key: The key of the hash.
    /// - Returns: A list of all values stored in a hash.
    @inlinable
    public func hvals(in key: String) -> EventLoopFuture<[RESPValue]> {
        return send(command: "HVALS", with: [key])
            .mapFromRESP()
    }

    /// Incrementally iterates over all fields in a hash.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of found fields and their values.
    @inlinable
    public func hscan(
        _ key: String,
        startingFrom position: Int = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> EventLoopFuture<(Int, [String: String])> {
        return _scan(command: "HSCAN", resultType: [String].self, key, position, count, match)
            .map {
                let values = Self._mapHashResponse($0.1)
                return ($0.0, values)
            }
    }
}

// MARK: Set

extension RedisClient {
    /// Sets a hash field to the value specified.
    /// - Note: If you do not want to overwrite existing values, use `hsetnx(_:field:to:)`.
    ///
    /// See [https://redis.io/commands/hset](https://redis.io/commands/hset)
    /// - Parameters:
    ///     - field: The name of the field in the hash being set.
    ///     - value: The value the hash field should be set to.
    ///     - key: The key that holds the hash.
    /// - Returns: `true` if the hash was created, `false` if it was updated.
    @inlinable
    public func hset(
        _ field: String,
        to value: RESPValueConvertible,
        in key: String
    ) -> EventLoopFuture<Bool> {
        return send(command: "HSET", with: [key, field, value])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Sets a hash field to the value specified only if the field does not currently exist.
    /// - Note: If you do not care about overwriting existing values, use `hset(_:field:to:)`.
    ///
    /// See [https://redis.io/commands/hsetnx](https://redis.io/commands/hsetnx)
    /// - Parameters:
    ///     - field: The name of the field in the hash being set.
    ///     - value: The value the hash field should be set to.
    ///     - key: The key that holds the hash.
    /// - Returns: `true` if the hash was created.
    @inlinable
    public func hsetnx(
        _ field: String,
        to value: RESPValueConvertible,
        in key: String
    ) -> EventLoopFuture<Bool> {
        return send(command: "HSETNX", with: [key, field, value])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Sets the fields in a hash to the respective values provided.
    ///
    /// See [https://redis.io/commands/hmset](https://redis.io/commands/hmset)
    /// - Parameters:
    ///     - fields: The key-value pair of field names and their respective values to set.
    ///     - key: The key that holds the hash.
    /// - Returns: An `EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func hmset(
        _ fields: [String: RESPValueConvertible],
        in key: String
    ) -> EventLoopFuture<Void> {
        assert(fields.count > 0, "At least 1 key-value pair should be specified")

        let args: [RESPValueConvertible] = fields.reduce(into: [], { (result, element) in
            result.append(element.key)
            result.append(element.value)
        })
        
        return send(command: "HMSET", with: [key] + args)
            .map { _ in () }
    }
}

// MARK: Get

extension RedisClient {
    /// Gets a hash field's value.
    ///
    /// See [https://redis.io/commands/hget](https://redis.io/commands/hget)
    /// - Parameters:
    ///     - field: The name of the field whose value is being accessed.
    ///     - key: The key of the hash being accessed.
    /// - Returns: The value of the hash field, or `nil` if either the key or field does not exist.
    @inlinable
    public func hget(_ field: String, from key: String) -> EventLoopFuture<String?> {
        return send(command: "HGET", with: [key, field])
            .map { return String($0) }
    }

    /// Gets the values of a hash for the fields specified.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field names to get values for.
    ///     - key: The key of the hash being accessed.
    /// - Returns: A list of values in the same order as the `fields` argument. Non-existent fields return `nil` values.
    @inlinable
    public func hmget(_ fields: [String], from key: String) -> EventLoopFuture<[String?]> {
        guard fields.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }

        return send(command: "HMGET", with: [key] + fields)
            .mapFromRESP(to: [RESPValue].self)
            .map { return $0.map(String.init) }
    }

    /// Returns all the fields and values stored in a hash.
    ///
    /// See [https://redis.io/commands/hgetall](https://redis.io/commands/hgetall)
    /// - Parameter key: The key of the hash to pull from.
    /// - Returns: A key-value pair list of fields and their values.
    @inlinable
    public func hgetall(from key: String) -> EventLoopFuture<[String: String]> {
        return send(command: "HGETALL", with: [key])
            .mapFromRESP(to: [String].self)
            .map(Self._mapHashResponse)
    }
}

// MARK: Increment

extension RedisClient {
    /// Increments a hash field's value and returns the new value.
    ///
    /// See [https://redis.io/commands/hincrby](https://redis.io/commands/hincrby)
    /// - Parameters:
    ///     - amount: The amount to increment the value stored in the field by.
    ///     - field: The name of the field whose value should be incremented.
    ///     - key: The key of the hash the field is stored in.
    /// - Returns: The new value of the hash field.
    @inlinable
    public func hincrby(_ amount: Int, field: String, in key: String) -> EventLoopFuture<Int> {
        /// connection.hincrby(20, field: "foo", in: "key")
        return send(command: "HINCRBY", with: [key, field, amount])
            .mapFromRESP()
    }

    /// Increments a hash field's value and returns the new value.
    ///
    /// See [https://redis.io/commands/hincrbyfloat](https://redis.io/commands/hincrbyfloat)
    /// - Parameters:
    ///     - amount: The amount to increment the value stored in the field by.
    ///     - field: The name of the field whose value should be incremented.
    ///     - key: The key of the hash the field is stored in.
    /// - Returns: The new value of the hash field.
    @inlinable
    public func hincrbyfloat<T>(_ amount: T, field: String, in key: String) -> EventLoopFuture<T>
        where
        T: BinaryFloatingPoint,
        T: RESPValueConvertible
    {
        return send(command: "HINCRBYFLOAT", with: [key, field, amount])
            .mapFromRESP()
    }
}