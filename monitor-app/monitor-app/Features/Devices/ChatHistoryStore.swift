import Foundation
import SQLite3

actor ChatHistoryStore {
    static let shared = ChatHistoryStore()

    private let syncCooldown: TimeInterval = 15
    private var db: OpaquePointer?

    private init() {
        openDatabaseIfNeeded()
        createTablesIfNeeded()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func loadMessages(deviceId: String, agentId: String, limit: Int = 50) -> [ChatMessage] {
        openDatabaseIfNeeded()
        guard let db else { return [] }

        let sql = """
        SELECT message_id, role, content, created_at, status, input_type
        FROM chat_messages
        WHERE device_id = ? AND agent_id = ?
        ORDER BY created_at ASC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            finalize(stmt)
            return []
        }
        defer { finalize(stmt) }

        sqlite3_bind_text(stmt, 1, deviceId, -1, transientDestructor)
        sqlite3_bind_text(stmt, 2, agentId, -1, transientDestructor)
        sqlite3_bind_int(stmt, 3, Int32(limit))

        var messages: [ChatMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let messageId = stringColumn(stmt, index: 0),
                let roleString = stringColumn(stmt, index: 1),
                let content = stringColumn(stmt, index: 2),
                let inputTypeString = stringColumn(stmt, index: 5)
            else {
                continue
            }

            let createdAt = sqlite3_column_double(stmt, 3)
            let status = Int8(sqlite3_column_int(stmt, 4))
            let role: ChatMessage.Role = roleString == "assistant" ? .assistant : .user
            let inputType: ChatMessage.InputType = inputTypeString == "voice" ? .voice : .text

            messages.append(
                ChatMessage(
                    id: messageId,
                    role: role,
                    content: content,
                    time: Date(timeIntervalSince1970: createdAt),
                    status: status,
                    inputType: inputType
                )
            )
        }
        return messages
    }

    func upsert(messages: [ChatMessage], deviceId: String, agentId: String) {
        let persistable = messages.filter { !$0.id.hasPrefix("temp-") }
        guard !persistable.isEmpty else { return }
        openDatabaseIfNeeded()
        guard let db else { return }

        execute("BEGIN IMMEDIATE TRANSACTION")
        for message in persistable {
            upsert(message: message, deviceId: deviceId, agentId: agentId, db: db)
        }
        execute("COMMIT")
    }

    func upsert(message: ChatMessage, deviceId: String, agentId: String) {
        guard !message.id.hasPrefix("temp-") else { return }
        openDatabaseIfNeeded()
        guard let db else { return }
        upsert(message: message, deviceId: deviceId, agentId: agentId, db: db)
    }

    func shouldSync(deviceId: String, agentId: String, hasCache: Bool) -> Bool {
        if !hasCache {
            return true
        }
        guard let lastSync = lastSyncAt(deviceId: deviceId, agentId: agentId) else {
            return true
        }
        return Date().timeIntervalSince(lastSync) >= syncCooldown
    }

    func recordSync(deviceId: String, agentId: String, at date: Date = Date()) {
        openDatabaseIfNeeded()
        guard let db else { return }

        let sql = """
        INSERT INTO chat_sync_state(device_id, agent_id, last_sync_at)
        VALUES (?, ?, ?)
        ON CONFLICT(device_id, agent_id)
        DO UPDATE SET last_sync_at = excluded.last_sync_at
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            finalize(stmt)
            return
        }
        defer { finalize(stmt) }

        sqlite3_bind_text(stmt, 1, deviceId, -1, transientDestructor)
        sqlite3_bind_text(stmt, 2, agentId, -1, transientDestructor)
        sqlite3_bind_double(stmt, 3, date.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    private func lastSyncAt(deviceId: String, agentId: String) -> Date? {
        openDatabaseIfNeeded()
        guard let db else { return nil }

        let sql = """
        SELECT last_sync_at
        FROM chat_sync_state
        WHERE device_id = ? AND agent_id = ?
        LIMIT 1
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            finalize(stmt)
            return nil
        }
        defer { finalize(stmt) }

        sqlite3_bind_text(stmt, 1, deviceId, -1, transientDestructor)
        sqlite3_bind_text(stmt, 2, agentId, -1, transientDestructor)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
    }

    private func upsert(message: ChatMessage, deviceId: String, agentId: String, db: OpaquePointer) {
        let sql = """
        INSERT INTO chat_messages(
            device_id, agent_id, message_id, role, content, created_at, status, input_type, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(message_id)
        DO UPDATE SET
            role = excluded.role,
            content = excluded.content,
            created_at = excluded.created_at,
            status = excluded.status,
            input_type = excluded.input_type,
            updated_at = excluded.updated_at
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            finalize(stmt)
            return
        }
        defer { finalize(stmt) }

        sqlite3_bind_text(stmt, 1, deviceId, -1, transientDestructor)
        sqlite3_bind_text(stmt, 2, agentId, -1, transientDestructor)
        sqlite3_bind_text(stmt, 3, message.id, -1, transientDestructor)
        sqlite3_bind_text(stmt, 4, message.role == .assistant ? "assistant" : "user", -1, transientDestructor)
        sqlite3_bind_text(stmt, 5, message.content, -1, transientDestructor)
        sqlite3_bind_double(stmt, 6, message.time.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 7, Int32(message.status))
        sqlite3_bind_text(stmt, 8, message.inputType == .voice ? "voice" : "text", -1, transientDestructor)
        sqlite3_bind_double(stmt, 9, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    private func openDatabaseIfNeeded() {
        guard db == nil else { return }
        let url = databaseURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            db = nil
            return
        }
    }

    private func createTablesIfNeeded() {
        execute("""
        CREATE TABLE IF NOT EXISTS chat_messages (
            device_id TEXT NOT NULL,
            agent_id TEXT NOT NULL,
            message_id TEXT PRIMARY KEY,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at REAL NOT NULL,
            status INTEGER NOT NULL,
            input_type TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        """)

        execute("""
        CREATE INDEX IF NOT EXISTS idx_chat_messages_device_agent_time
        ON chat_messages(device_id, agent_id, created_at DESC);
        """)

        execute("""
        CREATE TABLE IF NOT EXISTS chat_sync_state (
            device_id TEXT NOT NULL,
            agent_id TEXT NOT NULL,
            last_sync_at REAL NOT NULL,
            PRIMARY KEY (device_id, agent_id)
        );
        """)
    }

    private func execute(_ sql: String) {
        openDatabaseIfNeeded()
        guard let db else { return }
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private var databaseURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("monitor-app", isDirectory: true)
            .appendingPathComponent("chat-cache.sqlite", isDirectory: false)
    }

    private func stringColumn(_ stmt: OpaquePointer?, index: Int32) -> String? {
        guard let raw = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: raw)
    }

    private func finalize(_ stmt: OpaquePointer?) {
        if let stmt {
            sqlite3_finalize(stmt)
        }
    }

    private var transientDestructor: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
