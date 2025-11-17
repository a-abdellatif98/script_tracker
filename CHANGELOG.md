# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-01-17

### Added
- **Database advisory locks** for preventing concurrent script execution (PostgreSQL, MySQL, SQLite)
- `acquire_lock(filename)` - Manual lock acquisition
- `release_lock(filename)` - Manual lock release
- `with_advisory_lock(filename)` - Automatic lock management with block
- `check_timeout!(start_time, max_duration)` - Safer manual timeout checking
- RuboCop configuration with comprehensive rules
- RuboCop integration in CI/CD pipeline
- 14 new test cases for concurrency and timeout behavior
- Support for multi-database advisory locking strategies

### Fixed
- **CRITICAL**: Removed broken pre-execution timeout check that never worked
- **CRITICAL**: Added concurrency protection to prevent data corruption from simultaneous script runs
- Fixed `load` usage with proper warning suppression to prevent constant redefinition warnings
- Fixed nested ternary operators in rake tasks for better readability
- Fixed line length issues throughout codebase
- All RuboCop offenses resolved (0 offenses)

### Changed
- Documented risks of Ruby's `Timeout.timeout` with comprehensive warnings
- Improved code quality across all files (100% RuboCop compliant)
- Enhanced test coverage from 55 to 69 examples
- Improved error handling and logging
- Better numeric predicates usage (`.positive?` instead of `> 0`)
- Consistent string literal style (single quotes)

### Security
- Concurrent execution protection prevents race conditions and data corruption
- Advisory locks work across PostgreSQL, MySQL, and SQLite
- Locks automatically released even on exceptions

## [0.1.3] - 2025-01-17

### Changed
- Simplified and streamlined README documentation
- Cleaned up CHANGELOG format

## [0.1.2] - 2025-01-17

### Fixed
- Updated GitHub Actions workflows to use v4 actions
- Fixed GitHub release permissions
- Refactored workflows to match successful gem release pattern

## [0.1.1] - 2025-01-17

### Added
- CI/CD workflows for automated testing and releases
- GitHub Actions workflow for automatic releases on tag push
- Manual release workflow via GitHub Actions UI
- Local release script (`bin/release`)

## [0.1.0] - 2025-01-17

### Added
- Initial release
- Script execution tracking with status management
- Transaction support for script execution
- Built-in logging and progress tracking
- Batch processing helpers
- Timeout support for long-running scripts
- Stale script cleanup functionality
- Rake tasks for managing scripts
- Comprehensive RSpec test suite

[Unreleased]: https://github.com/a-abdellatif98/script_tracker/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/a-abdellatif98/script_tracker/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/a-abdellatif98/script_tracker/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/a-abdellatif98/script_tracker/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/a-abdellatif98/script_tracker/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/a-abdellatif98/script_tracker/releases/tag/v0.1.0
