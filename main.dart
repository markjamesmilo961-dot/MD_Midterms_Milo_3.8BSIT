import 'dart:io';

class InputEnded implements Exception {}

mixin Timestamped {
  final DateTime _createdAt = DateTime.now();

  String get createdLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_createdAt.year}-${two(_createdAt.month)}-${two(_createdAt.day)} '
        '${two(_createdAt.hour)}:${two(_createdAt.minute)}';
  }
}

abstract class LearningResource with Timestamped {
  final String _id;
  final String _title;
  final int _hours;
  final int _capacity;
  final List<String> _enrolledIds = [];

  LearningResource(this._id, this._title, this._hours, this._capacity);

  String get id => _id;
  String get title => _title;
  int get hours => _hours;
  int get capacity => _capacity;
  int get seatsLeft => _capacity - _enrolledIds.length;
  bool get isFull => seatsLeft <= 0;
  List<String> get enrolledIds => List.unmodifiable(_enrolledIds);

  String get type;

  double computeFee();

  bool enroll(String participantId) {
    if (isFull || _enrolledIds.contains(participantId)) {
      return false;
    }
    _enrolledIds.add(participantId);
    return true;
  }

  String describe() {
    return '[$_id] $type: $_title | $_hours hr | '
        'Fee: PHP ${computeFee().toStringAsFixed(2)} | '
        'Seats left: $seatsLeft/$_capacity | Added: $createdLabel';
  }
}

class Workshop extends LearningResource {
  final double _ratePerHour;
  final double _materialsFee;

  Workshop(
    String id,
    String title,
    int hours,
    int capacity,
    this._ratePerHour,
    this._materialsFee,
  ) : super(id, title, hours, capacity);

  @override
  String get type => 'Workshop';

  @override
  double computeFee() => (hours * _ratePerHour) + _materialsFee;
}

class OnlineCourse extends LearningResource {
  final int _modules;
  final double _pricePerModule;

  OnlineCourse(
    String id,
    String title,
    int hours,
    int capacity,
    this._modules,
    this._pricePerModule,
  ) : super(id, title, hours, capacity);

  @override
  String get type => 'Online Course';

  @override
  double computeFee() => _modules * _pricePerModule;

  @override
  String describe() => '${super.describe()} | Modules: $_modules';
}

class Participant with Timestamped {
  final String _id;
  final String _name;
  bool _isMember;
  final List<String> _enrolledResourceIds = [];

  static const double memberDiscount = 0.20;

  Participant(this._id, this._name, {bool isMember = false})
    : _isMember = isMember;

  String get id => _id;
  String get name => _name;
  bool get isMember => _isMember;
  List<String> get enrolledResourceIds =>
      List.unmodifiable(_enrolledResourceIds);

  void upgradeToMember() {
    _isMember = true;
  }

  void addEnrollment(String resourceId) {
    if (!_enrolledResourceIds.contains(resourceId)) {
      _enrolledResourceIds.add(resourceId);
    }
  }

  double amountDue(double fee) {
    final double discount = _isMember ? memberDiscount : 0.0;
    return fee - (fee * discount);
  }

  String describe() {
    final String status = _isMember ? 'Member' : 'Regular';
    return '[$_id] $_name | $status | '
        'Enrollments: ${_enrolledResourceIds.length} | Registered: $createdLabel';
  }
}

class LearningCenter {
  final Map<String, LearningResource> _resources = {};
  final Map<String, Participant> _participants = {};
  final List<String> _activityLog = [];
  int _resourceCounter = 0;
  int _participantCounter = 0;

  String nextResourceId() {
    _resourceCounter++;
    return 'R${_resourceCounter.toString().padLeft(3, '0')}';
  }

  String nextParticipantId() {
    _participantCounter++;
    return 'P${_participantCounter.toString().padLeft(3, '0')}';
  }

  void addResource(LearningResource resource) {
    _resources[resource.id] = resource;
  }

