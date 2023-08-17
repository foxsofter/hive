import 'dart:io';

import 'package:hive/hive.dart';
import 'src/lib.dart';

part 'main.g.dart';

@HiveType(typeId: 1)
class Person extends HiveObject {
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

@HiveType(typeId: 222)
class Person2 extends HiveObject {
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
    ..registerAdapter(Person2Adapter())
    ..registerAdapter(Person3Adapter())
    ..registerAdapter(Person4Adapter());

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
  for (var i = 0; i < 3; i++) {
    p1s.add(Person(
        name: 'fewfwefewfwef$i',
        age: 1100 + i,
        friends: ['Linda', 'Marc', 'Anne']));
  }
  box.addAll(p1s);

  final keys = box.toMap();
  print('keys: ${keys}');
  final values = box.values;
  print('values: ${values}');

  print(box.get('peter')); // Peter: 21
  print(box.get('dave')); // Dave: 22
  print(box.get(1)); // Dave: 22

  final sw = Stopwatch();
  sw.start();
  await Hive.openTypeBox2<Person, Person2>(oldBox: box);
  sw.stop();
  print("time cost: ${sw.elapsedMilliseconds}");

  final tb = Hive.typeBox<Person>();

  await box.close();

  var lb = Hive.typeBox<Person>();
  print(lb.get('peter')); // Peter: 21
  print(lb.get('dave')); // Dave: 22

  var lb3 = await Hive.openTypeBox<Person3>();
  final p3s = <Person3>[];
  for (var i = 0; i < 3; i++) {
    p3s.add(Person3(
        name: 'p3 $i', age: 1100 + i, friends: ['Linda', 'Marc', 'Anne']));
  }
  lb3.addAll(p3s);

  print(lb3.get(0)); // Peter: 21
}
