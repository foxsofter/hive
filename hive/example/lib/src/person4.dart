import 'package:hive/hive.dart';

part 'person4.g.dart';

@HiveType()
class Person4 {
  Person4({required this.name, required this.age, required this.friends});

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @HiveField(2)
  List<String> friends;

  @override
  String toString() {
    return '$name: $age';
  }
}