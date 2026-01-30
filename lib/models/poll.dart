import 'dart:convert';

class Poll {
  final String pollId;
  final String? password;
  final String hostDeviceId;
  final DateTime createdAt;
  final bool isActive;

  Poll({
    required this.pollId,
    this.password,
    required this.hostDeviceId,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'pollId': pollId,
      'password': password,
      'hostDeviceId': hostDeviceId,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      pollId: json['pollId'] as String,
      password: json['password'] as String?,
      hostDeviceId: json['hostDeviceId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Poll copyWith({
    String? pollId,
    String? password,
    String? hostDeviceId,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return Poll(
      pollId: pollId ?? this.pollId,
      password: password ?? this.password,
      hostDeviceId: hostDeviceId ?? this.hostDeviceId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
