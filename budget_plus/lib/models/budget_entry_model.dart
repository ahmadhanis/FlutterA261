class BudgetEntryModel {
  const BudgetEntryModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
    required this.category,
    required this.amount,
    required this.transactionDate,
    required this.description,
    required this.imageName,
  });

  final int id;
  final int userId;
  final String title;
  final String type;
  final String category;
  final double amount;
  final DateTime transactionDate;
  final String description;
  final String? imageName;

  factory BudgetEntryModel.fromJson(Map<String, dynamic> json) {
    final dateText = (json['transaction_date'] as String).replaceFirst(
      ' ',
      'T',
    );

    return BudgetEntryModel(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      title: json['title'] as String,
      type: json['type'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(dateText),
      description: json['description'] as String? ?? '',
      imageName: json['image_name'] as String?,
    );
  }
}
