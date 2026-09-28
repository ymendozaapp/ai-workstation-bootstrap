# AI Workstation Bootstrap

Public recovery entrypoint for my private AI workstation configuration.

## Purpose

This repository contains the minimal Windows recovery script required to:

1. Detect or recover WinGet.
2. Install missing bootstrap prerequisites: PowerShell 7, Git, GitHub CLI and chezmoi.
3. Authenticate with GitHub.
4. Clone the private ai-workstation repository.
5. Hand off control to bootstrap.ps1.

## Usage

Check only:

    .\install.ps1

Install/recover:

    .\install.ps1 -Install

## Security

This repository must never contain:
- API keys
- OAuth tokens
- passwords
- private keys
- .env files
- authentication files

The actual workstation configuration is stored separately in a private repository.

## Design

This bootstrap is intended to be idempotent:
- existing tools are not reinstalled;
- existing repositories are not recloned;
- authentication is requested only when required.
