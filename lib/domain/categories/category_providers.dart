import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryModel {
  final String id;
  final String name;
  final List<String> tags;

  CategoryModel({required this.id, required this.name, required this.tags});

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return CategoryModel(id: doc.id, name: doc.id, tags: []);
    }

    final rawTags = data['tags'];
    List<String> parsedTags = [];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    return CategoryModel(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      tags: parsedTags,
    );
  }
}

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('categories')
      .get();

  final categories = snapshot.docs
      .map((doc) => CategoryModel.fromFirestore(doc))
      .toList();

  categories.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

  return categories;
});
