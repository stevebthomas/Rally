import Foundation

/// Offline parser that extracts workout data from transcribed text using pattern matching
/// No API or internet required
class OfflineWorkoutParser {

    // Common exercise name variations mapped to canonical names
    private let exerciseAliases: [String: String] = [
        // ============================================
        // CHEST
        // ============================================
        "bench press": "Bench Press",
        "bench": "Bench Press",
        "flat bench": "Bench Press",
        "flat bench press": "Bench Press",
        "flat barbell bench press": "Bench Press",
        "barbell bench press": "Bench Press",
        "barbell bench": "Bench Press",
        "incline bench": "Incline Bench Press",
        "incline bench press": "Incline Bench Press",
        "incline press": "Incline Press",
        "incline dumbbell press": "Incline Dumbbell Press",
        "incline dumbbell": "Incline Dumbbell Press",
        "decline bench": "Decline Bench Press",
        "decline bench press": "Decline Bench Press",
        "decline press": "Decline Press",
        "decline hammer strength": "Decline Hammer Strength Press",
        "decline hammer strength press": "Decline Hammer Strength Press",
        "hammer strength press": "Hammer Strength Press",
        "dumbbell press": "Dumbbell Press",
        "db press": "Dumbbell Press",
        "chest press": "Chest Press",
        "machine chest press": "Machine Chest Press",
        "cable crossover": "Cable Crossover",
        "cable crossovers": "Cable Crossover",
        "crossover": "Cable Crossover",
        "crossovers": "Cable Crossover",
        "high to low cable": "Cable Crossover",
        "low to high cable": "Low Cable Crossover",
        "pec deck": "Pec Deck Fly",
        "pec deck fly": "Pec Deck Fly",
        "pec fly": "Pec Deck Fly",
        "machine fly": "Pec Deck Fly",
        "machine flyes": "Pec Deck Fly",
        "chest fly": "Chest Flyes",
        "chest flyes": "Chest Flyes",
        "flyes": "Chest Flyes",
        "flies": "Chest Flyes",
        "dumbbell fly": "Dumbbell Flyes",
        "dumbbell flyes": "Dumbbell Flyes",
        "db fly": "Dumbbell Flyes",
        "db flyes": "Dumbbell Flyes",
        "cable flyes": "Cable Flyes",
        "cable fly": "Cable Flyes",
        "weighted dips": "Weighted Dips",
        "dips": "Dips",
        "chest dips": "Chest Dips",
        "landmine press": "Landmine Press",
        "landmine": "Landmine Press",
        "push ups": "Push Ups",
        "push-ups": "Push Ups",
        "pushups": "Push Ups",
        "push up": "Push Ups",
        "pushup": "Push Ups",
        "wide push ups": "Wide Push Ups",
        "diamond push ups": "Diamond Push Ups",
        "incline push ups": "Incline Push Ups",
        "decline push ups": "Decline Push Ups",
        "pike push ups": "Pike Push Ups",
        "pike push up": "Pike Push Ups",
        "pike pushups": "Pike Push Ups",
        "pike pushup": "Pike Push Ups",

        // ============================================
        // BACK
        // ============================================
        "deadlift": "Deadlift",
        "deadlifts": "Deadlift",
        "dead lift": "Deadlift",
        "dead lifts": "Deadlift",
        "conventional deadlift": "Conventional Deadlift",
        "conventional deadlifts": "Conventional Deadlift",
        "sumo deadlift": "Sumo Deadlift",
        "sumo deadlifts": "Sumo Deadlift",
        "romanian deadlift": "Romanian Deadlift",
        "romanian deadlifts": "Romanian Deadlift",
        "rdl": "Romanian Deadlift",
        "rdls": "Romanian Deadlift",
        "stiff leg deadlift": "Stiff Leg Deadlift",
        "stiff legged deadlift": "Stiff Leg Deadlift",
        "pull ups": "Pull Ups",
        "pull-ups": "Pull Ups",
        "pullups": "Pull Ups",
        "pull up": "Pull Ups",
        "pullup": "Pull Ups",
        "overhand pull ups": "Pull Ups",
        "wide grip pull ups": "Wide Grip Pull Ups",
        "close grip pull ups": "Close Grip Pull Ups",
        "chin ups": "Chin Ups",
        "chin-ups": "Chin Ups",
        "chinups": "Chin Ups",
        "chin up": "Chin Ups",
        "chinup": "Chin Ups",
        "lat pulldown": "Lat Pulldown",
        "lat pull down": "Lat Pulldown",
        "pulldown": "Lat Pulldown",
        "pull down": "Lat Pulldown",
        "lat pulldowns": "Lat Pulldown",
        "neutral grip pulldown": "Neutral Grip Lat Pulldown",
        "close grip pulldown": "Close Grip Lat Pulldown",
        "wide grip pulldown": "Wide Grip Lat Pulldown",
        "seated cable row": "Seated Cable Row",
        "seated row": "Seated Cable Row",
        "seated rows": "Seated Cable Row",
        "cable row": "Cable Row",
        "cable rows": "Cable Row",
        "low row": "Low Row",
        "rows": "Rows",
        "row": "Rows",
        "barbell row": "Barbell Row",
        "barbell rows": "Barbell Row",
        "bent over row": "Bent Over Row",
        "bent over rows": "Bent Over Row",
        "bent-over row": "Bent Over Row",
        "bent-over barbell row": "Bent Over Barbell Row",
        "bent over barbell row": "Bent Over Barbell Row",
        "pendlay row": "Pendlay Row",
        "pendlay rows": "Pendlay Row",
        "dumbbell row": "Dumbbell Row",
        "dumbbell rows": "Dumbbell Row",
        "db row": "Dumbbell Row",
        "db rows": "Dumbbell Row",
        "one arm row": "One Arm Dumbbell Row",
        "single arm row": "One Arm Dumbbell Row",
        "t-bar row": "T-Bar Row",
        "t bar row": "T-Bar Row",
        "tbar row": "T-Bar Row",
        "t-bar rows": "T-Bar Row",
        "face pull": "Face Pulls",
        "face pulls": "Face Pulls",
        "facepull": "Face Pulls",
        "facepulls": "Face Pulls",
        "back extension": "Back Extensions",
        "back extensions": "Back Extensions",
        "hyperextension": "Hyperextensions",
        "hyperextensions": "Hyperextensions",
        "reverse hyper": "Reverse Hyperextension",
        "good morning": "Good Mornings",
        "good mornings": "Good Mornings",
        "rack pull": "Rack Pulls",
        "rack pulls": "Rack Pulls",

        // ============================================
        // SHOULDERS
        // ============================================
        "shoulder press": "Shoulder Press",
        "overhead press": "Overhead Press",
        "ohp": "Overhead Press",
        "military press": "Military Press",
        "standing press": "Standing Press",
        "seated shoulder press": "Seated Shoulder Press",
        "dumbbell shoulder press": "Dumbbell Shoulder Press",
        "db shoulder press": "Dumbbell Shoulder Press",
        "arnold press": "Arnold Press",
        "arnold": "Arnold Press",
        "lateral raise": "Lateral Raises",
        "lateral raises": "Lateral Raises",
        "side raise": "Lateral Raises",
        "side raises": "Lateral Raises",
        "dumbbell lateral raise": "Lateral Raises",
        "cable lateral raise": "Cable Lateral Raises",
        "machine lateral raise": "Machine Lateral Raises",
        "front raise": "Front Raises",
        "front raises": "Front Raises",
        "dumbbell front raise": "Front Raises",
        "plate front raise": "Plate Front Raises",
        "rear delt": "Rear Delt Flyes",
        "rear delts": "Rear Delt Flyes",
        "rear delt fly": "Rear Delt Flyes",
        "rear delt flyes": "Rear Delt Flyes",
        "reverse fly": "Rear Delt Flyes",
        "reverse flyes": "Rear Delt Flyes",
        "reverse pec deck": "Reverse Pec Deck Fly",
        "reverse pec deck fly": "Reverse Pec Deck Fly",
        "upright row": "Upright Row",
        "upright rows": "Upright Row",
        "shrugs": "Shrugs",
        "shrug": "Shrugs",
        "dumbbell shrugs": "Dumbbell Shrugs",
        "barbell shrugs": "Barbell Shrugs",
        "trap bar shrugs": "Trap Bar Shrugs",

        // ============================================
        // LEGS
        // ============================================
        "squat": "Squats",
        "squats": "Squats",
        "squatted": "Squats",
        "back squat": "Back Squat",
        "back squats": "Back Squat",
        "front squat": "Front Squat",
        "front squats": "Front Squat",
        "goblet squat": "Goblet Squat",
        "goblet squats": "Goblet Squat",
        "bulgarian split squat": "Bulgarian Split Squat",
        "bulgarian split squats": "Bulgarian Split Squat",
        "split squat": "Split Squat",
        "split squats": "Split Squat",
        "hack squat": "Hack Squat",
        "hack squats": "Hack Squat",
        "smith machine squat": "Smith Machine Squat",
        "smith machine": "Smith Machine Press",
        "smith press": "Smith Machine Press",
        "smith machine press": "Smith Machine Press",
        "incline smith": "Incline Smith Machine Press",
        "incline smith machine": "Incline Smith Machine Press",
        "incline smith machine press": "Incline Smith Machine Press",
        "incline smith press": "Incline Smith Machine Press",
        "decline smith": "Decline Smith Machine Press",
        "decline smith machine": "Decline Smith Machine Press",
        "decline smith machine press": "Decline Smith Machine Press",
        "box squat": "Box Squat",
        "box squats": "Box Squat",
        "pause squat": "Pause Squat",
        "leg press": "Leg Press",
        "legpress": "Leg Press",
        "leg presses": "Leg Press",
        "single leg press": "Single Leg Press",
        "lunges": "Lunges",
        "lunge": "Lunges",
        "walking lunges": "Walking Lunges",
        "walking lunge": "Walking Lunges",
        "reverse lunge": "Reverse Lunges",
        "reverse lunges": "Reverse Lunges",
        "dumbbell lunges": "Dumbbell Lunges",
        "barbell lunges": "Barbell Lunges",
        "leg extension": "Leg Extensions",
        "leg extensions": "Leg Extensions",
        "quad extension": "Leg Extensions",
        "leg curl": "Leg Curls",
        "leg curls": "Leg Curls",
        "lying leg curl": "Lying Leg Curl",
        "lying leg curls": "Lying Leg Curl",
        "seated leg curl": "Seated Leg Curl",
        "seated leg curls": "Seated Leg Curl",
        "hamstring curl": "Leg Curls",
        "hamstring curls": "Leg Curls",
        "nordic curl": "Nordic Curls",
        "nordic curls": "Nordic Curls",
        "calf raise": "Calf Raises",
        "calf raises": "Calf Raises",
        "standing calf raise": "Standing Calf Raises",
        "seated calf raise": "Seated Calf Raises",
        "donkey calf raise": "Donkey Calf Raises",
        "donkey calf raises": "Donkey Calf Raises",
        "hip thrust": "Hip Thrusts",
        "hip thrusts": "Hip Thrusts",
        "barbell hip thrust": "Barbell Hip Thrusts",
        "glute bridge": "Glute Bridge",
        "glute bridges": "Glute Bridge",
        "hip abduction": "Hip Abduction",
        "hip adduction": "Hip Adduction",
        "leg raise": "Leg Raises",
        "step up": "Step Ups",
        "step ups": "Step Ups",
        "box step up": "Box Step Ups",

        // ============================================
        // ARMS (Biceps, Triceps, Forearms)
        // ============================================
        // Biceps
        "bicep curl": "Bicep Curls",
        "bicep curls": "Bicep Curls",
        "biceps curl": "Bicep Curls",
        "biceps curls": "Bicep Curls",
        "curls": "Bicep Curls",
        "curl": "Bicep Curls",
        "dumbbell curl": "Dumbbell Curls",
        "dumbbell curls": "Dumbbell Curls",
        "db curl": "Dumbbell Curls",
        "db curls": "Dumbbell Curls",
        "barbell curl": "Barbell Curls",
        "barbell curls": "Barbell Curls",
        "ez bar curl": "EZ Bar Curls",
        "ez bar curls": "EZ Bar Curls",
        "ez-bar curl": "EZ Bar Curls",
        "ez-bar curls": "EZ Bar Curls",
        "preacher curl": "Preacher Curls",
        "preacher curls": "Preacher Curls",
        "ez bar preacher curl": "EZ Bar Preacher Curls",
        "ez-bar preacher curl": "EZ Bar Preacher Curls",
        "hammer curl": "Hammer Curls",
        "hammer curls": "Hammer Curls",
        "concentration curl": "Concentration Curls",
        "concentration curls": "Concentration Curls",
        "incline curl": "Incline Curls",
        "incline curls": "Incline Curls",
        "incline dumbbell curl": "Incline Dumbbell Curls",
        "spider curl": "Spider Curls",
        "spider curls": "Spider Curls",
        "cable curl": "Cable Curls",
        "cable curls": "Cable Curls",
        "21s": "21s",
        "twenty ones": "21s",

        // Triceps
        "tricep extension": "Tricep Extensions",
        "tricep extensions": "Tricep Extensions",
        "triceps extension": "Tricep Extensions",
        "triceps extensions": "Tricep Extensions",
        "overhead tricep extension": "Overhead Tricep Extensions",
        "overhead extension": "Overhead Tricep Extensions",
        "single arm tricep extension": "Single Arm Tricep Extension",
        "single arm tricep extensions": "Single Arm Tricep Extension",
        "one arm tricep extension": "Single Arm Tricep Extension",
        "one arm tricep extensions": "Single Arm Tricep Extension",
        "single arm extension": "Single Arm Tricep Extension",
        "one arm extension": "Single Arm Tricep Extension",
        "dumbbell tricep extension": "Dumbbell Tricep Extension",
        "dumbbell tricep extensions": "Dumbbell Tricep Extension",
        "db tricep extension": "Dumbbell Tricep Extension",
        "tricep pushdown": "Tricep Pushdowns",
        "tricep pushdowns": "Tricep Pushdowns",
        "triceps pushdown": "Tricep Pushdowns",
        "pushdown": "Tricep Pushdowns",
        "pushdowns": "Tricep Pushdowns",
        "rope pushdown": "Rope Pushdowns",
        "rope pushdowns": "Rope Pushdowns",
        "tricep rope pushdown": "Tricep Rope Pushdown",
        "cable pushdown": "Cable Pushdowns",
        "skull crusher": "Skull Crushers",
        "skull crushers": "Skull Crushers",
        "skullcrushers": "Skull Crushers",
        "skullcrusher": "Skull Crushers",
        "lying tricep extension": "Skull Crushers",
        "tricep dips": "Tricep Dips",
        "bench dips": "Bench Dips",
        "close grip bench": "Close Grip Bench Press",
        "close grip bench press": "Close Grip Bench Press",
        "close-grip bench press": "Close Grip Bench Press",
        "cgbp": "Close Grip Bench Press",
        "tricep kickback": "Tricep Kickbacks",
        "tricep kickbacks": "Tricep Kickbacks",
        "kickback": "Tricep Kickbacks",
        "kickbacks": "Tricep Kickbacks",
        "diamond pushups": "Diamond Push Ups",

        // Forearms
        "wrist curl": "Wrist Curls",
        "wrist curls": "Wrist Curls",
        "barbell wrist curl": "Barbell Wrist Curls",
        "barbell wrist curls": "Barbell Wrist Curls",
        "dumbbell wrist curl": "Dumbbell Wrist Curls",
        "dumbbell wrist curls": "Dumbbell Wrist Curls",
        "reverse wrist curl": "Reverse Wrist Curls",
        "reverse wrist curls": "Reverse Wrist Curls",
        "behind the back wrist curl": "Behind the Back Wrist Curls",
        "behind back wrist curl": "Behind the Back Wrist Curls",
        "reverse curl": "Reverse Curls",
        "reverse curls": "Reverse Curls",
        "reverse barbell curl": "Reverse Barbell Curls",
        "reverse barbell curls": "Reverse Barbell Curls",
        "zottman curl": "Zottman Curls",
        "zottman curls": "Zottman Curls",
        "zottmans": "Zottman Curls",
        "finger curl": "Finger Curls",
        "finger curls": "Finger Curls",
        "wrist roller": "Wrist Roller",
        "wrist roll": "Wrist Roller",
        "forearm roller": "Wrist Roller",
        "hand gripper": "Hand Gripper",
        "hand grippers": "Hand Gripper",
        "gripper": "Hand Gripper",
        "grippers": "Hand Gripper",
        "grip trainer": "Hand Gripper",
        "captains of crush": "Hand Gripper",
        "grip strength": "Hand Gripper",
        "static hold": "Static Holds",
        "static holds": "Static Holds",
        "barbell hold": "Barbell Holds",
        "barbell holds": "Barbell Holds",
        "dumbbell hold": "Dumbbell Holds",
        "dumbbell holds": "Dumbbell Holds",
        "farmer walk": "Farmer's Walk",
        "farmer walks": "Farmer's Walk",
        "farmers walk": "Farmer's Walk",
        "farmers walks": "Farmer's Walk",
        "farmer's walk": "Farmer's Walk",
        "farmer carry": "Farmer's Walk",
        "farmer carries": "Farmer's Walk",
        "dead hang": "Dead Hang",
        "dead hangs": "Dead Hang",
        "bar hang": "Dead Hang",
        "hanging": "Dead Hang",
        "towel hang": "Towel Hangs",
        "towel hangs": "Towel Hangs",
        "plate pinch": "Plate Pinch",
        "plate pinches": "Plate Pinch",
        "pinch grip": "Plate Pinch",
        "forearm pronation": "Forearm Pronation",
        "pronation": "Forearm Pronation",
        "forearm supination": "Forearm Supination",
        "supination": "Forearm Supination",
        "wrist extension": "Wrist Extensions",
        "wrist extensions": "Wrist Extensions",
        "wrist flexion": "Wrist Flexion",
        "radial deviation": "Radial Deviation",
        "ulnar deviation": "Ulnar Deviation",

        // ============================================
        // CORE (Abdominals & Obliques)
        // ============================================
        "plank": "Plank",
        "planks": "Plank",
        "side plank": "Side Plank",
        "side planks": "Side Plank",
        "crunch": "Crunches",
        "crunches": "Crunches",
        "cable crunch": "Cable Crunches",
        "cable crunches": "Cable Crunches",
        "sit ups": "Sit Ups",
        "sit-ups": "Sit Ups",
        "situps": "Sit Ups",
        "sit up": "Sit Ups",
        "situp": "Sit Ups",
        "lying leg raises": "Lying Leg Raises",
        "hanging leg raise": "Hanging Leg Raises",
        "hanging leg raises": "Hanging Leg Raises",
        "knee raise": "Knee Raises",
        "knee raises": "Knee Raises",
        "hanging knee raise": "Hanging Knee Raises",
        "russian twist": "Russian Twists",
        "russian twists": "Russian Twists",
        "ab wheel": "Ab Wheel Rollout",
        "ab wheel rollout": "Ab Wheel Rollout",
        "ab rollout": "Ab Wheel Rollout",
        "ab roller": "Ab Wheel Rollout",
        "cable woodchopper": "Cable Woodchoppers",
        "cable woodchoppers": "Cable Woodchoppers",
        "woodchopper": "Cable Woodchoppers",
        "woodchoppers": "Cable Woodchoppers",
        "wood chopper": "Cable Woodchoppers",
        "wood choppers": "Cable Woodchoppers",
        "bicycle crunch": "Bicycle Crunches",
        "bicycle crunches": "Bicycle Crunches",
        "mountain climber": "Mountain Climbers",
        "mountain climbers": "Mountain Climbers",
        "dead bug": "Dead Bug",
        "dead bugs": "Dead Bug",
        "bird dog": "Bird Dog",
        "bird dogs": "Bird Dog",
        "v up": "V Ups",
        "v ups": "V Ups",
        "v-up": "V Ups",
        "v-ups": "V Ups",
        "toe touch": "Toe Touches",
        "toe touches": "Toe Touches",
        "flutter kick": "Flutter Kicks",
        "flutter kicks": "Flutter Kicks",
        "hollow hold": "Hollow Hold",
        "wall sit": "Wall Sit",
        "wall sits": "Wall Sit",
        "wall squat": "Wall Sit",
        "wall squats": "Wall Sit",
        "l sit": "L-Sit",
        "l-sit": "L-Sit",
        "l sits": "L-Sit",
        "front lever": "Front Lever",
        "front levers": "Front Lever",
        "back lever": "Back Lever",
        "back levers": "Back Lever",
        "hollow body hold": "Hollow Hold",

        // ============================================
        // FULL BODY / COMPOUND
        // ============================================
        "clean": "Clean",
        "cleans": "Clean",
        "power clean": "Power Clean",
        "power cleans": "Power Clean",
        "hang clean": "Hang Clean",
        "hang cleans": "Hang Clean",
        "clean and jerk": "Clean and Jerk",
        "clean and press": "Clean and Press",
        "snatch": "Snatch",
        "snatches": "Snatch",
        "power snatch": "Power Snatch",
        "thruster": "Thrusters",
        "thrusters": "Thrusters",
        "burpee": "Burpees",
        "burpees": "Burpees",
        "burpee's": "Burpees",
        "kettlebell swing": "Kettlebell Swings",
        "kettlebell swings": "Kettlebell Swings",
        "kb swing": "Kettlebell Swings",
        "kb swings": "Kettlebell Swings",
        "kettlebell clean": "Kettlebell Clean",
        "kb clean": "Kettlebell Clean",
        "kettlebell press": "Kettlebell Press",
        "kb press": "Kettlebell Press",
        "kettlebell snatch": "Kettlebell Snatch",
        "kb snatch": "Kettlebell Snatch",
        "kettlebell row": "Kettlebell Row",
        "kb row": "Kettlebell Row",
        "kettlebell deadlift": "Kettlebell Deadlift",
        "kb deadlift": "Kettlebell Deadlift",
        "kettlebell squat": "Kettlebell Squat",
        "kb squat": "Kettlebell Squat",
        "kettlebell goblet squat": "Goblet Squat",
        "kettlebell lunge": "Kettlebell Lunges",
        "kb lunge": "Kettlebell Lunges",
        "kettlebell lunges": "Kettlebell Lunges",
        "kb lunges": "Kettlebell Lunges",
        "kettlebell curl": "Kettlebell Curls",
        "kb curl": "Kettlebell Curls",
        "kettlebell curls": "Kettlebell Curls",
        "kb curls": "Kettlebell Curls",
        "kettlebell tricep extension": "Kettlebell Tricep Extension",
        "kb tricep extension": "Kettlebell Tricep Extension",
        "kettlebell windmill": "Kettlebell Windmill",
        "kb windmill": "Kettlebell Windmill",
        "kettlebell halo": "Kettlebell Halo",
        "kb halo": "Kettlebell Halo",
        "turkish get up": "Turkish Get Up",
        "turkish getup": "Turkish Get Up",
        "battle rope": "Battle Ropes",
        "battle ropes": "Battle Ropes",
        "box jump": "Box Jumps",
        "box jumps": "Box Jumps",
        "jumping jack": "Jumping Jacks",
        "jumping jacks": "Jumping Jacks",
    ]