  void addParticipant(Participant participant) {
    _participants[participant.id] = participant;
  }

  LearningResource? findResource(String id) => _resources[id];
  Participant? findParticipant(String id) => _participants[id];

  bool get hasResources => _resources.isNotEmpty;
  bool get hasParticipants => _participants.isNotEmpty;

  String enrollParticipant(String participantId, String resourceId) {
    final participant = findParticipant(participantId);
    final resource = findResource(resourceId);

    if (participant == null)
      return 'Error: Participant $participantId not found.';
    if (resource == null) return 'Error: Resource $resourceId not found.';
    if (resource.isFull) return 'Error: "${resource.title}" is already full.';

    if (!resource.enroll(participant.id)) {
      return 'Error: ${participant.name} is already enrolled in "${resource.title}".';
    }

    participant.addEnrollment(resource.id);
    _activityLog.add('${participant.name} enrolled in ${resource.title}');

    final double due = participant.amountDue(resource.computeFee());
    return 'Success: ${participant.name} enrolled in "${resource.title}". '
        'Amount due: PHP ${due.toStringAsFixed(2)}';
  }

  void showResources() {
    for (final LearningResource r in _resources.values) {
      print(r.describe());
    }
  }

  void showParticipants() {
    for (final Participant p in _participants.values) {
      print(p.describe());
    }
  }

  void showBilling(Participant participant) {
    final ids = participant.enrolledResourceIds;
    if (ids.isEmpty) {
      print('${participant.name} has no enrollments yet.');
      return;
    }

    double subtotal = 0;
    print('--- Billing for ${participant.name} ---');
    for (final String resourceId in ids) {
      final resource = _resources[resourceId];
      if (resource == null) continue;
      final double fee = resource.computeFee();
      subtotal += fee;
      print(
        '  ${resource.title} (${resource.type}): PHP ${fee.toStringAsFixed(2)}',
      );
    }
    final double total = participant.amountDue(subtotal);
    final double saved = subtotal - total;
    print('Subtotal : PHP ${subtotal.toStringAsFixed(2)}');
    print(
      'Discount : PHP ${saved.toStringAsFixed(2)}'
      '${participant.isMember ? " (member 20%)" : ""}',
    );
    print('TOTAL DUE: PHP ${total.toStringAsFixed(2)}');
  }

  void showActivityLog() {
    if (_activityLog.isEmpty) {
      print('No enrollment activity yet.');
      return;
    }
    for (int i = 0; i < _activityLog.length; i++) {
      print('${i + 1}. ${_activityLog[i]}');
    }
  }
}

String readText(String prompt) {
  stdout.write(prompt);
  final String? line = stdin.readLineSync();
  if (line == null) throw InputEnded();
  return line.trim();
}

String readRequiredText(String prompt) {
  while (true) {
    final String value = readText(prompt);
    if (value.isNotEmpty) return value;
    print('Input cannot be empty. Please try again.');
  }
}

int readInt(String prompt, int min, int max) {
  while (true) {
    final int? value = int.tryParse(readText(prompt));
    if (value == null) {
      print('Invalid input. Please enter a whole number.');
    } else if (value < min || value > max) {
      print('Please enter a number between $min and $max.');
    } else {
      return value;
    }
  }
}

double readMoney(String prompt) {
  while (true) {
    try {
      final double value = double.parse(readText(prompt));
      if (value < 0) {
        print('Amount cannot be negative.');
        continue;
      }
      return value;
    } on FormatException {
      print('Invalid amount. Please enter a number such as 250 or 99.50.');
    }
  }
}

bool readYesNo(String prompt) {
  while (true) {
    final String answer = readText('$prompt (y/n): ').toLowerCase();
    if (answer == 'y' || answer == 'yes') return true;
    if (answer == 'n' || answer == 'no') return false;
    print('Please answer y or n.');
  }
}

void printTitle() {
  print('==========================================');
  print('        LEARNING CENTER MANAGER');
  print('==========================================');
}

