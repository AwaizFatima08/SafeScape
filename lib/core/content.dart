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
  'mosque': 'Mosque',
  'prayer': 'Prayer',
  'family': 'Family',
  'playground': 'Playground',
  'yawn': 'Sleepy',
  'quiet': 'Quiet',
  'soap': 'Soap',
  'face_calm': 'Calm',
  'face_happy': 'Happy',
  'face_sad': 'Sad',
  'face_upset': 'Upset',
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
  RoutineTemplate('Prayer Time', 'mosque', [
    TemplateStep('Wash for wudu', 'wash_hands', 'I wash my hands, face and feet with cool water.'),
    TemplateStep('Lay out the mat', 'prayer'),
    TemplateStep('Stand quietly', 'quiet', 'Everyone is quiet now. I can stand next to my family.'),
    TemplateStep('Pray together', 'prayer', 'We bow and sit together. It is calm.'),
    TemplateStep('All finished', 'star'),
  ]),
  RoutineTemplate('Nap Time', 'yawn', [
    TemplateStep('Close the curtains', 'moon'),
    TemplateStep('Lie down', 'bed', 'The bed is soft. I can hold my toy.'),
    TemplateStep('Quiet sounds', 'headphones', 'Soft sounds help me rest.'),
    TemplateStep('Rest my eyes', 'sleep'),
  ]),
  RoutineTemplate('Visiting Family', 'family', [
    TemplateStep('Put on shoes', 'shoes'),
    TemplateStep('Ride in the car', 'car'),
    TemplateStep('Say salaam', 'wave', 'I say salaam. I can wave instead of hugging if I like.'),
    TemplateStep('Snack together', 'snack'),
    TemplateStep('Quiet corner if I need it', 'calm', 'If it gets loud, I can sit in a quiet corner and breathe.'),
    TemplateStep('Go home', 'home'),
  ]),
  RoutineTemplate('Playground', 'playground', [
    TemplateStep('Put on shoes', 'shoes'),
    TemplateStep('Walk to the park', 'park'),
    TemplateStep('Wait for my turn', 'waiting', 'Other children are playing too. I wait, then it is my turn.'),
    TemplateStep('Slide and swing', 'playground'),
    TemplateStep('Drink some water', 'drink'),
    TemplateStep('Time to go home', 'home'),
  ]),
  RoutineTemplate('Wash Hands', 'soap', [
    TemplateStep('Water on', 'wash_hands'),
    TemplateStep('Soap and rub', 'soap', 'I rub my palms, the backs, and between my fingers.'),
    TemplateStep('Rinse', 'bubbles'),
    TemplateStep('Dry', 'hug'),
    TemplateStep('All clean', 'star'),
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
  'brown': 'Deep Brown Noise',
  'fan': 'Quiet Fan',
  'heartbeat': 'Slow Heartbeat',
  'musicbox': 'Music Box',
};

const modeNames = {
  'flow_canvas': 'Flow Canvas',
  'sounds': 'Soothing Sounds',
  'routine': 'Visual Routine',
  'wait_timer': 'Wait Timer',
  'breathing': 'Breathing Buddy',
  'bubbles': 'Bubble Pop',
  'feeling': 'Feelings Check-in',
};

/// Breathing Buddy patterns: seconds in / hold / out. Picked by picture.
class BreathPattern {
  final String id;
  final String title;
  final String inLabel;
  final String outLabel;
  final double inhale;
  final double hold;
  final double exhale;
  const BreathPattern(this.id, this.title, this.inLabel, this.outLabel, this.inhale, this.hold, this.exhale);
  double get cycle => inhale + hold + exhale;
}

const breathPatterns = [
  BreathPattern('balloon', 'Balloon', 'Breathe in', 'Breathe out', 4, 0, 6),
  BreathPattern('flower', 'Flower & Candle', 'Smell the flower', 'Blow the candle', 3, 0, 5),
  BreathPattern('box', 'Box', 'Breathe in', 'Breathe out', 4, 4, 4),
];

const breathPatternNames = {'balloon': 'Balloon', 'flower': 'Flower & Candle', 'box': 'Box'};

/// Feelings Check-in: four faces, and the calming tool Sammy suggests.
class Feeling {
  final String id;
  final String label;
  final String icon;
  final String sammySays;
  final String suggestedMode; // hub route the suggestion opens
  final String suggestionLabel;
  const Feeling(this.id, this.label, this.icon, this.sammySays, this.suggestedMode, this.suggestionLabel);
}

const feelings = [
  Feeling('calm', 'Calm', 'face_calm', 'Lovely and calm. Shall we listen to a soft sound?', 'sounds', 'Soothing Sounds'),
  Feeling('happy', 'Happy', 'face_happy', 'Happy! Let\'s make some gentle waves.', 'flow_canvas', 'Calming Canvas'),
  Feeling('sad', 'Sad', 'face_sad', 'It is okay to feel sad. Let\'s breathe together, slowly.', 'breathing', 'Breathing Buddy'),
  Feeling('upset', 'Upset', 'face_upset', 'That is a big feeling. Let\'s pop some slow bubbles.', 'bubbles', 'Bubble Pop'),
];

const feelingNames = {'calm': 'Calm', 'happy': 'Happy', 'sad': 'Sad', 'upset': 'Upset'};
