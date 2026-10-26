# KeyVault

A native macOS app for managing API keys, OAuth credentials, and multi-field developer secrets — stored entirely on-device with strong encryption.

Built as a developer-focused alternative to general-purpose password managers. Tools like Keeper or 1Password treat every credential as a username/password pair. KeyVault understands that an AWS IAM entry has an Access Key ID, a Secret Access Key, and a Region; that an OAuth entry has a Client ID, Client Secret, Token URL, Scope, and two tokens. Every entry type gets the right fields, and you can always add your own.

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

---

## Getting Started

```bash
git clone https://github.com/ababen/KeyVault.git
cd KeyVault
./setup.sh
```

`setup.sh` generates `KeyVault.xcodeproj` and opens it in Xcode. From there:

1. Select the **KeyVault** target → **Signing & Capabilities** → set your Team
2. Build and run with **⌘R** (run on your Mac, not the simulator — Touch ID and Keychain require a real device)

> **No paid developer account?** A free Apple ID works for personal use. Remove the `keychain-access-groups` entitlement from `KeyVault/KeyVault.entitlements` before building — the app will still use the Keychain via its default access group.

---

## Features

### Security

| Feature | Detail |
|---|---|
| Encryption | AES-256-GCM per field value |
| Key derivation | PBKDF2-SHA256, 100,000 iterations |
| Key storage | macOS Keychain (never written to disk in plaintext) |
| Unlock | Touch ID with password fallback |
| Auto-lock | 5-minute idle timeout (configurable) |
| Screen events | Locks automatically on screen sleep or system lock |
| Clipboard | Copied values auto-clear after 30 seconds |

### Entry Types & Templates

Each entry type pre-populates the right fields. All field sets are editable, and custom entries start blank.

| Template | Fields |
|---|---|
| **API Key** | API Key |
| **OAuth** | Client ID, Client Secret, Token URL, Scope, Access Token, Refresh Token |
| **Service Account** | Project ID, Client Email, Private Key |
| **AWS IAM** | Access Key ID, Secret Access Key, Region |
| **Custom** | You define the fields |

Each field is individually marked sensitive or non-sensitive. Sensitive fields are masked by default and require an explicit reveal action.

### Vault Management

- **Three-column layout** — sidebar (categories & tags), entry list, detail/edit view
- **Tags** — free-form tagging on any entry for flexible grouping
- **Expiration tracking** — set an expiry date on any entry; the app monitors and alerts when credentials are nearing or past expiry
- **Notes** — freeform notes field on every entry
- **Encrypted export/import** — backs up the entire vault as a single AES-256-GCM encrypted JSON file; importable with the same master password

### Agent Access

Entries can be granted to named agents (e.g. scripts, CLI tools, automation workflows) with scoped permissions:

- **Read** — agent can read field values
- **Read & Write** — agent can also update field values

Grants are per-entry and stored in SwiftData alongside the entry.

---

## Project Structure

```
KeyVault/
├── App/
│   ├── KeyVaultApp.swift       # Entry point, SwiftData ModelContainer setup
│   └── AppState.swift          # Global state: lock status, first launch
├── Models/
│   ├── Entry.swift             # Core credential entry model
│   ├── VaultSecureField.swift  # Encrypted field model
│   ├── EntryTemplate.swift     # Built-in field templates per entry type
│   ├── Agent.swift             # Agent identity
│   └── AgentGrant.swift        # Per-entry access grants with permissions
├── Security/
│   ├── VaultCrypto.swift       # AES-256-GCM encrypt/decrypt
│   ├── KeyDerivation.swift     # PBKDF2 key derivation from master password
│   ├── KeychainManager.swift   # Keychain read/write for the derived key
│   └── AutoLock.swift          # Idle timer + screen sleep/lock observer
├── Services/
│   ├── VaultService.swift      # CRUD for entries and fields (with encryption)
│   ├── ExportService.swift     # Encrypted JSON export and import
│   └── ExpirationMonitor.swift # Background monitoring for expiring credentials
├── Utilities/
│   ├── ClipboardManager.swift  # Copy-to-clipboard with 30s auto-clear
│   └── DateFormatting.swift    # Shared date formatters
└── Views/
    ├── MainView.swift           # Three-column NavigationSplitView
    ├── Sidebar/SidebarView      # Category and tag navigation
    ├── EntryList/EntryListView  # Filterable entry list
    ├── EntryDetail/             # Detail view, field rows, agent access panel
    ├── EntryEditor/             # Create/edit form with template picker
    └── Unlock/                  # First-launch setup and unlock screen
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | New entry |
| `⇧⌘L` | Lock vault |

---

## Roadmap

### Near-term

- **Full-text search** — search across entry names, providers, tags, and (decrypted) field values from the sidebar
- **Agent audit log** — a view showing every time an agent accessed an entry, with timestamp and permission used
- **Menu bar quick-access** — copy a field to clipboard from the menu bar without opening the full app window

### Future

- **Auto-rotation reminders** — configurable schedule to prompt key rotation independently of hard expiry dates (e.g. "remind me every 90 days")
- **Configurable auto-lock timeout** — expose the idle timeout as a user preference rather than a fixed 5 minutes
- **iCloud sync** — optional encrypted sync of the SwiftData store across devices via CloudKit
- **SSH key management** — import and store SSH key pairs as a dedicated entry type
- **Browser extension bridge** — inject API keys into web-based dashboards via a local XPC or native messaging bridge
- **Secure sharing** — time-limited, one-time-readable credential shares via an end-to-end encrypted link

---

## License

Released under the [MIT License](LICENSE). Copyright (c) 2026 Marketing Bull, LLC. All rights reserved.