    // Bodyweight exercises (no weight needed)
    private let bodyweightExercises: Set<String> = [
        "Push Ups", "Wide Push Ups", "Diamond Push Ups", "Incline Push Ups", "Decline Push Ups", "Pike Push Ups",
        "Pull Ups", "Wide Grip Pull Ups", "Close Grip Pull Ups", "Chin Ups",
        "Dips", "Chest Dips", "Tricep Dips", "Bench Dips",
        "Plank", "Side Plank", "Hollow Hold",
        "Crunches", "Bicycle Crunches", "Sit Ups", "V Ups",
        "Leg Raises", "Lying Leg Raises", "Hanging Leg Raises", "Knee Raises", "Hanging Knee Raises",
        "Russian Twists", "Mountain Climbers", "Flutter Kicks",
        "Dead Bug", "Bird Dog", "Toe Touches",
        "Lunges", "Walking Lunges", "Reverse Lunges",
        "Glute Bridge", "Hip Thrust",
        "Burpees", "Jumping Jacks", "Box Jumps",
        "Dead Hang", "Nordic Curls",
        "Back Extensions", "Hyperextensions",
    ]

    // Timed exercises (measured by duration, not reps)
    private let timedExercises: Set<String> = [
        "Plank", "Side Plank", "Hollow Hold",
        "Dead Hang", "Towel Hangs", "Bar Hang",
        "Wall Sit", "L-Sit", "Front Lever", "Back Lever",
        "Static Holds", "Barbell Holds", "Dumbbell Holds",
        "Farmer's Walk",
        "Battle Ropes",
    ]

