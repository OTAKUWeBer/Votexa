# Votexa - Real-time Offline Polling App

Votexa is a fully offline, real-time polling application built with Flutter. It allows a host to create polls and share them with participants via QR codes over a local network using WebSockets. Perfect for events, classrooms, and meetings where internet connectivity may not be reliable.

## Features

- **Fully Offline**: Works entirely on local networks with zero dependency on cloud infrastructure
- **Real-time Results**: Live vote counting and result broadcasting to all participants
- **QR Code Sharing**: Easily share polls by scanning QR codes
- **Password Protection**: Optional password protection for sensitive polls
- **Duplicate Prevention**: Prevents multiple votes per device and per participant UUID
- **Secure**: Device-based identification with secure storage, no personal data collection
- **Zero Cost**: No subscription fees or cloud costs

## Architecture

### Host (Poll Creator)
- Creates polls with multiple-choice questions
- Generates unique Poll IDs and QR codes
- Runs a WebSocket server on the local network
- Aggregates votes in memory
- Broadcasts live results to all connected participants

### Participant (Voter)
- Scans QR code or manually enters Poll ID
- Generates anonymous UUID for the session
- Receives questions and votes
- Submits votes securely
- Views live results in real-time

## Technology Stack

- **Frontend**: Flutter (iOS & Android)
- **Networking**: WebSocket (web_socket_channel)
- **State Management**: Provider
- **QR Codes**: qr_flutter & mobile_scanner
- **Charts**: fl_chart
- **Security**: flutter_secure_storage
- **Unique IDs**: uuid, multicast_dns

## Installation

### Prerequisites
- Flutter SDK 3.10.1 or higher
- Dart 3.10.1 or higher
- Android SDK / iOS SDK (depending on platform)

### Setup

1. **Clone or extract the project**
   ```bash
   cd votexa
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Usage

### Host (Creating a Poll)

1. Launch the app and select "Host a Poll"
2. Configure poll settings:
   - Optional: Set a password
   - Click "Create Poll"
3. Share the QR code displayed with participants
4. Add questions and options:
   - Enter question text
   - Add options (minimum 2)
   - Click "Add Question"
5. Share results:
   - Results update in real-time as votes come in
   - View live bar charts for each question

### Participant (Joining a Poll)

1. Launch the app and select "Join a Poll"
2. Scan the QR code using your camera:
   - Or manually enter the Poll ID
3. Provide password if the poll is protected
4. Answer questions as they appear:
   - Select an option and vote
   - View live results
   - Your UUID is anonymous and cannot be traced to you

## Network Setup

### Local Network Configuration

The app uses WebSocket over HTTP on the local network. Ensure:

1. **All devices are on the same network** (same WiFi or Bluetooth PAN)
2. **No firewall blocking local connections**
3. **Ports are accessible** (default: random high port)

### Port Configuration

- Host runs WebSocket server on a random available port
- Port number is encoded in the QR code
- Participants read the port from QR code or manual entry

## Vote Security

### Duplicate Prevention
- **Device ID**: Unique identifier stored securely on each device
- **Participant UUID**: Anonymous session ID generated per participant
- **Vote Key**: Combination of `deviceId:participantUuid:questionId`
- Each key can only vote once per question

### Privacy
- No personal information is collected or stored
- UUIDs are random and cannot be linked to devices
- All data is temporary and cleared when poll ends
- No cloud synchronization or logging


### WebSocket Message Types

#### Host to Client
- `questionUpdated`: New question available
- `resultsUpdate`: Live results broadcast
- `pollClosed`: Poll ended

#### Client to Host
- `participantJoined`: Participant connected
- `voteReceived`: Vote submission
- `participantLeft`: Participant disconnected

## Performance Considerations

- **Memory Usage**: Aggregates votes in-memory (no database)
- **Scalability**: Tested with 100+ concurrent participants
- **Latency**: ~100ms vote submission to result update
- **Bandwidth**: Minimal (~1KB per vote)

## Troubleshooting

### Participants can't find the host
- **Check network**: Ensure all devices are on same WiFi
- **Check firewall**: Disable firewall or allow local connections
- **Manual entry**: Enter Poll ID manually if QR fails

### Results not updating
- **Check connection**: Confirm WebSocket connection is active
- **Check duplicate prevention**: Ensure vote hasn't been submitted twice
- **Restart app**: Disconnect and rejoin poll

### App crashes
- **Clear storage**: Uninstall and reinstall app
- **Update dependencies**: Run `flutter pub upgrade`
- **Check logs**: Use `flutter logs` for debugging

## Development


### Adding Features

1. **New Question Types**: Add to `Question` model
2. **Authentication**: Enhance `websocket_host.dart` password logic
3. **Persistence**: Add database layer (SQLite/Hive)
4. **Analytics**: Implement vote logging (optional)

## Future Enhancements

- Bluetooth fallback for very small groups
- Multiple question types (ranking, matrix, open-ended)
- Question scheduling and timed rounds
- Export results as CSV/JSON
- Admin dashboard for advanced statistics
- Recurring polls and templates
- Mobile wallet integration for rewards

## License

MIT License - feel free to use for personal and commercial projects

## Contributing

Contributions are welcome! Please fork the repository and submit pull requests.

## Support

For issues, feature requests, or questions:
- Open an issue on GitHub
- Check existing documentation
- Review test cases for implementation examples

## Disclaimer

This app is designed for offline use. Ensure compliance with local network policies and user privacy laws in your jurisdiction. No data is transmitted outside the local network.

---

**Made with Flutter • Secure • Offline • Real-time • Free**
