# KantongKresek Installer

Interactive CLI installer that bootstraps a **Debian server** with everything needed: phpMyAdmin, Nginx + PHP-FPM, Java 11, and MariaDB. Designed for SSH deployment — lightweight, fast, and terminal-friendly.

## Features

- **ASCII banner** with real-time online/offline status
- **Menu-driven UI** built with inquirer + chalk
- **Progress spinners** with elapsed time for each script
- **SSH-friendly** — works in any terminal, no TUI dependency
- **GitHub-hosted scripts** — zero install payload, streams from raw URL

## Prerequisites

- Debian 12 (Bookworm) or compatible
- Root access
- Node.js >= 18
- Internet access (for curl + GitHub)

## Installation

```bash
# Global install
npm install -g kantongkresek

# Or run without installing
npx kantongkresek
```

## Usage

```bash
kantongkresek
```

Menu options:

| # | Option | Description |
|---|--------|-------------|
| 1 | Install Base | phpMyAdmin, Java 11, MariaDB |
| 2 | Configurations | Nginx + PHP-FPM + required packages |
| 3 | Install Database | Provision database schema |
| 0 | Exit | Close the installer |

## How it works

The CLI streams shell scripts from GitHub (`raw.githubusercontent.com`) and pipes them to `bash`. Each script runs with `stdio: 'inherit'`, so output appears inline. Progress is tracked with `ora` spinners and elapsed-time logging.

## License

MIT