    // Set type keywords for detection
    private let setTypeKeywords: [String: SetType] = [
        "drop set": .dropSet,
        "dropset": .dropSet,
        "drop": .dropSet,
        "superset": .superset,
        "super set": .superset,
        "rest pause": .restPause,
        "rest-pause": .restPause,
        "amrap": .amrap,
        "as many as possible": .amrap,
        "to failure": .toFailure,
        "til failure": .toFailure,
        "until failure": .toFailure,
        "failed": .toFailure,
        "warm up": .warmup,
        "warmup": .warmup,
        "warm-up": .warmup,
        "cluster": .cluster,
        "cluster set": .cluster,
    ]

    // Equipment keywords for detection
    private let equipmentKeywords: [String: Equipment] = [
        "barbell": .barbell,
        "bar": .barbell,
        "bb": .barbell,
        "dumbbell": .dumbbell,
        "dumbbells": .dumbbell,
        "db": .dumbbell,
        "dbs": .dumbbell,
        "cable": .cable,
        "cables": .cable,
        "machine": .machine,
        "kettlebell": .kettlebell,
        "kb": .kettlebell,
        "kettlebells": .kettlebell,
        "band": .resistanceBand,
        "bands": .resistanceBand,
        "resistance band": .resistanceBand,
        "smith": .smithMachine,
        "smith machine": .smithMachine,
        "trap bar": .trapBar,
        "hex bar": .trapBar,
        "ez bar": .ezBar,
        "ez curl bar": .ezBar,
        "bodyweight": .bodyweight,
        "body weight": .bodyweight,
        "bw": .bodyweight,
    ]

