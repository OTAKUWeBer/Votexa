import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/loading.dart';
import 'pages/home.dart';
import 'pages/host/host_create.dart';
import 'pages/host/host_poll.dart';
import 'pages/participant/participant_join.dart';
import 'pages/participant/participant_vote.dart';
import 'pages/results.dart';
import 'providers/poll_provider.dart';
import 'providers/participant_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PollProvider()),
        ChangeNotifierProvider(create: (_) => ParticipantProvider()),
      ],
      child: const VotexaApp(),
    ),
  );
}

class VotexaApp extends StatelessWidget {
  const VotexaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Votexa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF8b5cf6),
        scaffoldBackgroundColor: const Color(0xFF0f172a),
      ),
      home: const LoadingPage(),
      routes: {
        '/loading': (context) => const LoadingPage(),
        '/home': (context) => const HomePage(),
        '/host_create': (context) => const HostCreatePage(),
        '/host_poll': (context) => const HostPollPage(),
        '/participant_join': (context) => const ParticipantJoinPage(),
        '/participant_vote': (context) => const ParticipantVotePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/results') {
          final args = settings.arguments as Map<String, dynamic>?;
          final isHost = args?['isHost'] as bool? ?? false;
          return MaterialPageRoute(
            builder: (context) => ResultsPage(isHost: isHost),
          );
        }
        return null;
      },
    );
  }
}
