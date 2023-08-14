import 'dart:io';

import 'package:hive/hive.dart';

part 'main.g.dart';

@HiveType(typeId: 1)
class Person {
  Person({required this.name, required this.age, required this.friends});

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

@HiveType(typeId: 255)
class Person2 {
  Person2({required this.name, required this.age, required this.friends});

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

void main() async {
  var path = Directory.current.path;
  Hive
    ..init(path)
    ..registerAdapter(PersonAdapter())
    ..registerAdapter(Person2Adapter());

  var box = await Hive.openBox('testBox');

  var person = Person(
    name: 'Peter',
    age: 21,
    friends: ['Linda', 'Marc', 'Anne'],
  );
  await box.put('peter', person);
  var person2 = Person2(
    name: 'Dave',
    age: 22,
    friends: ['Linda', 'Marc', 'Anne'],
  );

  await box.put('dave', person2);

  final p1s = <Person>[];
  for (var i =0; i < 100000; i++) {
    p1s.add(Person(name: 'fewfwefewfwef$i', age: 1100+i, friends:  ['Linda', 'Marc', 'Anne']));
  }
  box.addAll(p1s);

  print(box.get('peter')); // Peter: 21
  print(box.get('dave')); // Dave: 22
  print(box.get(1)); // Dave: 22

  await box.close();
  final sw = Stopwatch();
  sw.start();
  var lb = await Hive.openBox('testBox');
  sw.stop();
  print("time cost: ${sw.elapsedMilliseconds}");
  print(lb.get('peter')); // Peter: 21
  print(lb.get('dave')); // Dave: 22
}
