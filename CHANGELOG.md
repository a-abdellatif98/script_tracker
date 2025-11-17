# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-17

### Added
- Initial release of ScriptTracker
- Script execution tracking with status management
- Transaction support for script execution
- Built-in logging and progress tracking
- Batch processing helpers
- Timeout support for long-running scripts
- Stale script cleanup functionality
- Rake tasks for managing scripts:
  - `scripts:create` - Create new scripts
  - `scripts:run` - Run pending scripts
  - `scripts:status` - View script status
  - `scripts:rollback` - Rollback scripts
  - `scripts:cleanup` - Cleanup stale scripts
- Comprehensive RSpec test suite
- Full documentation and examples

[Unreleased]: https://github.com/blink-global/script_tracker/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/blink-global/script_tracker/releases/tag/v0.1.0
