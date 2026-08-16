class SavedFile {
  final String name;
  final int size;
  final String date;

  const SavedFile(this.name, this.size, this.date);

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'name': name, 'size': size, 'date': date};

  factory SavedFile.fromJson(Map<String, dynamic> json) => SavedFile(
        json['name'] as String? ?? '',
        json['size'] as int? ?? 0,
        json['date'] as String? ?? '',
      );
}
