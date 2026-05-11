//@api-1.0
// LuxLingo — Ligne Claire Scene Generator
// Model:  FLUX.1 [dev] Q5P
// LoRA:   saurabhswami/Tintincomicslora
// Trigger: bande dessinée style

// ─── SETTINGS ────────────────────────────────────────────────────────────────

const MODEL       = "flux_1_dev_q5p.ckpt";
const LORA_NAME   = "saurabhswami_tintincomicslora_lora_f16.ckpt";
const LORA_WEIGHT = 0.85;

const WIDTH          = 1024;
const HEIGHT         = 512;
const STEPS          = 25;
const GUIDANCE_SCALE = 3.5;
const BASE_SEED      = 42;

// Images save automatically to ~/Pictures/luxlingo_scenes/
const OUTPUT_DIR = filesystem.pictures.path + "/luxlingo_scenes";

const STYLE_PREFIX =
  "bande dessinée style, Ligne Claire, clean bold black outlines, " +
  "vibrant flat colors, simple shapes, high quality comic illustration.";

// ─── SCENES ──────────────────────────────────────────────────────────────────
// To skip scenes already generated, comment them out or change the loop start index below.

const SCENES = [
  {
    key:    "school_morning",
    label:  "01 — Village school, morning arrival",
    prompt: "A charming stone schoolhouse in a small Luxembourg village, morning light, " +
            "children arriving on foot and by bicycle along a narrow tree-lined lane, " +
            "school bell tower, flower boxes on windows, green hills behind, " +
            "cheerful and welcoming atmosphere.",
  },
  {
    key:    "classroom",
    label:  "02 — Classroom, Mr. Weiss teaching",
    prompt: "Cozy village school classroom interior, wooden desks in rows, " +
            "a warm older teacher with white hair and round glasses at a blackboard, " +
            "Luxembourgish alphabet and numbers on the wall, maps, bright windows " +
            "overlooking green hills, backpacks on hooks, golden afternoon light.",
  },
  {
    key:    "village_park",
    label:  "03 — Village park, children playing",
    prompt: "A leafy village park in the Oesling hills, children playing football " +
            "on a small grass pitch, a golden retriever running with them, " +
            "ancient chestnut trees, a wooden bench, flower beds, blue sky, " +
            "rolling green hills visible beyond the park fence.",
  },
  {
    key:    "cafe_bakery",
    label:  "04 — Village café and bakery",
    prompt: "A quaint Luxembourg village café and bakery on a cobblestone square, " +
            "outdoor terrace with red-checked tablecloths, pastries in the window display, " +
            "a vintage café sign, flower pots by the entrance, morning sunshine, " +
            "warm and inviting European small-town feeling.",
  },
  {
    key:    "garden_fence",
    label:  "05 — Garden fence chat between neighbours",
    prompt: "Two neighbouring gardens separated by a low stone wall, parents chatting " +
            "warmly across the fence, children playing in the background, " +
            "vegetable garden on one side, flower garden on the other, " +
            "washing line, stone house facades, green hills.",
  },
  {
    key:    "bus_stop",
    label:  "06 — School bus stop at dawn",
    prompt: "A yellow school bus stop sign at the edge of a village lane, misty morning hills, " +
            "children with backpacks waiting under an ancient oak tree, " +
            "a golden retriever sitting nearby, village houses with lit kitchen windows, " +
            "soft early-morning light, dew on the grass.",
  },
  {
    key:    "cycling_path",
    label:  "07 — Cycling path through the Oesling",
    prompt: "A winding cycle path through rolling green hills of the Oesling Luxembourg, " +
            "two children on bicycles with helmets and backpacks, ancient forest on one side, " +
            "open meadow with wildflowers on the other, a stream in the valley below, " +
            "bright clear sky, cheerful adventurous mood.",
  },
  {
    key:    "village_street",
    label:  "08 — Village street, narrow lane",
    prompt: "A narrow cobblestone village lane in northern Luxembourg, " +
            "old slate-roofed houses with colourful shutters, a child walking a golden retriever, " +
            "a cat on a windowsill, flower boxes, a small fountain, " +
            "warm late-afternoon sun casting long shadows, peaceful timeless atmosphere.",
  },
  {
    key:    "school_playground",
    label:  "09 — School playground at break time",
    prompt: "A lively school playground, children playing hopscotch and skipping rope, " +
            "a painted mural of the Luxembourg flag on a stone wall, " +
            "a chestnut tree in the corner, schoolhouse facade behind, bright midday sun, " +
            "backpacks piled against the wall.",
  },
  {
    key:    "kitchen_evening",
    label:  "10 — Cosy evening, homework at the kitchen table",
    prompt: "A warm Luxembourg village kitchen, a child doing homework at a wooden table " +
            "by lamplight, a parent nearby preparing dinner, a golden retriever by the radiator, " +
            "rain on the window, bookshelves, a Luxembourg map on the wall, pots on the stove.",
  },
  {
    key:    "village_market",
    label:  "11 — Village weekly market",
    prompt: "A lively open-air market on the cobblestone square of a Luxembourg village, " +
            "wooden stalls with colourful awnings selling vegetables bread cheese and flowers, " +
            "villagers browsing and chatting, a child carrying a basket, " +
            "an old stone fountain in the centre, warm morning sunlight.",
  },
  {
    key:    "doctors_office",
    label:  "12 — Doctor's waiting room",
    prompt: "A cosy village doctor's waiting room, simple wooden chairs along a white wall, " +
            "a potted plant in the corner, health posters on the wall, " +
            "a friendly nurse behind a small reception desk, " +
            "warm light through a window overlooking green hills, calm safe atmosphere.",
  },
  {
    key:    "sports_hall",
    label:  "13 — Sports hall / indoor gymnasium",
    prompt: "A bright village sports hall, children playing indoor football on a wooden floor, " +
            "coloured team bibs, a goal at each end, sports equipment along the wall, " +
            "high windows letting in afternoon light, a scoreboard, cheerful energetic feel.",
  },
  {
    key:    "train_station",
    label:  "14 — Small village train station",
    prompt: "A tiny Luxembourg village train station platform, a red CFL train just arriving, " +
            "a stone station building with a clock above the door, passengers with bags waiting, " +
            "a bicycle rack, green rolling hills beyond the tracks, crisp morning air.",
  },
  {
    key:    "library",
    label:  "15 — Village library interior",
    prompt: "A cosy village library reading room, tall wooden bookshelves lining the walls, " +
            "a child sitting cross-legged on a beanbag reading, another at a low table with an atlas, " +
            "a librarian at the desk, afternoon sun through arched windows, plants on the windowsill.",
  },
  {
    key:    "winter_street",
    label:  "16 — Winter street, snow-covered village",
    prompt: "A narrow Luxembourg village lane in winter, rooftops dusted with snow, " +
            "children in colourful coats and scarves walking home from school, " +
            "lit kitchen windows glowing orange against cold blue dusk, " +
            "footprints in snow, a lantern casting warm light on cobblestones.",
  },
  {
    key:    "church_square",
    label:  "17 — Village church square with fountain",
    prompt: "The central square of a small Luxembourg village, an old stone church with a bell tower, " +
            "a round stone fountain in front, flower beds, villagers on a bench, " +
            "a child chasing pigeons, afternoon golden light, Luxembourg flags on the facade.",
  },
  {
    key:    "river_swimming",
    label:  "18 — River and swimming spot, Oesling",
    prompt: "A sun-dappled river bend in the Oesling hills, children jumping from a low wooden dock " +
            "into clear water, a golden retriever on the bank, a picnic blanket under a willow tree, " +
            "wildflowers along the bank, rolling green hills reflected in the water.",
  },
];