void printMenu() {
  print('\n----------------- MENU -----------------');
  print('1. Add learning resource');
  print('2. Register participant');
  print('3. Enroll participant in a resource');
  print('4. View all resources');
  print('5. View all participants');
  print('6. View participant billing');
  print('7. Upgrade participant to member');
  print('8. View enrollment activity log');
  print('0. Exit');
}

void addResourceFlow(LearningCenter center) {
  print('\nResource type:  1) Workshop   2) Online Course');
  final int kind = readInt('Choose type (1-2): ', 1, 2);

  final String title = readRequiredText('Title: ');
  final int hours = readInt('Duration in hours (1-200): ', 1, 200);
  final int capacity = readInt('Capacity / seats (1-500): ', 1, 500);
  final String id = center.nextResourceId();

  if (kind == 1) {
    final double rate = readMoney('Rate per hour (PHP): ');
    final double materials = readMoney('Materials fee (PHP): ');
    center.addResource(Workshop(id, title, hours, capacity, rate, materials));
  } else {
    final int modules = readInt('Number of modules (1-100): ', 1, 100);
    final double price = readMoney('Price per module (PHP): ');
    center.addResource(
      OnlineCourse(id, title, hours, capacity, modules, price),
    );
  }
  print('Resource added with ID $id.');
}

void registerParticipantFlow(LearningCenter center) {
  final String name = readRequiredText('Participant name: ');
  final bool member = readYesNo('Is this person a member (20% discount)?');
  final String id = center.nextParticipantId();
  center.addParticipant(Participant(id, name, isMember: member));
  print('Participant registered with ID $id.');
}

void enrollFlow(LearningCenter center) {
  if (!center.hasParticipants || !center.hasResources) {
    print('You need at least one participant and one resource first.');
    return;
  }
  center.showParticipants();
  final String pid = readText('Participant ID: ').toUpperCase();
  center.showResources();
  final String rid = readText('Resource ID: ').toUpperCase();
  print(center.enrollParticipant(pid, rid));
}

void billingFlow(LearningCenter center) {
  if (!center.hasParticipants) {
    print('No participants registered yet.');
    return;
  }
  final String pid = readText('Participant ID: ').toUpperCase();
  final participant = center.findParticipant(pid);
  if (participant == null) {
    print('Error: Participant $pid not found.');
    return;
  }
  center.showBilling(participant);
}

void upgradeFlow(LearningCenter center) {
  if (!center.hasParticipants) {
    print('No participants registered yet.');
    return;
  }
  final String pid = readText('Participant ID: ').toUpperCase();
  final participant = center.findParticipant(pid);
  if (participant == null) {
    print('Error: Participant $pid not found.');
  } else if (participant.isMember) {
    print('${participant.name} is already a member.');
  } else {
    participant.upgradeToMember();
    print('${participant.name} is now a member (20% discount applies).');
  }
}

void main() {
  final LearningCenter center = LearningCenter();
  bool running = true;

  printTitle();

  try {
    while (running) {
      printMenu();
      final String choice = readText('Choose an option (0-8): ');

      switch (choice) {
        case '1':
          addResourceFlow(center);
        case '2':
          registerParticipantFlow(center);
        case '3':
          enrollFlow(center);
        case '4':
          if (center.hasResources) {
            center.showResources();
          } else {
            print('No resources added yet.');
          }
        case '5':
          if (center.hasParticipants) {
            center.showParticipants();
          } else {
            print('No participants registered yet.');
          }
        case '6':
          billingFlow(center);
        case '7':
          upgradeFlow(center);
        case '8':
          center.showActivityLog();
        case '0':
          running = false;
          print('Thank you for using Learning Center Manager. Goodbye!');
        default:
          print(
            'Invalid choice "$choice". Please select a number from 0 to 8.',
          );
      }
    }
  } on InputEnded {
    print('\nInput ended. Goodbye!');
  } catch (e) {
    print('An unexpected error occurred: $e');
  }
}
