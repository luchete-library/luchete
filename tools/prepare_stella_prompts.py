"""Save the exact prompts used by the built-in image tool, before generation."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
specs=json.loads((ROOT/'tools/stella_interaction_specs.json').read_text(encoding='utf-8'))
for member,spec in specs.items():
    for group in ('social','furniture'):
        text=f'''Use case: illustration-story / identity-preserve.
Asset type: production pixel-art sprite animation atlas for a cozy library fan game.
Reference 1 is the exact existing tiny overworld character, the MAIN identity and body-proportion anchor. Reference 2 is the matching detailed outfit design, used ONLY to clarify colors and accessories, NOT its tall proportions.
Draw ONLY {spec['name']} in the EXACT default outfit. {spec['identity']}
True transparent alpha background. EXACTLY FIVE equal columns and FOUR equal rows, TWENTY separate full-body sprites, ample empty gutters at every cell edge. No labels, grid lines, other people, background, furniture, floor, cast shadows, effects, text, gradients, glow, or detached spare parts.
Use crisp stepped pixel clusters like hand-authored 16-bit RPG sprites at about 88 pixels character height. Two-and-a-half-head chibi proportions, large consistent head, short torso and legs, fully connected neck/shoulders/hips. Keep body size, head size and proportions absolutely stable between ALL cells. No stretched limbs, no floating hands, no segmented body or jelly motion. Full figure visible from top accessory to soles. Preserve identity accessories and clothes even when sitting or closing eyes. Eyes and mouth should be small and readable: closed-mouth subtle smiles, never toothy grins. Do not add animal ears to human characters.
Sheet composition: 5 columns x 4 rows. Camera front, SAME virtual camera scale in every cell. Each cell has its own pose centered with the body's ground-contact point aligned horizontally. Sit poses are SHORTER because knees bend; never enlarge their head or entire body to fill the cell. Neutral standing height is the scale reference. Every row's column 5 is the SAME neutral front standing pose with hands relaxed and no props.
Columns 1-4 form: preparatory anticipation, enter gesture, main expressive action, release/recovery. Column 5 is neutral standing. These are full connected poses, not separate anatomical layers. Place all feet/ground-contact at SAME relative lower baseline for the row, and preserve open transparent margins.
'''
        if group=='furniture':
            text+='For reading and tea, show believable seated knees and hips with feet below the body, but DO NOT draw the chair/table. For yoga, show knees folding naturally into a cross-legged seated pose; head and torso stay the same size as standing. Books/cups are small and never cover the face. Stream poses remain standing.\n'
        for row,(_,label,description) in enumerate(spec[group],1):
            text+=f'ROW {row}: {label}. Columns 1-4: {description} Column 5: same neutral front standing pose.\n'
        text+='No new costume elements. Final check: exactly 20 complete separated sprites in a perfectly regular 5x4 matrix, coherent body proportions, real alpha transparency, no furniture.\n'
        (ROOT/f'assets/characters/source/{member}_interactions_{group}_v1.prompt.txt').write_text(text,encoding='utf-8')
print('Saved 12 built-in generation prompts.')
