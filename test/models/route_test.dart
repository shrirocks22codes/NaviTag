import 'dart:math';
import 'package:test/test.dart';
import 'package:nfc_project_test/models/route.dart';
import '../property_test_framework.dart';

/// Generator for InstructionType
class InstructionTypeGenerator extends Generator<InstructionType> {
  @override
  InstructionType generate(Random random) {
    return InstructionType.values[random.nextInt(InstructionType.values.length)];
  }
}

/// Generator for Direction
class DirectionGenerator extends Generator<Direction> {
  @override
  Direction generate(Random random) {
    return Direction.values[random.nextInt(Direction.values.length)];
  }
}

/// Generator for NavigationInstruction
class NavigationInstructionGenerator extends Generator<NavigationInstruction> {
  final StringGenerator _stringGen = StringGenerator(minLength: 1, maxLength: 30);
  final InstructionTypeGenerator _typeGen = InstructionTypeGenerator();
  final DirectionGenerator _directionGen = DirectionGenerator();
  final DoubleGenerator _distanceGen = DoubleGenerator(min: 0.1, max: 1000.0);

  @override
  NavigationInstruction generate(Random random) {
    return NavigationInstruction(
      id: _stringGen.generate(random),
      type: _typeGen.generate(random),
      description: _stringGen.generate(random),
      fromLocationId: _stringGen.generate(random),
      toLocationId: _stringGen.generate(random),
      direction: _directionGen.generate(random),
      distance: _distanceGen.generate(random),
    );
  }
}

/// Generator for Route that creates valid routes
class RouteGenerator extends Generator<Route> {
  final StringGenerator _stringGen = StringGenerator(minLength: 1, maxLength: 20);
  final DoubleGenerator _distanceGen = DoubleGenerator(min: 1.0, max: 10000.0);
  final IntGenerator _timeGen = IntGenerator(min: 60000, max: 3600000); // 1 minute to 1 hour in ms

  @override
  Route generate(Random random) {
    final startId = _stringGen.generate(random);
    final endId = _stringGen.generate(random);
    
    // Generate a path with at least start and end
    final pathLength = 2 + random.nextInt(8); // 2-9 locations
    final pathIds = <String>[startId];
    
    // Add intermediate locations
    for (int i = 1; i < pathLength - 1; i++) {
      pathIds.add(_stringGen.generate(random));
    }
    pathIds.add(endId);
    
    // Generate instructions that match the path
    final instructions = <NavigationInstruction>[];
    for (int i = 0; i < pathIds.length - 1; i++) {
      final instruction = NavigationInstruction(
        id: _stringGen.generate(random),
        type: i == 0 ? InstructionType.start : 
              i == pathIds.length - 2 ? InstructionType.destination : 
              InstructionType.straight,
        description: _stringGen.generate(random),
        fromLocationId: pathIds[i],
        toLocationId: pathIds[i + 1],
        direction: DirectionGenerator().generate(random),
        distance: _distanceGen.generate(random),
      );
      instructions.add(instruction);
    }

    return Route(
      id: _stringGen.generate(random),
      startLocationId: startId,
      endLocationId: endId,
      pathLocationIds: pathIds,
      estimatedDistance: _distanceGen.generate(random),
      estimatedTime: Duration(milliseconds: _timeGen.generate(random)),
      instructions: instructions,
    );
  }
}

