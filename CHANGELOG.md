# Changelog

All notable changes to PointerPals will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-14

### Initial Release

#### Core Features
- 📍 **Cursor Publishing**: Share your cursor position in real-time
- 👥 **Subscriptions**: Subscribe to other users' cursors
- 🪟 **Overlay Windows**: Transparent, non-interactive cursor overlays
- ⏰ **Auto-fade**: Cursors fade out after 5 seconds of inactivity
- 🎨 **Smooth Animations**: Fluid cursor movement with configurable timing
- 🔄 **Real-time Updates**: 30 FPS cursor position broadcasting
- 📊 **Menu Bar Integration**: Lightweight menu bar app with status indicators

#### Technical Features
- WebSocket-based networking for real-time communication
- Normalized coordinate system (0.0-1.0) for cross-resolution compatibility
- Automatic reconnection with configurable intervals
- Connection health monitoring
- Efficient position updates (only when cursor moves)
- Multiple subscription support

#### Configuration
- Comprehensive configuration file (`PointerPalsConfig.swift`)
- Customizable publishing rate (FPS)
- Adjustable fade timings
- Configurable cursor opacity
- Window behavior settings
- Debug logging option

#### Documentation
- Complete README with setup instructions
- Quick Start Guide
- Xcode Setup Guide
- Server documentation
- Node.js WebSocket server included

### Known Limitations
- Single display support (multi-monitor requires additional work)
- Basic cursor styling (custom cursors planned for future)
- Local/LAN testing only (production deployment manual)
- No built-in authentication (requires external implementation)

### Requirements
- macOS 12.0 or later
- Xcode 14.0 or later (for building)
- Node.js 14.x or later (for server)
- Accessibility permissions

---

## [Unreleased]

### Planned Features

#### v1.1.0 - Enhanced Customization
- [ ] Custom cursor colors per user
- [ ] Cursor labels showing usernames
- [ ] Multiple cursor style presets
- [ ] Custom cursor images
- [ ] Theme support (light/dark)

#### v1.2.0 - Advanced Features
- [ ] Drawing mode (leave cursor trails)
- [ ] Screen recording with cursor overlays
- [ ] Cursor history replay
- [ ] Presence indicators
- [ ] User online/offline status

#### v1.3.0 - Multi-Monitor
- [ ] Multi-display support
- [ ] Screen resolution synchronization
- [ ] Display selection per subscription
- [ ] Virtual screen boundaries

#### v1.4.0 - Collaboration
- [ ] Group subscriptions/rooms
- [ ] Permission system
- [ ] Private/public cursor sharing
- [ ] Temporary share links
- [ ] Time-limited sessions

#### v2.0.0 - Enterprise Features
- [ ] User authentication
- [ ] Encrypted connections (end-to-end)
- [ ] LDAP/SSO integration
- [ ] Team management
- [ ] Usage analytics
- [ ] Admin dashboard
- [ ] Audit logging

### Known Issues

#### High Priority
- None reported yet

#### Medium Priority
- Cursor may appear off-screen on different aspect ratios
- No automatic screen resolution detection
- Memory usage increases with many subscriptions

#### Low Priority
- Menu bar icon doesn't update immediately after subscription changes
- Reconnection can take multiple attempts on poor connections
- No visual feedback during connection attempts

### Performance Improvements Planned
- [ ] Optimize cursor position updates
- [ ] Reduce memory footprint
- [ ] Implement cursor position interpolation
- [ ] Add connection quality indicators
- [ ] Implement adaptive FPS based on network conditions

### Security Enhancements Planned
- [ ] Implement JWT authentication
- [ ] Add rate limiting per user
- [ ] Implement subscription approval workflow
- [ ] Add encryption for cursor data
- [ ] Implement user blocking
- [ ] Add privacy mode (hide cursor from specific apps)

---

## Version History

### Version Numbering
- **Major** (X.0.0): Breaking changes, major new features
- **Minor** (1.X.0): New features, backwards compatible
- **Patch** (1.0.X): Bug fixes, minor improvements

### Upgrade Notes

#### Upgrading to 1.x from any version
- No special steps required for initial release

---

## Contributing

We welcome contributions! Planned areas for contribution:

- **UI/UX**: Improve menu bar interface, add settings window
- **Networking**: Add support for other protocols (WebRTC, etc.)
- **Features**: Implement planned features from roadmap
- **Documentation**: Improve guides, add tutorials
- **Testing**: Write unit tests, integration tests
- **Platform Support**: iOS companion app, Windows version

---

## Support

For issues, questions, or feature requests:
- GitHub Issues: [Report a bug or request a feature]
- Email: support@pointerpals.example.com
- Discord: [Join our community]

---

## License

MIT License - see LICENSE file for details

---

## Acknowledgments

- Inspired by remote pair programming tools
- Built with Swift and AppKit
- Uses Node.js and WebSocket protocol
- Community feedback and contributions

---

Last Updated: 2024-01-14
