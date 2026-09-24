// Static content: routine pictograms and the ready-made routines.

import '../models/models.dart';

/// Icon key -> friendly label. Images are `assets/icons/<key>.png`
/// (Noto Color Emoji, Apache 2.0; see scripts/icons.txt).
const iconLabels = <String, String>{
  'wake_up': 'Wake up',
  'toilet': 'Toilet',
  'wash_hands': 'Wash hands',
  'toothbrush': 'Brush teeth',
  'shower': 'Shower',
  'bath': 'Bath',
  'clothes': 'Get dressed',
  'shoes': 'Shoes',
  'breakfast': 'Breakfast',
  'meal': 'Meal',
  'snack': 'Snack',
  'drink': 'Drink',
  'backpack': 'Backpack',
  'car': 'Car',
  'bus': 'Bus',
  'school': 'School',
  'teacher': 'Teacher',
  'book': 'Books',
  'story': 'Story',
  'play': 'Play',
  'park': 'Park',
  'doctor': 'Doctor',
  'hospital': 'Clinic',
  'waiting': 'Wait',
  'tooth': 'Dentist',
  'haircut': 'Haircut',
  'scissors': 'Scissors',
  'shop': 'Shopping',
  'home': 'Home',
  'moon': 'Night',
  'bed': 'Bed',
  'sleep': 'Sleep',
  'hug': 'Hug',
  'music': 'Music',
  'tv': 'TV',
  'tablet': 'Tablet',
  'comb': 'Comb hair',
  'medicine': 'Medicine',
  'stethoscope': 'Check-up',
  'wave': 'Say hello',
  'star': 'Star',
  'calm': 'Calm down',
  'sun': 'Outside',
  'swim': 'Swim',
  'turtle': 'Sammy',
  'gift': 'Treat',
  'ice_cream': 'Ice cream',
  'paint': 'Art',
  'bubbles': 'Bubbles',
  'headphones': 'Headphones',
};

String iconAsset(String key) =>
    'assets/icons/${iconLabels.containsKey(key) ? key : 'star'}.png';

class TemplateStep {
  final String title;
  final String icon;
  final String story;
  const TemplateStep(this.title, this.icon, [this.story = '']);
}

class RoutineTemplate {
  final String title;
  final String icon;
  final List<TemplateStep> steps;
  const RoutineTemplate(this.title, this.icon, this.steps);

  Routine build(String childId) => Routine(
    id: newId('routine'),
    childId: childId,
    title: title,
    iconKey: icon,
    steps: [
      for (final s in steps)
        RoutineStep(id: newId('step'), title: s.title, iconKey: s.icon, story: s.story),
    ],
  );
}

const routineTemplates = <RoutineTemplate>[
  RoutineTemplate('Morning Routine', 'wake_up', [
    TemplateStep('Wake up', 'wake_up', 'Good morning! I open my eyes and stretch.'),
    TemplateStep('Use the toilet', 'toilet'),
    TemplateStep('Brush teeth', 'toothbrush', 'I brush my top teeth and my bottom teeth.'),
    TemplateStep('Get dressed', 'clothes'),
    TemplateStep('Eat breakfast', 'breakfast'),
  ]),
  RoutineTemplate('Going to School', 'school', [
    TemplateStep('Put on shoes', 'shoes'),
    TemplateStep('Take my backpack', 'backpack'),
    TemplateStep('Ride to school', 'bus', 'I sit in my seat. I can look out of the window.'),
    TemplateStep('Say hello to my teacher', 'teacher', 'My teacher is happy to see me.'),
  ]),
  RoutineTemplate('Visiting the Doctor', 'hospital', [
    TemplateStep('Put on shoes', 'shoes'),
    TemplateStep('Ride in the car', 'car'),
    TemplateStep('Wait in the waiting room', 'waiting', 'I wait in a chair. I can read or listen to music while I wait.'),
    TemplateStep('See the doctor', 'doctor', 'The doctor listens to my heart. It might feel cold. That is okay.'),
    TemplateStep('Go home', 'home'),
  ]),
  RoutineTemplate('Going to the Dentist', 'tooth', [
    TemplateStep('Ride in the car', 'car'),
    TemplateStep('Wait my turn', 'waiting'),
    TemplateStep('Sit in the big chair', 'tooth', 'The chair goes up and back. A bright light helps the dentist see.'),
    TemplateStep('Open wide', 'toothbrush', 'The dentist counts my teeth. It might tickle.'),
    TemplateStep('All finished', 'star'),
  ]),
  RoutineTemplate('Haircut', 'haircut', [
    TemplateStep('Sit in the chair', 'waiting'),
    TemplateStep('Cape on', 'clothes', 'A cape keeps the hair off my clothes.'),
    TemplateStep('Snip snip', 'scissors', 'The scissors make a snipping sound. I can hold still and breathe slowly.'),
    TemplateStep('Look in the mirror', 'haircut'),
  ]),
  RoutineTemplate('Bath Time', 'bath', [
    TemplateStep('Clothes off', 'clothes'),
    TemplateStep('Get in the bath', 'bath', 'The water is warm.'),
    TemplateStep('Wash my body', 'bubbles'),
    TemplateStep('Dry with a towel', 'hug'),
    TemplateStep('Put on pyjamas', 'moon'),
  ]),
  RoutineTemplate('Shopping Trip', 'shop', [
    TemplateStep('Put on shoes', 'shoes'),
    TemplateStep('Ride in the car', 'car'),
    TemplateStep('Push the trolley', 'shop', 'The shop can be busy and noisy. I can wear my headphones.'),
    TemplateStep('Pay and go home', 'home'),
  ]),
  RoutineTemplate('Bedtime Routine', 'moon', [
    TemplateStep('Put on pyjamas', 'moon'),
    TemplateStep('Brush teeth', 'toothbrush'),
    TemplateStep('Read a story', 'story'),
    TemplateStep('Goodnight hug', 'hug'),
    TemplateStep('Lights off and sleep', 'bed', 'My room is dark and quiet. I close my eyes and breathe slowly.'),
  ]),
];

/// Human names for palettes and sounds (dashboard, PDF, canvas chips).
const paletteNames = {
  'lavender': 'Lavender',
  'mint': 'Mint',
  'sand': 'Warm Sand',
  'blue': 'Powder Blue',
};

const soundTitles = {
  'hum': 'Warm Hum',
  'rain': 'Soft Rain',
  'ocean': 'Ocean Waves',
  'marimba': 'Marimba Lullaby',
};

const modeNames = {
  'flow_canvas': 'Flow Canvas',
  'sounds': 'Soothing Sounds',
  'routine': 'Visual Routine',
  'wait_timer': 'Wait Timer',
};