// ─── RESOLVE LORA ────────────────────────────────────────────────────────────
// Try DrawThings' name resolver first; fall back to the hardcoded filename.

let loraFile = LORA_NAME;
try {
  const resolved = pipeline.findLoRAByName("saurabhswami/Tintincomicslora");
  if (resolved && resolved.file) {
    loraFile = resolved.file;
  }
} catch (e) {
  // Use hardcoded LORA_NAME
}

// ─── RUN ─────────────────────────────────────────────────────────────────────
// pipeline.run() is synchronous in DrawThings — no async/await needed.
// prompt and negativePrompt are top-level keys, NOT inside configuration.

const startScene = 0; // Change to 5 to skip first 5, etc.

for (let i = startScene; i < SCENES.length; i++) {
  const scene = SCENES[i];
  const seed  = BASE_SEED + i;
  const fullPrompt = STYLE_PREFIX + " " + scene.prompt;

  console.log(`[${i + 1}/${SCENES.length}] ${scene.label}  (seed ${seed})`);

  // Apply settings to the live configuration object
  const config = Object.assign(pipeline.configuration, {
    model:         MODEL,
    width:         WIDTH,
    height:        HEIGHT,
    steps:         STEPS,
    guidanceScale: GUIDANCE_SCALE,
    seed:          seed,
    loras:         [{ file: loraFile, weight: LORA_WEIGHT }],
  });

  canvas.clear();

  // prompt and negativePrompt go at the TOP LEVEL of pipeline.run(), not in config
  pipeline.run({
    configuration:  config,
    prompt:         fullPrompt,
    negativePrompt: "",
  });

  // Auto-save with the scene key name — no manual renaming needed
  const savePath = `${OUTPUT_DIR}/scene_${scene.key}.png`;
  canvas.saveImage(savePath, true);

  console.log(`  ✓ saved: scene_${scene.key}.png`);
}

console.log("All done! Files saved to ~/Pictures/luxlingo_scenes/");
