# Contributing to EasyMonitor Probe Node

Thank you for your interest in contributing to the EasyMonitor Probe Node! This document provides guidelines for contributing to this open-source project.

## Development Setup

### Prerequisites

- Go 1.23 or later
- Redis 7+ for testing
- Make (optional but recommended)

### Getting Started

1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/easymonitor.git
   cd easymonitor/probe-node
   ```

2. **Install Dependencies**
   ```bash
   make deps
   ```

3. **Run Tests**
   ```bash
   make test
   ```

## Code Guidelines

### Go Style

- Follow standard Go conventions and idioms
- Use `gofmt` for formatting
- Run `go vet` before committing
- Prefer `golangci-lint` for comprehensive linting

### Testing

- Write tests for all new functionality
- Maintain or improve code coverage
- Use table-driven tests where appropriate
- Mock external dependencies (Redis, HTTP servers)

Example test structure:

```go
func TestFeatureName(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected string
        wantErr  bool
    }{
        {"valid input", "test", "result", false},
        {"invalid input", "", "", true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := FeatureFunction(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("expected error: %v, got: %v", tt.wantErr, err)
            }
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

### Documentation

- Add godoc comments for all exported functions and types
- Update README.md when adding new features
- Include examples in documentation
- Keep CHANGELOG.md updated

## Pull Request Process

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**
   - Write clean, tested code
   - Follow existing patterns
   - Add tests for new features

3. **Test Your Changes**
   ```bash
   make test
   make lint
   ```

4. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

   Use conventional commit messages:
   - `feat:` new feature
   - `fix:` bug fix
   - `docs:` documentation changes
   - `test:` adding or updating tests
   - `refactor:` code refactoring
   - `perf:` performance improvements

5. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

   Then create a pull request on GitHub.

## What to Contribute

### High Priority

- Bug fixes
- Performance improvements
- Additional check types (TCP, UDP, DNS, etc.)
- Improved error handling
- Better logging and observability

### Welcome Contributions

- Documentation improvements
- Test coverage improvements
- Code refactoring
- Example configurations
- CI/CD improvements

### Ideas for New Features

- Metrics export (Prometheus format)
- Distributed tracing support
- Advanced retry logic
- Circuit breaker patterns
- Additional authentication methods
- Webhook notifications
- Custom check plugins

## Architecture Guidelines

### Core Principles

1. **Simplicity** - Keep the binary small and focused
2. **Reliability** - Handle failures gracefully
3. **Performance** - Optimize for high throughput
4. **Observability** - Provide clear logs and metrics

### Module Structure

```
probe-node/
├── cmd/probe/          # Main application
├── internal/           # Private application code
│   ├── auth/          # JWT authentication
│   ├── checker/       # Check implementations
│   ├── config/        # Configuration management
│   ├── consumer/      # Redis stream consumer
│   └── publisher/     # Result publisher
└── pkg/               # Public packages
    └── types/         # Shared types
```

### Adding New Check Types

To add a new check type (e.g., DNS):

1. Create `internal/checker/dns.go`
2. Implement the `Checker` interface
3. Add tests in `internal/checker/dns_test.go`
4. Update `cmd/probe/main.go` to handle the new type
5. Document in README.md

## Testing

### Unit Tests

```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Run specific test
go test -v ./internal/checker -run TestHTTPChecker
```

### Integration Tests

Integration tests require Redis:

```bash
# Start Redis in Docker
docker run -d -p 6379:6379 redis:7-alpine

# Run integration tests
go test -v -tags=integration ./...
```

### Benchmarks

```bash
# Run benchmarks
go test -bench=. ./...

# With memory profiling
go test -bench=. -benchmem ./...
```

## Performance Considerations

- Avoid allocations in hot paths
- Use sync.Pool for frequently allocated objects
- Profile before optimizing
- Consider impact on binary size

## Security

- Never log sensitive data (tokens, passwords)
- Validate all external inputs
- Use constant-time comparison for tokens
- Keep dependencies updated
- Report security issues privately

## Getting Help

- GitHub Issues: For bugs and feature requests
- GitHub Discussions: For questions and general discussion
- Code Review: Request review from maintainers

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the code, not the person
- Help others learn and grow

Thank you for contributing to EasyMonitor! 🚀