    // Grip keywords for detection
    private let gripKeywords: [String: GripType] = [
        "wide grip": .wide,
        "wide": .wide,
        "narrow grip": .narrow,
        "narrow": .narrow,
        "close grip": .narrow,
        "close": .narrow,
        "underhand grip": .underhand,
        "underhand": .underhand,
        "supinated": .underhand,
        "supinated grip": .underhand,
        "overhand grip": .overhand,
        "overhand": .overhand,
        "pronated": .overhand,
        "pronated grip": .overhand,
        "neutral grip": .neutral,
        "neutral": .neutral,
        "hammer grip": .neutral,
        "mixed grip": .mixed,
        "mixed": .mixed,
        "alternating grip": .mixed,
        "reverse grip": .reverse,
        "reverse": .reverse,
    ]

    // Stance keywords for detection
    private let stanceKeywords: [String: StanceType] = [
        "wide stance": .wide,
        "sumo": .sumo,
        "sumo stance": .sumo,
        "narrow stance": .narrow,
        "staggered stance": .staggered,
        "staggered": .staggered,
        "split stance": .staggered,
        "single leg": .singleLeg,
        "one leg": .singleLeg,
        "unilateral": .singleLeg,
    ]

    // Exercise metadata: equipment and primary muscles
    private let exerciseMetadata: [String: (equipment: Equipment, muscles: [MuscleGroup])] = [
        // CHEST
        "Bench Press": (.barbell, [.chest, .triceps, .shoulders]),
        "Incline Bench Press": (.barbell, [.chest, .shoulders, .triceps]),
        "Decline Bench Press": (.barbell, [.chest, .triceps]),
        "Dumbbell Press": (.dumbbell, [.chest, .triceps, .shoulders]),
        "Incline Dumbbell Press": (.dumbbell, [.chest, .shoulders]),
        "Chest Flyes": (.dumbbell, [.chest]),
        "Dumbbell Flyes": (.dumbbell, [.chest]),
        "Cable Crossover": (.cable, [.chest]),
        "Pec Deck Fly": (.machine, [.chest]),
        "Machine Chest Press": (.machine, [.chest, .triceps]),
        "Push Ups": (.bodyweight, [.chest, .triceps, .shoulders]),

        // BACK
        "Deadlift": (.barbell, [.back, .hamstrings, .glutes]),
        "Romanian Deadlift": (.barbell, [.hamstrings, .glutes, .back]),
        "Pull Ups": (.bodyweight, [.back, .biceps]),
        "Chin Ups": (.bodyweight, [.back, .biceps]),
        "Lat Pulldown": (.cable, [.back, .biceps]),
        "Barbell Row": (.barbell, [.back, .biceps]),
        "Dumbbell Row": (.dumbbell, [.back, .biceps]),
        "Cable Row": (.cable, [.back, .biceps]),
        "Seated Cable Row": (.cable, [.back, .biceps]),
        "T-Bar Row": (.barbell, [.back, .biceps]),
        "Face Pulls": (.cable, [.shoulders, .back]),

        // SHOULDERS
        "Shoulder Press": (.barbell, [.shoulders, .triceps]),
        "Overhead Press": (.barbell, [.shoulders, .triceps]),
        "Dumbbell Shoulder Press": (.dumbbell, [.shoulders, .triceps]),
        "Arnold Press": (.dumbbell, [.shoulders]),
        "Lateral Raises": (.dumbbell, [.shoulders]),
        "Front Raises": (.dumbbell, [.shoulders]),
        "Rear Delt Flyes": (.dumbbell, [.shoulders, .back]),
        "Shrugs": (.barbell, [.shoulders]),
        "Upright Row": (.barbell, [.shoulders]),

        // LEGS
        "Squat": (.barbell, [.quads, .glutes, .hamstrings]),
        "Back Squat": (.barbell, [.quads, .glutes, .hamstrings]),
        "Front Squat": (.barbell, [.quads, .core]),
        "Goblet Squat": (.kettlebell, [.quads, .glutes]),
        "Leg Press": (.machine, [.quads, .glutes]),
        "Lunges": (.bodyweight, [.quads, .glutes]),
        "Walking Lunges": (.bodyweight, [.quads, .glutes]),
        "Bulgarian Split Squat": (.dumbbell, [.quads, .glutes]),
        "Leg Extension": (.machine, [.quads]),
        "Leg Curl": (.machine, [.hamstrings]),
        "Hip Thrust": (.barbell, [.glutes, .hamstrings]),
        "Calf Raises": (.machine, [.calves]),

        // ARMS - BICEPS
        "Bicep Curls": (.dumbbell, [.biceps]),
        "Barbell Curls": (.barbell, [.biceps]),
        "Hammer Curls": (.dumbbell, [.biceps, .forearms]),
        "Preacher Curls": (.barbell, [.biceps]),
        "Cable Curls": (.cable, [.biceps]),

        // ARMS - TRICEPS
        "Tricep Extensions": (.cable, [.triceps]),
        "Skull Crushers": (.barbell, [.triceps]),
        "Tricep Pushdown": (.cable, [.triceps]),
        "Close Grip Bench Press": (.barbell, [.triceps, .chest]),
        "Dips": (.bodyweight, [.triceps, .chest]),
        "Overhead Tricep Extensions": (.dumbbell, [.triceps]),

        // ARMS - FOREARMS
        "Wrist Curls": (.dumbbell, [.forearms]),
        "Reverse Wrist Curls": (.dumbbell, [.forearms]),
        "Farmer's Walk": (.dumbbell, [.forearms, .core]),
        "Dead Hang": (.bodyweight, [.forearms, .back]),

        // CORE
        "Plank": (.bodyweight, [.core]),
        "Side Plank": (.bodyweight, [.core]),
        "Crunches": (.bodyweight, [.core]),
        "Sit Ups": (.bodyweight, [.core]),
        "Hanging Leg Raises": (.bodyweight, [.core]),
        "Russian Twists": (.bodyweight, [.core]),
        "Ab Wheel Rollout": (.other, [.core]),
        "Cable Crunches": (.cable, [.core]),

        // FULL BODY
        "Kettlebell Swings": (.kettlebell, [.fullBody, .glutes, .hamstrings]),
        "Clean": (.barbell, [.fullBody]),
        "Power Clean": (.barbell, [.fullBody]),
        "Thrusters": (.barbell, [.fullBody]),
        "Burpees": (.bodyweight, [.fullBody]),
    ]