void main() {
  group('Route Model Tests', () {
    // Property 3: Route Calculation Optimality
    // This property tests that route serialization preserves all route data,
    // which is essential for maintaining route calculation integrity
    createPropertyTest<Route>(
      description: 'Route serialization round-trip preserves all data',
      generator: RouteGenerator(),
      property: (route) {
        // Serialize to JSON and back
        final json = route.toJson();
        final deserialized = Route.fromJson(json);
        
        // The deserialized route should be identical to the original
        return route == deserialized;
      },
      iterations: 100,
      featureName: 'nfc-navigation',
      propertyNumber: 3,
      propertyText: 'Route Calculation Optimality',
    );

    // Additional property test for NavigationInstruction serialization
    createPropertyTest<NavigationInstruction>(
      description: 'NavigationInstruction serialization round-trip preserves data',
      generator: NavigationInstructionGenerator(),
      property: (instruction) {
        final json = instruction.toJson();
        final deserialized = NavigationInstruction.fromJson(json);
        return instruction == deserialized;
      },
      iterations: 100,
    );

    // Property test for route validation consistency
    createPropertyTest<Route>(
      description: 'Valid routes maintain consistency after operations',
      generator: RouteGenerator(),
      property: (route) {
        // A properly generated route should be valid
        if (!route.isValid()) return false;
        
        // Route should contain its start and end locations
        if (!route.containsLocation(route.startLocationId)) return false;
        if (!route.containsLocation(route.endLocationId)) return false;
        
        // Start location should be at index 0
        if (route.getLocationIndex(route.startLocationId) != 0) return false;
        
        // End location should be at the last index
        final lastIndex = route.pathLocationIds.length - 1;
        if (route.getLocationIndex(route.endLocationId) != lastIndex) return false;
        
        return true;
      },
      iterations: 100,
    );

    // Property test for enum serialization
    createPropertyTest<InstructionType>(
      description: 'InstructionType serialization round-trip is consistent',
      generator: InstructionTypeGenerator(),
      property: (instructionType) {
        final json = instructionType.toJson();
        final deserialized = InstructionType.fromJson(json);
        return instructionType == deserialized;
      },
      iterations: 100,
    );

    createPropertyTest<Direction>(
      description: 'Direction serialization round-trip is consistent',
      generator: DirectionGenerator(),
      property: (direction) {
        final json = direction.toJson();
        final deserialized = Direction.fromJson(json);
        return direction == deserialized;
      },
      iterations: 100,
    );

    // Unit tests for specific edge cases
    group('Unit Tests', () {
      test('Route validation works correctly', () {
        final validRoute = Route(
          id: 'route1',
          startLocationId: 'start',
          endLocationId: 'end',
          pathLocationIds: const ['start', 'middle', 'end'],
          estimatedDistance: 100.0,
          estimatedTime: const Duration(minutes: 5),
          instructions: const [
            NavigationInstruction(
              id: 'inst1',
              type: InstructionType.start,
              description: 'Start here',
              fromLocationId: 'start',
              toLocationId: 'middle',
              direction: Direction.forward,
              distance: 50.0,
            ),
            NavigationInstruction(
              id: 'inst2',
              type: InstructionType.destination,
              description: 'Arrive at destination',
              fromLocationId: 'middle',
              toLocationId: 'end',
              direction: Direction.forward,
              distance: 50.0,
            ),
          ],
        );

        expect(validRoute.isValid(), isTrue);
        expect(validRoute.calculateTotalDistance(), equals(100.0));
      });

      test('Route getNextInstruction works correctly', () {
        final route = Route(
          id: 'route1',
          startLocationId: 'start',
          endLocationId: 'end',
          pathLocationIds: const ['start', 'end'],
          estimatedDistance: 50.0,
          estimatedTime: const Duration(minutes: 2),
          instructions: const [
            NavigationInstruction(
              id: 'inst1',
              type: InstructionType.start,
              description: 'Go to end',
              fromLocationId: 'start',
              toLocationId: 'end',
              direction: Direction.forward,
              distance: 50.0,
            ),
          ],
        );

        final nextInstruction = route.getNextInstruction('start');
        expect(nextInstruction, isNotNull);
        expect(nextInstruction!.fromLocationId, equals('start'));
        expect(nextInstruction.toLocationId, equals('end'));

        final noInstruction = route.getNextInstruction('nonexistent');
        expect(noInstruction, isNull);
      });

      test('Route copyWith creates proper copy', () {
        final original = Route(
          id: 'route1',
          startLocationId: 'start',
          endLocationId: 'end',
          pathLocationIds: const ['start', 'end'],
          estimatedDistance: 50.0,
          estimatedTime: const Duration(minutes: 2),
          instructions: const [],
        );

        final copy = original.copyWith(estimatedDistance: 75.0);

        expect(copy.id, equals(original.id));
        expect(copy.estimatedDistance, equals(75.0));
        expect(copy.estimatedTime, equals(original.estimatedTime));
        expect(copy != original, isTrue);
      });

      test('Enum fromJson handles invalid values gracefully', () {
        expect(InstructionType.fromJson('invalid'), equals(InstructionType.straight));
        expect(Direction.fromJson('invalid'), equals(Direction.forward));
      });
    });
  });
}