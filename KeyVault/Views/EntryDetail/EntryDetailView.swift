import SwiftUI
import CryptoKit

struct EntryDetailView: View {
    @Bindable var entry: Entry
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var decryptedValues: [UUID: String] = [:]
    @State private var visibleFields: Set<UUID> = []
    @State private var showDeleteConfirm = false
    @State private var showEditor = false
    @State private var copiedFieldId: UUID?

    private var vaultService: VaultService? {
        guard let key = appState.encryptionKey else { return nil }
        return VaultService(modelContext: modelContext, key: key)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                fieldsSection
                Divider()
                agentAccessSection
                Divider()
                metadataSection
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            EntryEditorView(entry: entry)
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteEntry() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(entry.name)\" and all its fields.")
        }
        .onDisappear { decryptedValues.removeAll() }
        // Non-sensitive fields are shown in the clear, so decrypt them up front. Re-runs when
        // another entry is selected or this one is edited.
        .task(id: "\(entry.id)-\(entry.updatedAt.timeIntervalSinceReferenceDate)") { loadNonSensitiveValues() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: entry.type.icon)
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .frame(width: 48, height: 48)
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Text(entry.provider)
                        .foregroundStyle(.secondary)

                    Text(entry.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .clipShape(Capsule())

                    expiryPill
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var expiryPill: some View {
        switch entry.expiryStatus {
        case .expired:
            Text("Expired")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.red.opacity(0.15))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        case .expiringSoon:
            Text("Expires \(entry.expiresAt?.relativeDisplay ?? "")")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.15))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        case .active:
            Text("Expires \(entry.expiresAt?.shortDisplay ?? "")")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        case .noExpiry:
            EmptyView()
        }
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fields")
                .font(.headline)

            ForEach(entry.fields.sorted(by: { $0.sortOrder < $1.sortOrder })) { field in
                FieldRow(
                    field: field,
                    decryptedValue: decryptedValues[field.id],
                    isVisible: visibleFields.contains(field.id),
                    isCopied: copiedFieldId == field.id,
                    onToggleVisibility: { toggleFieldVisibility(field) },
                    onCopy: { copyField(field) }
                )
            }
        }
    }

    // MARK: - Agent Access

    private var agentAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agent Access")
                .font(.headline)

            if entry.agentAccess.isEmpty {
                Text("No agents have access to this entry")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(entry.agentAccess) { grant in
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading) {
                            Text(grant.agentName)
                                .fontWeight(.medium)
                            Text("Granted \(grant.grantedAt.relativeDisplay) · \(grant.permission.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            revokeAccess(grant)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entry.tags.isEmpty {
                HStack {
                    Text("Tags:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(entry.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            if !entry.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.notes)
                        .font(.caption)
                }
            }

            HStack(spacing: 16) {
                Text("Created \(entry.createdAt.shortDisplay)")
                Text("Updated \(entry.updatedAt.relativeDisplay)")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func loadNonSensitiveValues() {
        guard let service = vaultService else { return }
        // Non-sensitive fields, plus any sensitive ones the user has revealed, so an edit
        // never leaves a stale value on screen.
        var values: [UUID: String] = [:]
        for field in entry.fields where !field.isSensitive || visibleFields.contains(field.id) {
            values[field.id] = try? service.decryptFieldValue(field)
        }
        decryptedValues = values
    }

    private func toggleFieldVisibility(_ field: VaultSecureField) {
        if visibleFields.contains(field.id) {
            visibleFields.remove(field.id)
            decryptedValues.removeValue(forKey: field.id)
        } else {
            guard let service = vaultService else { return }
            do {
                let value = try service.decryptFieldValue(field)
                decryptedValues[field.id] = value
                visibleFields.insert(field.id)
            } catch {
                // TODO: show error
            }
        }
        appState.autoLock.userActivity()
    }

    private func copyField(_ field: VaultSecureField) {
        guard let service = vaultService else { return }
        do {
            let value: String
            if let cached = decryptedValues[field.id] {
                value = cached
            } else {
                value = try service.decryptFieldValue(field)
            }
            ClipboardManager.copy(value)
            copiedFieldId = field.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if copiedFieldId == field.id { copiedFieldId = nil }
            }
        } catch {
            // TODO: show error
        }
        appState.autoLock.userActivity()
    }

    private func revokeAccess(_ grant: AgentGrant) {
        try? vaultService?.revokeAccess(grant)
    }

    private func deleteEntry() {
        try? vaultService?.deleteEntry(entry)
    }
}

