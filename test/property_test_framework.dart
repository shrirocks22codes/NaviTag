/// Simple property-based testing framework for Flutter
/// This provides basic generators and property test functionality
library;

import 'dart:math';
import 'package:test/test.dart';

/// Base class for all generators
abstract class Generator<T> {
  T generate(Random random);
}

/// String generator
class StringGenerator extends Generator<String> {
  final int minLength;
  final int maxLength;
  final String chars;

  StringGenerator({
    this.minLength = 1,
    this.maxLength = 10,
    this.chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  });

  @override
  String generate(Random random) {
    final length = minLength + random.nextInt(maxLength - minLength + 1);
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}

/// Integer generator
class IntGenerator extends Generator<int> {
  final int min;
  final int max;

  IntGenerator({this.min = 0, this.max = 100});

  @override
  int generate(Random random) {
    return min + random.nextInt(max - min + 1);
  }
}

/// Double generator
class DoubleGenerator extends Generator<double> {
  final double min;
  final double max;

  DoubleGenerator({this.min = 0.0, this.max = 100.0});

  @override
  double generate(Random random) {
    return min + random.nextDouble() * (max - min);
  }
}

/// Choice generator - picks from a list of options
class ChoiceGenerator<T> extends Generator<T> {
  final List<T> choices;

  ChoiceGenerator(this.choices);

  @override
  T generate(Random random) {
    return choices[random.nextInt(choices.length)];
  }
}

/// List generator
class ListGenerator<T> extends Generator<List<T>> {
  final Generator<T> elementGenerator;
  final int minLength;
  final int maxLength;

  ListGenerator(
    this.elementGenerator, {
    this.minLength = 0,
    this.maxLength = 10,
  });

  @override
  List<T> generate(Random random) {
    final length = minLength + random.nextInt(maxLength - minLength + 1);
    return List.generate(length, (_) => elementGenerator.generate(random));
  }
}

/// Creates a property test with named parameters (backward compatibility)
void createPropertyTest<T>({
  required String description,
  required Generator<T> generator,
  required bool Function(T) property,
  String? featureName,
  int? propertyNumber,
  String? propertyText,
  int iterations = 100,
  int? seed,
}) {
  test(description, () {
    final random = Random(seed);
    
    for (int i = 0; i < iterations; i++) {
      final testCase = generator.generate(random);
      
      try {
        final result = property(testCase);
        if (!result) {
          fail('Property failed for test case: $testCase');
        }
      } catch (e, stackTrace) {
        fail('Property threw exception for test case: $testCase\n'
             'Exception: $e\n'
             'Stack trace: $stackTrace');
      }
    }
  });
}

/// Creates a property test with positional parameters
void createPropertyTestPositional<T>(
  String description,
  Generator<T> generator,
  bool Function(T) property, {
  int iterations = 100,
  int? seed,
}) {
  test(description, () {
    final random = Random(seed);
    
    for (int i = 0; i < iterations; i++) {
      final testCase = generator.generate(random);
      
      try {
        final result = property(testCase);
        if (!result) {
          fail('Property failed for test case: $testCase');
        }
      } catch (e, stackTrace) {
        fail('Property threw exception for test case: $testCase\n'
             'Exception: $e\n'
             'Stack trace: $stackTrace');
      }
    }
  });
}