    // Word-number mapping
    private let wordNumbers: [String: String] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
        "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
        "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
        "eighteen": "18", "nineteen": "19", "twenty": "20",
        // Frequency words (expand to include "times" so patterns match)
        "once": "1 times", "twice": "2 times", "thrice": "3 times",
    ]

    /// Replace spoken number words with digits so regex patterns can match
    private func replaceWordNumbers(in text: String) -> String {
        var result = text
        // Sort by length descending to replace longer words first (e.g. "eighteen" before "eight")
        for (word, digit) in wordNumbers.sorted(by: { $0.key.count > $1.key.count }) {
            result = result.replacingOccurrences(of: word, with: digit)
        }
        return result
    }

    /// Preprocess text to expand gym slang before regex parsing
    static func expandGymSlang(_ text: String) -> String {
        var result = text.lowercased()

        // Plate math - barbell = 45lbs, plates are per side
        // Formula: (plates per side * 2) + 45lb bar
        // Sort by specificity (longer patterns first)
        let platePatterns: [(String, String)] = [
            // 4 plates combinations (405 base)
            ("4 plates and a 45", "495 pounds"),
            ("4 plates and a 25", "455 pounds"),
            ("4 plates and a quarter", "455 pounds"),
            ("4 plates and a 10", "425 pounds"),
            ("4 plates and a dime", "425 pounds"),
            ("4 plates and a 5", "415 pounds"),
            ("4 plates and a nickel", "415 pounds"),
            ("four plates", "405 pounds"),
            ("4 plates", "405 pounds"),

            // 3 plates combinations (315 base)
            ("3 plates and a 45", "405 pounds"),
            ("3 plates and a 25", "365 pounds"),
            ("3 plates and a quarter", "365 pounds"),
            ("3 plates and a 10", "335 pounds"),
            ("3 plates and a dime", "335 pounds"),
            ("3 plates and a 5", "325 pounds"),
            ("3 plates and a nickel", "325 pounds"),
            ("three plates", "315 pounds"),
            ("3 plates", "315 pounds"),

            // 2 plates combinations (225 base)
            ("2 plates and a 45", "315 pounds"),
            ("two plates and a 45", "315 pounds"),
            ("2 plates and a 25", "275 pounds"),
            ("two plates and a 25", "275 pounds"),
            ("2 plates and a quarter", "275 pounds"),
            ("two plates and a quarter", "275 pounds"),
            ("2 plates and a 15", "255 pounds"),
            ("two plates and a 15", "255 pounds"),
            ("2 plates and 15", "255 pounds"),
            ("2 plates and a 10", "245 pounds"),
            ("two plates and a 10", "245 pounds"),
            ("2 plates and a dime", "245 pounds"),
            ("2 plates and a 5", "235 pounds"),
            ("two plates and a 5", "235 pounds"),
            ("2 plates and a nickel", "235 pounds"),
            ("two plates", "225 pounds"),
            ("2 plates", "225 pounds"),

            // 1 plate combinations (135 base)
            ("a plate and a 45", "225 pounds"),
            ("plate and a 45", "225 pounds"),
            ("1 plate and a 45", "225 pounds"),
            ("one plate and a 45", "225 pounds"),
            ("a plate and 45", "225 pounds"),
            ("plate and 45", "225 pounds"),

            ("a plate and a 35", "205 pounds"),
            ("plate and a 35", "205 pounds"),
            ("a plate and 35", "205 pounds"),

            ("a plate and a 25", "185 pounds"),
            ("plate and a 25", "185 pounds"),
            ("1 plate and a 25", "185 pounds"),
            ("one plate and a 25", "185 pounds"),
            ("a plate and 25", "185 pounds"),
            ("plate and 25", "185 pounds"),
            ("a plate and a quarter", "185 pounds"),
            ("plate and a quarter", "185 pounds"),

            ("a plate and a 15", "165 pounds"),
            ("plate and a 15", "165 pounds"),
            ("1 plate and a 15", "165 pounds"),
            ("one plate and a 15", "165 pounds"),
            ("a plate and 15", "165 pounds"),
            ("plate and 15", "165 pounds"),
            ("with a plate and 15", "at 165 pounds"),
            ("with a plate and a 15", "at 165 pounds"),

            ("a plate and a 10", "155 pounds"),
            ("plate and a 10", "155 pounds"),
            ("1 plate and a 10", "155 pounds"),
            ("a plate and 10", "155 pounds"),
            ("plate and 10", "155 pounds"),
            ("a plate and a dime", "155 pounds"),
            ("plate and a dime", "155 pounds"),
            ("with a plate and 10", "at 155 pounds"),
            ("with a plate and a 10", "at 155 pounds"),

            ("a plate and a 5", "145 pounds"),
            ("plate and a 5", "145 pounds"),
            ("1 plate and a 5", "145 pounds"),
            ("a plate and 5", "145 pounds"),
            ("plate and 5", "145 pounds"),
            ("a plate and a nickel", "145 pounds"),
            ("plate and a nickel", "145 pounds"),

            // Single plates
            ("one plate", "135 pounds"),
            ("1 plate", "135 pounds"),
            ("a plate", "135 pounds"),

            // Just the bar
            ("just the bar", "45 pounds"),
            ("empty bar", "45 pounds"),
            ("bar only", "45 pounds"),

            // Small plate slang (for dumbbells or additional context)
            ("a quarter", "25 pounds"),
            ("a dime", "10 pounds"),
            ("a nickel", "5 pounds"),
        ]

        for (slang, expanded) in platePatterns {
            result = result.replacingOccurrences(of: slang, with: expanded)
        }

        // Common weight expressions
        let weightExpressions: [(String, String)] = [
            ("put on a", "at"),
            ("i put on", "at"),
            ("loaded up", "at"),
            ("threw on", "at"),
            ("with a", "at"),
        ]

        for (slang, expanded) in weightExpressions {
            result = result.replacingOccurrences(of: slang, with: expanded)
        }

        // Body part slang to exercises
        let slangMap: [(String, String)] = [
            ("hittin' bis", "bicep curls"),
            ("hitting bis", "bicep curls"),
            ("hit bis", "bicep curls"),
            ("worked bis", "bicep curls"),
            ("hittin' tris", "tricep extensions"),
            ("hitting tris", "tricep extensions"),
            ("hit tris", "tricep extensions"),
            ("worked tris", "tricep extensions"),
            ("hittin' chest", "bench press"),
            ("hitting chest", "bench press"),
            ("hit chest", "bench press"),
            ("worked chest", "bench press"),
            ("hittin' back", "rows"),
            ("hitting back", "rows"),
            ("hit back", "rows"),
            ("worked back", "rows"),
            ("hittin' legs", "squats"),
            ("hitting legs", "squats"),
            ("hit legs", "squats"),
            ("worked legs", "squats"),
            ("banged out", "did"),
            ("knocked out", "did"),
        ]

        for (slang, expanded) in slangMap {
            result = result.replacingOccurrences(of: slang, with: expanded)
        }

        return result
    }

    /// Parse transcribed text into structured workout data
    func parseWorkout(transcription: String) -> [ParsedExercise] {
        // Preprocess: expand gym slang, then replace word numbers
        let preprocessed = OfflineWorkoutParser.expandGymSlang(transcription)
        let text = replaceWordNumbers(in: preprocessed)
        var exercises: [ParsedExercise] = []

        // Split by common separators (periods, "then", "and then", "also", "next")
        let segments = splitIntoSegments(text)

        for segment in segments {
            if let exercise = parseSegment(segment) {
                // Check if we already have this exercise, if so merge sets
                if let existingIndex = exercises.firstIndex(where: { $0.name.lowercased() == exercise.name.lowercased() }) {
                    exercises[existingIndex].sets.append(contentsOf: exercise.sets)
                } else {
                    exercises.append(exercise)
                }
            }
        }

        // Renumber sets
        for i in exercises.indices {
            for j in exercises[i].sets.indices {
                exercises[i].sets[j].setNumber = j + 1
            }
        }

        return exercises
    }

    /// Split text into logical segments
    private func splitIntoSegments(_ text: String) -> [String] {
        // Split on common delimiters
        var segments = [text]

        let delimiters = [". ", ", then ", " then ", " and then ", " also did ", " also ", " next ", " after that ", " followed by "]

        for delimiter in delimiters {
            segments = segments.flatMap { $0.components(separatedBy: delimiter) }
        }

        return segments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Parse a single segment into an exercise
    private func parseSegment(_ segment: String) -> ParsedExercise? {
        let segment = replaceWordNumbers(in: segment)
        let lowerSegment = segment.lowercased()

        // Find exercise name
        guard let exerciseName = findExerciseName(in: segment) else {
            return nil
        }

        // Determine exercise category
        let isBodyweight = bodyweightExercises.contains(exerciseName)
        let isTimed = timedExercises.contains(exerciseName)

        let category: ExerciseCategory
        if isTimed {
            category = .timed
        } else if isBodyweight {
            category = .bodyweight
        } else {
            category = .weighted
        }

        // Detect equipment from keywords or metadata
        let equipment = detectEquipment(in: lowerSegment, exerciseName: exerciseName)

        // Get muscle groups from metadata
        let muscles = exerciseMetadata[exerciseName]?.muscles ?? []

        // Detect set type
        let setType = detectSetType(in: lowerSegment)

        // Phase 2: Detect intensity and execution factors
        let rpe = extractRPE(from: lowerSegment)
        let rir = extractRIR(from: lowerSegment)
        let restTime = extractRestTime(from: lowerSegment)
        let tempo = extractTempo(from: lowerSegment)
        let grip = detectGrip(in: lowerSegment)
        let stance = detectStance(in: lowerSegment)

        // Try per-set breakdown first (e.g. "first set was 100 pounds for 4 reps the second set was 120 pounds for 5 reps")
        if let perSetResult = parsePerSetBreakdown(from: segment, isBodyweight: isBodyweight, equipment: equipment, setType: setType, rpe: rpe, rir: rir, restTime: restTime, tempo: tempo, grip: grip, stance: stance) {
            return ParsedExercise(name: exerciseName, sets: perSetResult, category: category, equipment: equipment, primaryMuscles: muscles)
        }

        // Fallback: uniform sets
        let sets = extractSets(from: segment)
        let reps = extractReps(from: segment)
        let (weight, unit) = extractWeight(from: segment)
        let duration = isTimed ? extractDuration(from: segment) : nil

        var parsedSets: [ParsedSet] = []

        let numSets = sets ?? 1
        // If weight is specified but no reps, assume 1 rep (likely a max/PR)
        // If no weight and no reps, default to 1 rep as well (unless timed)
        let numReps = isTimed ? (reps ?? 0) : (reps ?? 1)

        // If no weight specified and equipment has a base weight, use that
        let setWeight: Double
        if isBodyweight {
            setWeight = 0.0
        } else if let explicitWeight = weight {
            setWeight = explicitWeight
        } else {
            // Use equipment base weight if available (barbell=45, trapBar=45, ezBar=25, smithMachine=20)
            setWeight = EquipmentService.shared.baseWeight(for: equipment)
        }
        let setUnit = unit ?? .lbs
        let setDuration = duration

        for i in 1...numSets {
            parsedSets.append(ParsedSet(
                setNumber: i,
                reps: numReps,
                weight: setWeight,
                unit: setUnit,
                duration: setDuration,
                setType: setType,
                rpe: rpe,
                rir: rir,
                restTime: restTime,
                tempo: tempo,
                gripType: grip,
                stanceType: stance
            ))
        }

        return ParsedExercise(
            name: exerciseName,
            sets: parsedSets,
            category: category,
            equipment: equipment,
            primaryMuscles: muscles
        )
    }

    /// Detect equipment from text or exercise metadata
    private func detectEquipment(in text: String, exerciseName: String) -> Equipment {
        // First check keywords in the text
        for (keyword, equipment) in equipmentKeywords {
            if text.contains(keyword) {
                return equipment
            }
        }

        // Fall back to exercise metadata
        if let metadata = exerciseMetadata[exerciseName] {
            return metadata.equipment
        }

        // Check if it's a bodyweight exercise
        if bodyweightExercises.contains(exerciseName) {
            return .bodyweight
        }

        return .other
    }

    /// Detect set type from keywords
    private func detectSetType(in text: String) -> SetType {
        for (keyword, setType) in setTypeKeywords {
            if text.contains(keyword) {
                return setType
            }
        }
        return .normal
    }

    /// Extract duration in seconds from text (for timed exercises)
    private func extractDuration(from text: String) -> Int? {
        let lower = text.lowercased()

        // Patterns for duration: "60 seconds", "1 minute", "30 sec", "1:30"
        let patterns: [(pattern: String, multiplier: Int)] = [
            (#"(\d+)\s*(?:minutes?|mins?|m)\s*(?:and\s*)?(\d+)?\s*(?:seconds?|secs?|s)?"#, 60),  // "1 minute 30 seconds"
            (#"(\d+):(\d+)"#, 0),  // "1:30" format
            (#"(\d+)\s*(?:minutes?|mins?|m)\b"#, 60),  // "2 minutes"
            (#"(\d+)\s*(?:seconds?|secs?|s)\b"#, 1),  // "60 seconds"
        ]

        // Try minute:second format first
        if let match = lower.range(of: #"(\d+):(\d+)"#, options: .regularExpression) {
            let matchStr = String(lower[match])
            let parts = matchStr.split(separator: ":")
            if parts.count == 2, let mins = Int(parts[0]), let secs = Int(parts[1]) {
                return mins * 60 + secs
            }
        }

        // Try "X minutes Y seconds" format
        if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:minutes?|mins?|m)\s*(?:and\s*)?(\d+)\s*(?:seconds?|secs?|s)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            if let minsRange = Range(match.range(at: 1), in: lower),
               let secsRange = Range(match.range(at: 2), in: lower),
               let mins = Int(lower[minsRange]),
               let secs = Int(lower[secsRange]) {
                return mins * 60 + secs
            }
        }

        // Try "X minutes" format
        if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:minutes?|mins?|m)\b"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let mins = Int(lower[range]) {
            return mins * 60
        }

        // Try "X seconds" format
        if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:seconds?|secs?|s)\b"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let secs = Int(lower[range]) {
            return secs
        }

        return nil
    }

    /// Extract RPE (Rate of Perceived Exertion) from text - returns 1-10 scale
    private func extractRPE(from text: String) -> Int? {
        let lower = text.lowercased()

        // Patterns: "RPE 8", "rpe of 7", "RPE8", "at an 8", "felt like an 8"
        let patterns = [
            #"rpe\s*(?:of\s*)?(\d+)"#,
            #"rpe(\d+)"#,
            #"rate\s*(?:of\s*)?(?:perceived\s*)?(?:exertion\s*)?(?:of\s*)?(\d+)"#,
            #"(?:felt like|was) (?:an? )?(\d+)\s*(?:out of 10|/10)"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
               let range = Range(match.range(at: 1), in: lower),
               let rpe = Int(lower[range]) {
                // Clamp to 1-10
                return max(1, min(10, rpe))
            }
        }

        return nil
    }

    /// Extract RIR (Reps In Reserve) from text
    private func extractRIR(from text: String) -> Int? {
        let lower = text.lowercased()

        // Patterns: "RIR 2", "2 in the tank", "2 reps in reserve", "had 3 left"
        let patterns = [
            #"rir\s*(?:of\s*)?(\d+)"#,
            #"rir(\d+)"#,
            #"(\d+)\s*(?:reps?\s*)?in\s*(?:the\s*)?(?:tank|reserve)"#,
            #"(?:had|left)\s*(\d+)\s*(?:reps?\s*)?(?:left|remaining)?"#,
            #"could\s*(?:have\s*)?(?:done\s*)?(\d+)\s*more"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
               let range = Range(match.range(at: 1), in: lower),
               let rir = Int(lower[range]) {
                // RIR typically 0-5
                return max(0, min(10, rir))
            }
        }

        return nil
    }

    /// Extract rest time in seconds from text
    private func extractRestTime(from text: String) -> Int? {
        let lower = text.lowercased()

        // Patterns: "90 seconds rest", "2 minute rest", "rest 60 seconds", "rested for 2 minutes"
        let patterns: [(pattern: String, multiplier: Int)] = [
            (#"rest(?:ed)?\s*(?:for\s*)?(\d+)\s*(?:minutes?|mins?|m)\s*(?:and\s*)?(\d+)?\s*(?:seconds?|secs?|s)?"#, 60),
            (#"(\d+)\s*(?:minutes?|mins?|m)\s*(?:and\s*)?(\d+)?\s*(?:seconds?|secs?|s)?\s*rest"#, 60),
            (#"rest(?:ed)?\s*(?:for\s*)?(\d+)\s*(?:seconds?|secs?|s)"#, 1),
            (#"(\d+)\s*(?:seconds?|secs?|s)\s*rest"#, 1),
            (#"rest(?:ed)?\s*(?:for\s*)?(\d+)\s*(?:minutes?|mins?|m)"#, 60),
            (#"(\d+)\s*(?:minutes?|mins?|m)\s*rest"#, 60),
            (#"(\d+):(\d+)\s*rest"#, 0),  // "1:30 rest"
        ]

        // Try minute:second format first
        if let regex = try? NSRegularExpression(pattern: #"(\d+):(\d+)\s*rest"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let minsRange = Range(match.range(at: 1), in: lower),
           let secsRange = Range(match.range(at: 2), in: lower),
           let mins = Int(lower[minsRange]),
           let secs = Int(lower[secsRange]) {
            return mins * 60 + secs
        }

        // Try minutes + seconds format
        if let regex = try? NSRegularExpression(pattern: #"rest(?:ed)?\s*(?:for\s*)?(\d+)\s*(?:minutes?|mins?|m)\s*(?:and\s*)?(\d+)\s*(?:seconds?|secs?|s)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let minsRange = Range(match.range(at: 1), in: lower),
           let secsRange = Range(match.range(at: 2), in: lower),
           let mins = Int(lower[minsRange]),
           let secs = Int(lower[secsRange]) {
            return mins * 60 + secs
        }

        // Try minutes only
        if let regex = try? NSRegularExpression(pattern: #"(?:rest(?:ed)?\s*(?:for\s*)?|(?<=\s))(\d+)\s*(?:minutes?|mins?|m)\s*rest"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let mins = Int(lower[range]) {
            return mins * 60
        }

        if let regex = try? NSRegularExpression(pattern: #"rest(?:ed)?\s*(?:for\s*)?(\d+)\s*(?:minutes?|mins?|m)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let mins = Int(lower[range]) {
            return mins * 60
        }

        // Try seconds only
        if let regex = try? NSRegularExpression(pattern: #"(?:rest(?:ed)?\s*(?:for\s*)?|(?<=\s))(\d+)\s*(?:seconds?|secs?|s)\s*rest"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let secs = Int(lower[range]) {
            return secs
        }

        if let regex = try? NSRegularExpression(pattern: #"rest(?:ed)?\s*(?:for\s*)?(\d+)\s*(?:seconds?|secs?|s)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let secs = Int(lower[range]) {
            return secs
        }

        return nil
    }

    /// Extract tempo notation from text (e.g., "3-1-2", "slow eccentric")
    private func extractTempo(from text: String) -> String? {
        let lower = text.lowercased()

        // Numeric tempo pattern: "3-1-2-0", "3/1/2", "3 1 2"
        let numericPatterns = [
            #"tempo\s*(?:of\s*)?(\d+[-/\s]\d+[-/\s]\d+(?:[-/\s]\d+)?)"#,
            #"(\d+[-/\s]\d+[-/\s]\d+(?:[-/\s]\d+)?)\s*tempo"#,
            #"\b(\d+-\d+-\d+(?:-\d+)?)\b"#,  // Standalone "3-1-2-0"
        ]

        for pattern in numericPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
               let range = Range(match.range(at: 1), in: lower) {
                // Normalize to dash-separated format
                var tempo = String(lower[range])
                tempo = tempo.replacingOccurrences(of: "/", with: "-")
                tempo = tempo.replacingOccurrences(of: " ", with: "-")
                return tempo
            }
        }

        // Descriptive tempo patterns
        let descriptivePatterns: [(pattern: String, tempo: String)] = [
            (#"slow\s*(?:and\s*)?controlled"#, "3-1-3"),
            (#"slow\s*eccentric"#, "4-0-1"),
            (#"slow\s*negative"#, "4-0-1"),
            (#"pause(?:d)?\s*(?:at\s*)?(?:the\s*)?bottom"#, "2-2-1"),
            (#"pause(?:d)?\s*(?:at\s*)?(?:the\s*)?top"#, "2-0-2-2"),
            (#"explosive"#, "1-0-X"),
            (#"time\s*under\s*tension"#, "3-1-3"),
            (#"tut"#, "3-1-3"),
        ]

        for (pattern, tempo) in descriptivePatterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return tempo
            }
        }

        return nil
    }

    /// Detect grip type from text
    private func detectGrip(in text: String) -> GripType? {
        let lower = text.lowercased()

        // Sort by length descending to match longer patterns first
        let sortedGrips = gripKeywords.keys.sorted { $0.count > $1.count }

        for keyword in sortedGrips {
            if lower.contains(keyword) {
                return gripKeywords[keyword]
            }
        }

        return nil
    }

    /// Detect stance type from text
    private func detectStance(in text: String) -> StanceType? {
        let lower = text.lowercased()

        // Sort by length descending to match longer patterns first
        let sortedStances = stanceKeywords.keys.sorted { $0.count > $1.count }

        for keyword in sortedStances {
            if lower.contains(keyword) {
                return stanceKeywords[keyword]
            }
        }

        return nil
    }

    /// Ordinal markers used to split per-set descriptions
    private let ordinalPatterns: [String] = [
        "1st set", "2nd set", "3rd set", "4th set", "5th set",
        "6th set", "7th set", "8th set", "9th set", "10th set",
        "first set", "second set", "third set", "fourth set", "fifth set",
        "sixth set", "seventh set", "eighth set", "ninth set", "tenth set",
        "set 1", "set 2", "set 3", "set 4", "set 5",
        "set 6", "set 7", "set 8", "set 9", "set 10",
    ]

    /// Try to parse per-set breakdowns like "first set was 100 pounds for 4 reps the second set was 120 pounds for 5 reps"
    private func parsePerSetBreakdown(
        from text: String,
        isBodyweight: Bool,
        equipment: Equipment = .other,
        setType: SetType = .normal,
        rpe: Int? = nil,
        rir: Int? = nil,
        restTime: Int? = nil,
        tempo: String? = nil,
        grip: GripType? = nil,
        stance: StanceType? = nil
    ) -> [ParsedSet]? {
        let lower = text.lowercased()

        // Find all ordinal markers present in the text and their positions
        var markers: [(position: Int, label: String)] = []
        for marker in ordinalPatterns {
            var searchStart = lower.startIndex
            while let range = lower.range(of: marker, range: searchStart..<lower.endIndex) {
                markers.append((lower.distance(from: lower.startIndex, to: range.lowerBound), marker))
                searchStart = range.upperBound
            }
        }

        guard markers.count >= 2 else { return nil }

        // Sort by position
        markers.sort { $0.position < $1.position }

        // Split text into per-set chunks
        var parsedSets: [ParsedSet] = []
        for i in 0..<markers.count {
            let startIdx = lower.index(lower.startIndex, offsetBy: markers[i].position)
            let endIdx = i + 1 < markers.count
                ? lower.index(lower.startIndex, offsetBy: markers[i + 1].position)
                : lower.endIndex
            let chunk = String(lower[startIdx..<endIdx])

            let reps = extractReps(from: chunk) ?? extractFirstNumber(from: chunk)
            let (weight, unit) = extractWeight(from: chunk)

            // Try to extract per-set RPE/RIR if mentioned for this specific set
            let setRpe = extractRPE(from: chunk) ?? rpe
            let setRir = extractRIR(from: chunk) ?? rir

            // Determine weight - use equipment base weight if not specified
            let setWeight: Double
            if isBodyweight {
                setWeight = 0.0
            } else if let explicitWeight = weight {
                setWeight = explicitWeight
            } else {
                setWeight = EquipmentService.shared.baseWeight(for: equipment)
            }

            parsedSets.append(ParsedSet(
                setNumber: i + 1,
                reps: reps ?? 1,
                weight: setWeight,
                unit: unit ?? .lbs,
                duration: nil,
                setType: setType,
                rpe: setRpe,
                rir: setRir,
                restTime: restTime,
                tempo: tempo,
                gripType: grip,
                stanceType: stance
            ))
        }

        return parsedSets
    }

    /// Find exercise name in text - only returns recognized exercises
    private func findExerciseName(in text: String) -> String? {
        let lowercased = text.lowercased()

        // Sort by length descending so we match longer names first
        // e.g., "incline bench press" before "bench press" before "bench"
        let sortedAliases = exerciseAliases.keys.sorted { $0.count > $1.count }

        for alias in sortedAliases {
            if lowercased.contains(alias) {
                return exerciseAliases[alias]
            }
        }

        // Only accept recognized exercises - no fallback for unknown text
        return nil
    }

    /// Extract number of sets from text
    private func extractSets(from text: String) -> Int? {
        let lower = text.lowercased()

        // Check for "X times" at end of sentence or after reps (means sets, not reps)
        // e.g., "5 reps three times" = 3 sets
        let timesPatterns = [
            #"reps?\s+(\d+)\s*times?"#,  // "5 reps 3 times"
            #"reps?\s+(twice|two\s*times)"#,  // "5 reps twice"
            #"reps?\s+(three|3)\s*times?"#,
            #"reps?\s+(four|4)\s*times?"#,
            #"reps?\s+(five|5)\s*times?"#,
            #"(\d+)\s*times?\s*$"#,  // "X times" at end of text
        ]

        for pattern in timesPatterns {
            if let match = lower.range(of: pattern, options: .regularExpression) {
                let matchedText = String(lower[match])
                if matchedText.contains("twice") || matchedText.contains("two times") {
                    return 2
                } else if matchedText.contains("three") {
                    return 3
                } else if matchedText.contains("four") {
                    return 4
                } else if matchedText.contains("five") && !matchedText.contains("reps") {
                    return 5
                } else if let number = extractFirstNumber(from: matchedText) {
                    // For patterns with reps, we want the number after reps
                    let afterReps = matchedText.replacingOccurrences(of: #"^\d+\s*reps?\s*"#, with: "", options: .regularExpression)
                    if let setsNum = extractFirstNumber(from: afterReps) {
                        return setsNum
                    }
                    return number
                }
            }
        }

        let patterns = [
            #"(\d+)\s*sets?"#,
            #"(\d+)\s*x\s*\d+"#,  // "3x10" format - first number is sets
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                if let number = extractFirstNumber(from: matchedText) {
                    return number
                }
            }
        }

        return nil
    }

    /// Extract number of reps from text
    private func extractReps(from text: String) -> Int? {
        let lower = text.lowercased()

        // Check for singular rep phrases first (returns 1)
        // Use regex with word boundaries to avoid matching "for 1" within "for 10"
        let singularPatterns = [
            #"\ba\s+single\s+rep"#,
            #"\bsingle\s+rep"#,
            #"\bone\s+rep"#,
            #"\b1\s+rep\b"#,
            #"\ba\s+rep\b"#,
            #"\bfor\s+a\s+single\b"#,
            #"\bjust\s+one\b"#,
            #"\bfor\s+one\b(?!\d)"#,
            #"\bfor\s+1\b(?!\d)"#  // "for 1" only if not followed by another digit
        ]
        for pattern in singularPatterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return 1
            }
        }

        // Priority patterns - check these first (explicit reps mentions)
        let priorityPatterns = [
            #"(\d+)\s*reps?"#,
            #"for\s+(\d+)\s+reps?"#,
            #"sets?\s*of\s*(\d+)"#,  // "4 sets of 8" - second number is reps
            #"\d+\s*x\s*(\d+)"#,  // "3x10" format - second number is reps
        ]

        for pattern in priorityPatterns {
            if let match = lower.range(of: pattern, options: .regularExpression) {
                let matchedText = String(lower[match])

                // For "NxN" format, get the second number
                if pattern.contains("x") {
                    let parts = matchedText.components(separatedBy: "x")
                    if parts.count == 2, let reps = Int(parts[1].trimmingCharacters(in: .whitespaces).prefix(while: { $0.isNumber })) {
                        return reps
                    }
                } else {
                    if let number = extractFirstNumber(from: matchedText) {
                        return number
                    }
                }
            }
        }

        // Secondary patterns - only use "times" if it's NOT at the end (which likely means sets)
        // and there's no explicit reps pattern
        let hasRepsKeyword = lower.contains("rep")
        if !hasRepsKeyword {
            // Check for "X times" but not at the end of the text (end "times" likely means sets)
            let timesPattern = #"(\d+)\s*times?(?!.*$)"#
            if let match = lower.range(of: timesPattern, options: .regularExpression) {
                let matchedText = String(lower[match])
                if let number = extractFirstNumber(from: matchedText) {
                    return number
                }
            }

            // Fallback patterns
            let fallbackPatterns = [
                #"for\s*(\d+)"#,
                #"did\s*(\d+)"#,
                #"do\s*(\d+)"#,
            ]

            for pattern in fallbackPatterns {
                if let match = lower.range(of: pattern, options: .regularExpression) {
                    let matchedText = String(lower[match])
                    if let number = extractFirstNumber(from: matchedText) {
                        return number
                    }
                }
            }
        }

        return nil
    }

    /// Extract weight and unit from text
    private func extractWeight(from text: String) -> (Double?, WeightUnit?) {
        // Check for kg/kilos first
        let kgPattern = #"(\d+\.?\d*)\s*(kilograms?|kilos?|kgs?|kg)"#
        if let match = text.range(of: kgPattern, options: [.regularExpression, .caseInsensitive]) {
            let matchedText = String(text[match])
            if let number = extractFirstDouble(from: matchedText) {
                return (number, .kg)
            }
        }

        // Check for lbs/pounds
        let lbsPattern = #"(\d+\.?\d*)\s*(pounds?|lbs?|lb)"#
        if let match = text.range(of: lbsPattern, options: [.regularExpression, .caseInsensitive]) {
            let matchedText = String(text[match])
            if let number = extractFirstDouble(from: matchedText) {
                return (number, .lbs)
            }
        }

        // Check for "at X" pattern (assume lbs)
        let atPattern = #"at\s*(\d+\.?\d*)"#
        if let match = text.range(of: atPattern, options: .regularExpression) {
            let matchedText = String(text[match])
            if let number = extractFirstDouble(from: matchedText) {
                return (number, .lbs)
            }
        }

        // Check for standalone weight after NxN pattern (e.g., "3x10 225 bench")
        let afterSetsRepsPattern = #"\d+\s*x\s*\d+\s+(\d+\.?\d*)"#
        if let match = text.range(of: afterSetsRepsPattern, options: [.regularExpression, .caseInsensitive]) {
            let matchedText = String(text[match])
            // Get the last number (weight) from the match
            let numbers = matchedText.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if numbers.count >= 3, let weight = Double(numbers[2]), weight >= 20 {
                return (weight, .lbs)
            }
        }

        // Check for standalone 3-digit number (likely a weight, assume lbs)
        // This catches patterns like "bench 225" or "225 bench press"
        let standalonePattern = #"(?<!\d)\b(\d{3})\b(?!\s*x)(?!\s*reps?)(?!\s*sets?)"#
        if let match = text.range(of: standalonePattern, options: .regularExpression) {
            let matchedText = String(text[match])
            if let number = extractFirstDouble(from: matchedText), number >= 45 {
                return (number, .lbs)
            }
        }

        return (nil, nil)
    }

    /// Extract first integer from string
    private func extractFirstNumber(from text: String) -> Int? {
        let pattern = #"\d+"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return Int(text[match])
        }
        return nil
    }

    /// Extract first double from string
    private func extractFirstDouble(from text: String) -> Double? {
        let pattern = #"\d+\.?\d*"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return Double(text[match])
        }
        return nil
    }
}
