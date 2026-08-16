class Message {
  final String type;
  final Map<String, dynamic> data;

  Message(this.type, this.data);

  Map<String, dynamic> toJson() => <String, dynamic>{'type': type, ...data};

  factory Message.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final data = Map<String, dynamic>.from(json)..remove('type');
    return Message(type, data);
  }
}
