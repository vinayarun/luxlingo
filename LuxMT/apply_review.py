#!/usr/bin/env python3
"""
apply_review.py — Fix the remaining sentences in still_unfixed.json.

Three strategies per word:
  A) Substitute: replace DeepL synonym with target word directly in the translation.
  B) Accept variant: DeepL gives a case/number/gender form — accept the DeepL
     translation and point cloze_index at the variant form (app shows mismatch hint).
  C) Mark unchanged: truly broken translations — leave in review for manual fixing.

Usage:
  cd /Users/nv/projects/luxlingo
  source LuxMT/venv/bin/activate
  python3 LuxMT/apply_review.py [--dry-run]
"""

import json, re, sys, os

SEED_PATH    = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'
UNFIXED_PATH = 'LuxMT/still_unfixed.json'

# ── Token helpers (shared with fix_missing_word_sentences.py) ─────────────────
APOS       = "''ʼ'"
ELISION_RE = re.compile(r'^[dtlDTL][' + APOS + r']')

def normalize(tok):
    tok = re.sub(r"""[.,?!:;\"()\[\]«»…–\d''""ʼ']""", '', tok)
    return tok.lower()

def find_lemma_idx(lemma_l, text):
    no_n = lemma_l[:-1] if lemma_l.endswith('n') else lemma_l
    for i, w in enumerate(text.split()):
        n = normalize(w)
        if ELISION_RE.match(w) and len(n) > 1:
            n = n[1:]
        if n == lemma_l or n == no_n:
            return i
    return None

def find_multiword_idx(lemma_l, text):
    """
    For a multi-word lemma (e.g. 'sou datt'), find the index of the first word
    in text where the next token matches the second word.
    Returns the index of the first word, or None if not found.
    """
    parts = lemma_l.lower().split()
    if len(parts) < 2:
        return find_lemma_idx(lemma_l, text)
    words = text.split()
    for i in range(len(words) - len(parts) + 1):
        match = True
        for j, part in enumerate(parts):
            if normalize(words[i + j]) != part:
                match = False
                break
        if match:
            return i
    return None

def find_any_idx(targets, text):
    """Find the first occurrence of any target string (case-insensitive) in text tokens."""
    text_l = text.lower()
    words = text.split()
    for i, w in enumerate(words):
        n = normalize(w)
        if ELISION_RE.match(w) and len(n) > 1:
            n = n[1:]
        for t in targets:
            tl = t.lower()
            if n == tl or w.lower() == tl:
                return i
            # prefix match (e.g. "definitivt".startswith("definitiv"))
            if n.startswith(tl) or tl.startswith(n):
                return i
    # Also try substring match within tokens
    for i, w in enumerate(words):
        for t in targets:
            if t.lower() in normalize(w):
                return i
    return None

def substitute(text, find_words, replacement):
    """
    Replace first occurrence of any word in find_words with replacement.
    Respects word boundaries. Preserves original capitalisation context.
    Also handles multi-word find targets.
    """
    for fw in find_words:
        # Try exact word boundary replacement (case-insensitive)
        pattern = re.compile(r'\b' + re.escape(fw) + r'\b', re.IGNORECASE)
        new_text, n = pattern.subn(replacement, text, count=1)
        if n:
            return new_text
    return text

def make_result(lemma_l, lu, text_en, diff, exact=True):
    # Handle multi-word lemmas
    if ' ' in lemma_l:
        idx = find_multiword_idx(lemma_l, lu)
    else:
        idx = find_lemma_idx(lemma_l, lu)
    if idx is None:
        return None
    words = lu.split()
    tok   = words[idx] if idx < len(words) else ''
    norm  = normalize(tok)
    if ELISION_RE.match(tok) and len(norm) > 1:
        norm = norm[1:]
    # For multi-word, check first word matches
    first_part = lemma_l.split()[0] if ' ' in lemma_l else lemma_l
    is_exact = (norm == first_part)
    return {
        'text_lu':          lu,
        'text_en':          text_en,
        'difficulty':       diff,
        'cloze_index':      idx,
        'exact_form':       is_exact,
        'cloze_confidence': 'exact' if is_exact else 'fallback',
    }

def make_variant_result(variant_words, lu, text_en, diff):
    """Accept DeepL output but point cloze_index at the variant form."""
    idx = find_any_idx(variant_words, lu)
    if idx is None:
        return None
    return {
        'text_lu':          lu,
        'text_en':          text_en,
        'difficulty':       diff,
        'cloze_index':      idx,
        'exact_form':       False,
        'cloze_confidence': 'fallback',
    }

# ── Strategy table ─────────────────────────────────────────────────────────────
# Each entry: word_lu → strategy dict
#   'sub':       [(find_list, replacement), ...]  — Strategy A
#   'variant':   [accepted_forms, ...]            — Strategy B (accept DeepL form)
#   'multiword': True                             — lemma spans two tokens
#   'skip':      True                             — skip (handled elsewhere/manual)
#
# NOTE: No duplicate keys — Python silently drops the first when keys repeat.
# Merged strategies use both 'sub' and 'variant' in the same dict entry.

STRATEGIES = {

    # ── Conjunctions / connectives ─────────────────────────────────────────────
    'mä':           {'sub': [(['mee'], 'mä')]},
    'obwuel':       {'sub': [(['och wann', 'och wéi'], 'obwuel'),
                             (['trotzdem', 'trotz'], 'obwuel')]},
    'sou datt':     {'multiword': True,
                     'sub': [(['soudatt', 'Sou datt', 'sou datt'], 'sou datt')]},
    'entweeder':    {'sub': [(['Entweder', 'entweder'], 'entweeder')]},
    'weder':        {'sub': [(['weder', 'néng... nach', 'weder'], 'weder')]},
    'dat':          {'sub': [(['datt', 'deen', 'dat'], 'dat')]},
    'datt':         {'sub': [(['dat'], 'datt')]},

    # ── Adverbs of time ────────────────────────────────────────────────────────
    # 'nees' — merged (was duplicated): both find lists combined
    'nees':         {'sub': [(['erëm', 'nach eng Kéier', 'erneut', 'nochmal', 'nees'], 'nees')]},
    'nuets':        {'sub': [(['Nuetshimmel', 'Himmel', 'Nuecht',
                               'an der Nuecht', 'bei Nuecht', 'bei der Nuecht',
                               "an d'Nuecht"], 'nuets')]},
    'mëttes':       {'sub': [(['um Mëtteg', 'zu Mëttes', 'mëtteg', 'am Mëtteg',
                               'Mëtteg'], 'mëttes')]},
    'moies':        {'sub': [(['de Moien', 'am Moien', 'moie', 'Moien'], 'moies')]},
    'owes':         {'sub': [(['den Owend', 'am Owend', 'am Abend', 'Owend'], 'owes')]},
    'heiansdo':     {'sub': [(['gelegentlech', 'manchmal', 'heiansdo'], 'heiansdo')]},
    'momentan':     {'sub': [(['de Moment', 'am Moment', 'aktuell', 'derzeit'], 'momentan')]},
    'spéider':      {'sub': [(['méi spéit', 'méi spéider', 'spéit'], 'spéider')]},
    'fréier':       {'sub': [(['fréi haut', 'fréier', 'fraider', 'virdrun',
                               'vrun', 'virdrum'], 'fréier')]},
    'Ament':        {'sub': [(['de Moment', 'am Moment', 'momentan'], "den Ament")]},
    'Tëschenzäit':  {'sub': [(['ënnerdeems', 'derwäil', 'derweil', 'zwëschenduerch',
                               'inzwëschent', 'tëscht', 'tëschenzeitlech', 'derwäert',
                               'derwäl', 'derwell', 'zwëschenzäitlech',
                               'an der Tëschenzäit'], 'an der Tëschenzäit')]},
    'Mëttegiessen': {'sub': [(['Mëttegiessen', 'Mëttegiess'], 'Mëttegiessen')]},

    # ── Adverbs of frequency / degree ─────────────────────────────────────────
    # 'selten' — merged (was duplicated): added extra variants
    'selten':       {'sub': [(['rar', 'gelegentlech', 'ball ni', 'bal ni',
                               'nearly never', 'selten'], 'selten')]},
    'souguer':      {'sub': [(['sogar', 'och', 'méi'], 'souguer')]},
    'souwisou':     {'sub': [(['wéi och ëmmer', 'awer souwisou', 'sowieso'], 'souwisou')]},
    'zimmlech':     {'sub': [(['ganz', 'zimlech', 'ziemlich', 'ganzen vill'], 'zimmlech')]},
    'grad':         {'sub': [(['genau', 'just', 'aktuell', 'ganz', 'gerade'], 'grad')]},
    'just':         {'sub': [(['nëmmen', 'eegentlech', 'gerade', 'just'], 'just')]},
    'kaum':         {'sub': [(['bal net', 'knapp', 'schriwwens'], 'kaum')]},
    'bal':          {'sub': [(['nach net', 'nach ëmmer net', 'nach ni'], 'bal')]},
    'bestëmmt':     {'sub': [(['definitivt', 'definitiv', 'Definitiv',
                               'bestimmt', 'sécher', 'gewëss'], 'bestëmmt')]},
    'warscheinlech': {'sub': [(['wahrscheinlech', 'Wahrscheinlech', 'wahrscheinlich',
                                'dohinner'], 'warscheinlech')]},
    'vläicht':      {'sub': [(['kéinten', 'vläicht', 'méint'], 'vläicht')]},
    'spéit':        {'sub': [(['décke', 'spéit', 'spéider'], 'spéit')]},

    # ── Adverbs of place ───────────────────────────────────────────────────────
    'néierens':     {'sub': [(['nirgends', 'nirgendou', 'nowhere',
                               'nirgendow', 'Nirgends'], 'néierens')]},
    'derbäi':       {'sub': [(['präsent', 'dobäi', 'dabei', 'derbäi',
                               'deelgeholl', 'Abegraff', 'bei deem',
                               'abegraff'], 'derbäi')]},
    'matten':       {'sub': [(['Mëtt', "d'Mëtt", 'an der Mëtt', 'Mëttestras',
                               'Mëttestrooss', "an d'Mëtt"], 'matten')]},
    'bannen':       {'sub': [(['am Haus', 'hei am', 'an', 'dran',
                               'ëm', 'an der'], 'bannen')]},
    'baussen':      {'sub': [(['dobaussen', 'draussen', 'baussen'], 'baussen')]},

    # ── Nouns (content words) ──────────────────────────────────────────────────
    'Mënsch':       {'sub': [(['Persoun', 'Person', 'Individuum', 'Leit',
                               'Persounen'], 'Mënsch')]},
    'Komerod':      {'sub': [(['Kameraden', 'Kamerod', 'Kamerad',
                               'Genoss', 'Kollege', 'Gefährte'], 'Komerod')]},
    'Duuscht':      {'sub': [(['Duerst', 'Durst', 'Duuscht'], 'Duuscht')]},
    'Heft':         {'sub': [(['Notebook', 'Notizbuch', 'Notizheft',
                               'Hefte', 'Heft'], 'Heft')]},
    'Technik':      {'sub': [(['techneschen', 'Technologie', 'Technik',
                               'technologesch', 'Technologien'], 'Technik')]},
    'Apdikt':       {'sub': [(['Apothek', 'Apotheke', 'Apotheek',
                               'Pharmacie'], 'Apdikt')]},
    'Strof':        {'sub': [(['Straf', 'Strafe'], 'Strof')]},
    'Owendiessen':  {'sub': [(['Owesiessen', 'Iessen owes', 'Abendessen',
                               'mam Iessen', 'iessen', 'iessen Owes',
                               'Owesiess', 'Iess Owes'], 'Owendiessen')]},
    'Léierpersonal': {'sub': [(['Schoulmeeschteren', 'Enseignant', 'Enseignanten',
                                'Schoulmeeschter', 'Léierpersonal', 'Enseignante',
                                'Proff', 'Professer', 'Professeur'], 'Léierpersonal')]},
    'Schüler':      {'sub': [(['Schülerin', 'Schüler', 'Student', 'Studenten',
                               'Élève', 'Schulkind', 'Schoulkand'], 'Schüler')]},
    # 'Vull' — merged (was duplicated): sub + variant together
    'Vull':         {'sub': [(['Vugel', 'Vugelen', 'Vogel', 'Vëgel', 'Vugeler'], 'Vull')],
                     'variant': ['Vull', 'Vullen', 'Vulle']},
    'Bad':          {'sub': [(['Buedzëmmer', 'Badkummer', 'Bued',
                               'Badezimmer'], 'Bad')]},
    'Plaz':         {'sub': [(['Duerfplatz', 'Plaz', 'Platz', 'Plazz'], 'Plaz')]},
    'Donner':       {'sub': [(['Donn', 'Donner'], 'Donner')]},
    'violett':      {'sub': [(['lila', 'Lila', 'violett'], 'violett')]},
    'Geräisch':     {'sub': [(['Toun', 'Kaméidi', 'Geräusch', 'Lärm',
                               'Kaméid', 'Geräisch'], 'Geräisch')]},
    'Erfolleg':     {'sub': [(['erfollegräich', 'méi erfollegräich', 'Succès',
                               'Erfoleg', 'Erfolleg', 'Erfolg', 'succès'], 'Erfolleg')]},
    'Luucht':       {'sub': [(['Liicht', 'Luucht', 'Licht'], 'Luucht')]},
    'Null':         {'sub': [(['null', 'Keng', 'kengem', 'kee'], 'Null')]},
    'Breet':        {'sub': [(['breede', 'breet', 'breden', 'breden'], 'Breet')]},
    'Steen':        {'sub': [(['Stéin', 'Steen', 'Steng', 'Steinfelsen'], 'Steen')]},
    'Quadrat':      {'sub': [(['véiereckeg', 'quadratesch', 'quadrat'], 'Quadrat')]},
    'Geld':         {'sub': [(['Suen', 'suen', 'Geld'], 'Geld')]},
    'Rees':         {'sub': [(['Schoulausfluch', 'Rees', 'Reese',
                               'reesen', 'Reesen'], 'Rees')]},
    'schlecht':     {'sub': [(['schlëmm', 'schlecht', 'Pech', 'schlamm'], 'schlecht')]},
    'Blumm':        {'sub': [(['Blummen', 'Blumm'], 'Blumm')]},
    'Auto':         {'sub': [(['Vëlo', 'Fahrrad', 'Auto'], 'Auto')]},
    'Zil':          {'sub': [(['Haaptzil', 'Ziler', 'Zil', 'Ziel'], 'Zil')]},
    'Ligen':        {'sub': [(['Lügen', 'Lüg', 'Ligen'], 'Ligen')]},
    'Séil':         {'sub': [(['Séilen', 'Seele', 'Séil'], 'Séil')]},
    'Konscht':      {'sub': [(['Zeechnungen', 'Biller', 'Konscht', 'Kunst'], 'Konscht')]},
    'Handel':       {'sub': [(['Beruff', 'Geschäft', 'Handel'], 'Handel')]},
    'Politik':      {'sub': [(['politescher', 'Politik'], 'Politik')]},
    'Wal':          {'sub': [(['Lokalwalen', 'Walen', 'Wahlen', 'Wahl', 'Wal'], 'Wal')]},
    'Bierger':      {'sub': [(['Awunner', 'Bierger'], 'Bierger')]},
    'Geriicht':     {'sub': [(['Riichter', 'Geriicht', 'Gericht'], 'Geriicht')]},
    'Gefor':        {'sub': [(['geféierlech', 'Gefor', 'Gefouer', 'Gefahr'], 'Gefor')]},
    'Noutfall':     {'sub': [(['Noutfäll', 'Notfall', 'Noutfall',
                               'Notausgang', 'Noutausgang'], 'Noutfall')]},
    'Vergaangenheet': {'sub': [(['Geschicht', 'Vergaangenheet', 'Vergaangenhéit',
                                 'Vergangenheet'], 'Vergaangenheet')]},
    'Fräiheet':     {'sub': [(['fräi', 'Fräiheet', 'Freiheit',
                               'Freiheet'], 'Fräiheet')]},
    'Wëssenschaft': {'sub': [(['Wëssenschaft', 'Wissenschaft'], 'Wëssenschaft')]},
    'Gerechtegkeet': {'sub': [(['Geriicht', 'Gerechtegkeet', 'Gerechtigkeit'], 'Gerechtegkeet')]},
    'Déift':        {'sub': [(['déif', 'Déift', 'Tiefe', 'Déiften'], 'Déift')]},
    'Joer':         {'sub': [(['Joren', 'Joer', 'Jahren'], 'Joer')]},
    'Essen':        {'sub': [(['Liewensmëttel', 'Iessen', 'Essen',
                               'Iess', 'Ernährung'], 'Essen')]},
    'Kand':         {'sub': [(['Kanner', 'Kand', 'Kind'], 'Kand')]},
    'Zëmmer':       {'sub': [(['Sall', 'Zëmmer', 'Zimmer'], 'Zëmmer')]},
    'Vëlo':         {'sub': [(['Rennvëlo', 'Vëlo', 'Fahrrad',
                               'Veloen', 'Velo'], 'Vëlo')]},
    'Ouer':         {'sub': [(['Ohrwéi', 'Oueren', 'Ouer', 'Uhr'], 'Ouer')]},
    'Béier':        {'sub': [(['Biersorten', 'Béier', 'Bier'], 'Béier')]},
    'Zopp':         {'sub': [(['Tomatesupp', 'Supp', 'Soupe', 'Zopp'], 'Zopp')]},
    'Saz':          {'sub': [(['Sätzstruktur', 'Saz', 'Satz', 'Säz'], 'Saz')]},
    'Ball':         {'sub': [(['Kugel', 'Ball', 'Bäll'], 'Ball')]},
    'Vakanz':       {'sub': [(['Vakanzrees', 'Vakanz', 'Ferien',
                               'Vakanze', 'Urlaub'], 'Vakanz')]},
    'Sëtz':         {'sub': [(['Setzt', 'Sëtz', 'Sitz', 'Platz'], 'Sëtz')]},
    'Goût':         {'sub': [(['schmaachtlecht', 'Goût', 'Geschmack',
                               'Geschmaach', 'Gout', 'Goust'], 'Goût')]},
    'Schlof':       {'sub': [(['schléift', 'Schlof', 'Schlaf',
                               'Schlofen', 'Schlaaf'], 'Schlof')]},
    'Holz':         {'sub': [(['Bësch', 'Holz', 'Wald'], 'Holz')]},
    'Längt':        {'sub': [(['laang', 'Längt', 'Länge'], 'Längt')]},
    'Hond':         {'sub': [(['Hënn', 'Hond', 'Hund'], 'Hond')]},
    'Klass':        {'sub': [(['Noperen', 'Klass', 'Klasse'], 'Klass')]},
    'Text':         {'sub': [(['Noriichten', 'Text', 'Texten'], 'Text')]},
    'Zuel':         {'sub': [(['Telefonsnummer', 'Zuel', 'Zuel', 'Zahl'], 'Zuel')]},
    'Numm':         {'sub': [(['heescht', 'Numm', 'Name', 'Namen'], 'Numm')]},
    'Angscht':      {'sub': [(['Familljeängschten', 'Angscht', 'Angst'], 'Angscht')]},
    'Dokter':       {'sub': [(['Duerfdokter', 'Dokter', 'Arzt',
                               'Medeziner', 'Dottor'], 'Dokter')]},
    'Gesondheet':   {'sub': [(['gesond', 'Gesondheet', 'Gesundheit',
                               'Gesundheet'], 'Gesondheet')]},
    'lecker':       {'sub': [(['léckeg', 'lecker'], 'lecker')]},
    'Jackett':      {'sub': [(['Jacken', 'Jackett', 'Jacket', 'Veste'], 'Jackett')]},
    'Relioun':      {'sub': [(['Religioun', 'Relioun'], 'Relioun')]},
    'Landwirtschaft': {'sub': [(['Felder', 'Landwirtschaft', 'Acker',
                                 'Bauer', 'Landwirtschaftlech'], 'Landwirtschaft')]},
    'Traditioun':   {'sub': [(['Traditioun', 'Tradition'], 'Traditioun')]},
    'Schwëster':    {'sub': [(['Schwëster', 'Schwester'], 'Schwëster')]},
    'Hoffnung':     {'sub': [(['Hoffnung', 'Hoffen'], 'Hoffnung')]},
    'Gefill':       {'sub': [(['fillt', 'Gefill', 'Gefühl'], 'Gefill')]},
    'Frënd':        {'sub': [(['Frënn', 'Frënd', 'Freund', 'Frond'], 'Frënd')]},
    'Bierg':        {'sub': [(['Hügel', 'Bierg', 'Berg', 'Bergen'], 'Bierg'),],
                     'variant': ['Bierg', 'Bierger', 'Berg', 'Bergen']},
    'Mëttegiessen': {'sub': [(['Mëttegiessen', 'Mëttegiess'], 'Mëttegiessen')]},
    'Aarbecht':     {'sub': [(['Aarbecht', 'Job'], 'Aarbecht')]},
    'wat':          {'sub': [(['wovun', 'wat', 'was'], 'wat')]},
    'aner':         {'sub': [(['anert', 'aner'], 'aner')]},
    'Dier':         {'sub': [(['Haaptdier', 'Dier', 'Door'], 'Dier')]},
    'Schlëssel':    {'sub': [(['Autoschlëssel', 'Schlëssel', 'Schlüssel'], 'Schlëssel')]},
    'Stull':        {'sub': [(['Büro-Stull', 'Bürostull', 'Stull', 'Stuhl',
                               'Stol'], 'Stull')]},
    'Floss':        {'sub': [(['Musel', 'Floss', 'Flüss'], 'Floss')]},
    'Ticket':       {'sub': [(['Zuchsticket', 'Ticket', 'Billet',
                               'Billett', 'Tickets'], 'Ticket')]},
    'Gréisst':      {'sub': [(['grouss', 'Gréisst'], 'Gréisst')]},
    'richteg':      {'sub': [(['korrekt', 'richteg', 'richtig'], 'richteg')],
                     'variant': ['richteg', 'richtig', 'richtegen', 'richteger']},
    'wichteg':      {'sub': [(['bedeitend', 'wichteg'], 'wichteg')],
                     'variant': ['wichteg', 'wichtegen', 'wichteges', 'wichteger']},
    'Léift':        {'sub': [(['Liewen', 'Liebe', 'Léift', 'léif', 'Léib'], 'Léift')]},
    'Recht':        {'sub': [(['richteg', 'korrekt', 'Recht', 'Gesetz'], 'Recht')]},
    'Auer':         {'sub': [(['Stonn', 'Stonnen', 'Auer', 'Uhr', 'Ueren'], 'Auer')]},
    'Feier':        {'sub': [(['Hëtzt', 'brennend', 'Feier'], 'Feier')]},
    'Brudder':      {'sub': [(['Bridder', 'Bréider', 'Bruder', 'Brudder'], 'Brudder')]},
    'jiddereen':    {'sub': [(['alleguerten', 'allesamt', 'jiddereen', 'jidderengem'], 'jiddereen')],
                     'variant': ['jiddereen', 'jidder', 'jidderengem',
                                 'jidderenger', 'jidderee']},
    'Faarf':        {'sub': [(['Faarwen', 'Faarf', 'Farbe', 'Farwen'], 'Faarf'),],
                     'variant': ['Faarf', 'Faarf', 'Farwen']},
    'souguer':      {'sub': [(['sogar', 'och', 'méi'], 'souguer')]},
    'Plang':        {'sub': [(['Pläng', 'Plan', 'Pläng'], 'Plang')]},
    'Kéis':         {'sub': [(['Kéis', 'Käse'], 'Kéis')]},     # was duplicated — single entry
    'Botter':       {'sub': [(['Boter', 'Butter', 'Botter'], 'Botter')]},
    'Dauer':        {'sub': [(['Dauer'], 'Dauer')]},
    'Geméis':       {'sub': [(['Geméis', 'Gemüse'], 'Geméis')]},
    'Uebst':        {'sub': [(['Friichten', 'Uebst', 'Friicht', 'Obst'], 'Uebst')]},
    'Zocker':       {'sub': [(['Zocker'], 'Zocker')]},
    'Ueleg':        {'sub': [(['Ueleg', 'Ueeleg', 'Öl'], 'Ueleg')]},
    'Stëft':        {'sub': [(['Stëft', 'Bleistëft', 'Stift', 'Bleistift'], 'Stëft')]},

    # ── Color/animal story characters ──────────────────────────────────────────
    'Klengt Wisel': {'sub': [(['klengen Wisel', 'kleng Wisel', 'klenge Wisel',
                               'klenges Wisel', 'een', 'Kand', 'Déier',
                               'Maus', 'Wisel'], 'Klengt Wisel')]},
    'Blo Steemärel': {'sub': [(['Himmel', 'Blummen', 'Blumm'], 'Steemärel'),
                               (['blae', 'blo', 'blauen', 'Blauen'], 'Blo'),
                               (['Blo Steemärel', 'blo Steemärel',
                                 'bloe Steemärel'], 'Blo Steemärel')]},
    'Giel Bëschmaus': {'sub': [(['Sonn', 'Bléimchen', 'Muessen',
                                  'Giel Bëschmaus', 'giel Bëschmaus',
                                  'Bëschmaus'], 'Giel Bëschmaus')]},
    'Brong Mierint': {'sub': [(['Hond', 'Maus', 'Déier',
                                'Brong Mierint', 'brong Mierint',
                                'Mierint'], 'Brong Mierint')]},
    'Gro-Zon':      {'sub': [(['Wolleken', 'Wand', 'Loft',
                               'Gro-Zon', 'griis', 'Griis'], 'Gro-Zon')]},

    # ── Pronouns / determiners (variant forms) ─────────────────────────────────
    'eent':         {'variant': ['ee', 'een', 'eent', 'eng', 'engem', 'enger']},
    'keen':         {'variant': ['keen', 'kee', 'keng', 'keenge', 'kengem',
                                 'keiner', 'keeng']},
    'säin':         {'variant': ['säi', 'säin', 'seng', 'sengem', 'senger',
                                 'sengen']},
    'eist':         {'variant': ['eist', 'eis', 'eisem', 'eiser', 'eise', 'eisen']},
    'déi':          {'variant': ['déi', 'si', 'hinnen', 'hir', 'hinnen']},
    'dir':          {'variant': ['dir', 'du', 'Iech', 'iech', 'Äre', 'äre']},
    'dëst':         {'variant': ['dëst', 'dësen', 'dëser', 'dësem', 'dat', 'des']},
    'dësen':        {'variant': ['dëst', 'dësen', 'dëser', 'dësem', 'dat', 'des']},
    'däin':         {'variant': ['däin', 'däi', 'däng', 'denger', 'dengem']},
    'äert':         {'variant': ['äert', 'äre', 'ärer', 'ärem', 'äre', 'Äre']},
    'mäin':         {'variant': ['mäin', 'mäi', 'meng', 'mengem', 'menger', 'menge']},
    'him':          {'variant': ['him', 'hien', 'hie', 'en']},
    'hir':          {'variant': ['hir', 'si', 'hatt']},
    'mech':         {'variant': ['mech', 'mir', 'ech']},
    'dech':         {'variant': ['dech', 'dir', 'du']},
    'iech':         {'variant': ['iech', 'dir', 'Iech']},
    'si':           {'variant': ['si', 'hatt', 'hir']},
    'hien':         {'variant': ['hien', 'hie', 'en', 'him']},
    'du':           {'variant': ['du', 'dir', 'dech']},
    'et':           {'variant': ['et', 'dat', 'deen', 'et', 'en']},
    'fir':          {'variant': ['fir', 'firer', 'firwat', 'fuerden']},
    'op':           {'variant': ['op', 'op', 'uewen']},
    'an':           {'variant': ['an', 'a', 'am', 'an der', 'an dem']},
    'vun':          {'variant': ['vun', 'vu', 'vum', 'vun']},
    'mat':          {'variant': ['mat', 'mam', 'mat']},
    'den':          {'variant': ['den', 'de', 'dem', 'd', 'der']},
    'wéi':          {'variant': ['wéi', 'wéini', 'wou', 'wei']},
    'wann':         {'variant': ['wann', 'wéini', 'wa']},
    'méi':          {'variant': ['méi', 'me', 'méi']},
    'net':          {'variant': ['net', 'nit', 'net']},
    'och':          {'variant': ['och', 'och']},

    # ── Inflected nouns (accept plural/case form) ──────────────────────────────
    'Apel':         {'variant': ['Apel', 'Äppel', 'Äppelen', 'Apel']},
    'Bam':          {'variant': ['Bam', 'Beem', 'Bäm', 'Baum']},
    'Hand':         {'variant': ['Hand', 'Hänn', 'Handen', 'Hänn']},
    'Zwee':         {'variant': ['zwee', 'zwou', 'zwei', 'zwou', 'zwéin']},
    'Kopp':         {'variant': ['Kopp', 'Kapp', 'Käpp']},
    'Linn':         {'variant': ['Linn', 'Linnen', 'Linn']},

    # ── Adjectives ────────────────────────────────────────────────────────────
    'jonk':         {'variant': ['jonk', 'jonkt', 'jonken', 'jonker', 'jonkst']},
    'schéin':       {'variant': ['schéin', 'schéint', 'schéinen', 'schéiner',
                                 'schéi', 'schein']},
    'méiglech':     {'sub': [(['méiglech', 'mëglech', 'möglech'], 'méiglech')]},
    'nächst':       {'variant': ['nächst', 'nächsten', 'nächste', 'nächster']},
    'besonnesch':   {'sub': [(['besonnesch', 'besondes'], 'besonnesch')]},
    'deier':        {'variant': ['deier', 'deieren', 'deier']},
    'bëlleg':       {'variant': ['bëlleg', 'bëllege', 'bëllegem', 'bëllegen']},

    # ── Other nouns / misc ────────────────────────────────────────────────────
    'Regierung':    {'sub': [(['Regierung', 'Regirung'], 'Regierung')]},
    'Sécherheet':   {'sub': [(['Sécherheet', 'Sicherheet', 'Sicherheit'], 'Sécherheet')]},
    'Accident':     {'sub': [(['Accident'], 'Accident')]},
    'Gléck':        {'sub': [(['Gléck', 'Glück'], 'Gléck')]},
    'Dram':         {'sub': [(['Dram', 'Dreem', 'Dreamer'], 'Dram')]},
    'Kraaft':       {'sub': [(['Kraaft', 'Kraft', 'Mächt'], 'Kraaft')]},
    'Täsch':        {'sub': [(['Tasch', 'Täsch', 'Tasche', 'Sak'], 'Täsch')]},
    'Kleed':        {'sub': [(['Kleed', 'Kleeder'], 'Kleed')]},
    'Bild':         {'sub': [(['Bild', 'Photo', 'Foto', 'Biller'], 'Bild')]},
    'Gewiicht':     {'sub': [(['Gewiicht'], 'Gewiicht')]},
    'Héicht':       {'sub': [(['Héicht'], 'Héicht')]},
    'Geroch':       {'sub': [(['Geroch'], 'Geroch')]},
    'Krees':        {'sub': [(['Krees'], 'Krees')]},
    'Kultur':       {'sub': [(['Kultur'], 'Kultur')]},
    'Box':          {'sub': [(['Hose', 'Hosen', 'Box', 'Buxe'], 'Box')]},
    'Wahlen':       {'sub': [(['Wahlen'], 'Wahlen')]},
    'Natur':        {'sub': [(['Natur'], 'Natur')]},
    'Planzen':      {'sub': [(['Planzen', 'Pflanzen'], 'Planzen')]},
    'Insekt':       {'sub': [(['Insekt'], 'Insekt')]},
    'Päerd':        {'sub': [(['Päerd'], 'Päerd')]},
    'Kaz':          {'sub': [(['Kaz'], 'Kaz')]},
    'Telefon':      {'sub': [(['Telefon', 'Handy', 'Portable'], 'Telefon')]},
    'Kaart':        {'sub': [(['Kaart'], 'Kaart')]},
    'Äerd':         {'sub': [(['Äerd', 'Erd', 'Ërd', 'Buedem'], 'Äerd')]},
    'Ufank':        {'sub': [(['Ufank', 'Anfank'], 'Ufank')]},
    'Säit':         {'sub': [(['Säit', 'Seite'], 'Säit')]},
    'Mëtt':         {'sub': [(['Mëtt'], 'Mëtt')]},
    'Enn':          {'sub': [(['Enn', 'End'], 'Enn')]},
    'Geschicht':    {'sub': [(['Geschicht', 'Geschichte'], 'Geschicht')]},
    'Sprooch':      {'sub': [(['Sprooch', 'Sproochen', 'Sprache'], 'Sprooch')]},
    'Buch':         {'sub': [(['Buch', 'Bicher'], 'Buch')]},
    'Loft':         {'sub': [(['Loft'], 'Loft')]},
    'Schong':       {'sub': [(['Schong'], 'Schong')]},
    'Metall':       {'sub': [(['Metall'], 'Metall')]},
    'Musek':        {'sub': [(['Musek', 'Musik'], 'Musek')]},
    'Gaart':        {'sub': [(['Gaart', 'Garten'], 'Gaart')]},
    'Duerf':        {'sub': [(['Duerf', 'Dorf'], 'Duerf')]},
    'Stad':         {'sub': [(['Stad', 'Stadt'], 'Stad')]},
    'Schoul':       {'sub': [(['Schoul', 'Schule'], 'Schoul')]},
    'Kichen':       {'sub': [(['Kichen', 'Kiche', 'Küche'], 'Kichen')]},
    'Wand':         {'sub': [(['Wand'], 'Wand')]},
    'Elteren':      {'sub': [(['Elteren'], 'Elteren')]},
    'Téi':          {'sub': [(['Téi', 'Tee'], 'Téi')]},
    'Gedanken':     {'sub': [(['Gedanken'], 'Gedanken')]},
    'Iddi':         {'sub': [(['Iddi', 'Idée', 'Idee'], 'Iddi')]},
    'Stëmm':        {'sub': [(['Stëmm'], 'Stëmm')]},
    'Hëllef':       {'sub': [(['Hëllef'], 'Hëllef')]},
    'Léisung':      {'sub': [(['Léisung', 'Lösung'], 'Léisung')]},
    'Zesummenaarbecht': {'sub': [(['Zesummenaarbecht', 'Zesummeaarbecht',
                                   'Zusammenarbeit'], 'Zesummenaarbecht')]},
    'Ënnerstëtzung': {'sub': [(['Ënnerstëtzung', 'Unterstëtzung',
                                'Unterstützung'], 'Ënnerstëtzung')]},
    'Fridden':      {'sub': [(['Fridden'], 'Fridden')]},
    'Krich':        {'sub': [(['Krich'], 'Krich')]},
    'Staat':        {'sub': [(['Staat'], 'Staat')]},
    'Alter':        {'sub': [(['Alter', 'Al'], 'Alter')]},

    # ── Directional adverbs ───────────────────────────────────────────────────
    'riets':        {'sub': [(['riets', 'riet'], 'riets')]},
    'lénks':        {'sub': [(['lénks', 'lénk'], 'lénks')]},
    'uewen':        {'sub': [(['uewen', 'uewe'], 'uewen')]},
    'ënnen':        {'sub': [(['ënnen', 'ënnert', 'ënne'], 'ënnen')]},
    'hannen':       {'sub': [(['hannen', 'hanne', 'hannt'], 'hannen')]},

    # ── Other adverbs / prepositions ──────────────────────────────────────────
    'zënter':       {'sub': [(['säit', 'zënter'], 'zënter')]},
    'bis':          {'sub': [(['bis'], 'bis')]},
    'direkt':       {'sub': [(['direkt'], 'direkt')]},
    'natierlech':   {'sub': [(['natierlech', 'natürlich'], 'natierlech')]},
    'sécher':       {'sub': [(['sécher', 'sicher'], 'sécher')]},
    'einfach':      {'sub': [(['einfach'], 'einfach')]},
    'hanner':       {'sub': [(['hannert', 'hanner'], 'hanner')]},
    'tëscht':       {'sub': [(['tëscht', 'tëschenzeitlech'], 'tëscht')]},
    'duerch':       {'sub': [(['duerch'], 'duerch')]},
    'wärend':       {'sub': [(['während', 'wärend'], 'wärend')]},
    'haut':         {'sub': [(['haut'], 'haut')]},
    'muer':         {'sub': [(['muer', 'moien', 'Moien'], 'muer')]},
    'gëschter':     {'sub': [(['gëschter'], 'gëschter')]},
    'nach':         {'sub': [(['nach'], 'nach')]},
    'schonn':       {'sub': [(['schonn', 'schon', 'scho'], 'schonn')]},
    'elo':          {'sub': [(['elo'], 'elo')]},
    'selwer':       {'sub': [(['selwer', 'selber'], 'selwer')]},
    'bëssen':       {'sub': [(['e bësschen', 'e wéineg', 'wéineg'], 'e bëssen')]},
    'genuch':       {'sub': [(['genuch', 'genug'], 'genuch')]},

    # ── Numerals ──────────────────────────────────────────────────────────────
    'Aacht':        {'variant': ['aacht', 'acht', '8']},
    'Néng':         {'variant': ['néng', 'néng', '9']},
    'honnert':      {'variant': ['honnert', 'hundert', '100']},
    'dausend':      {'variant': ['dausend', 'tausend', '1000']},
}


def process_item(item):
    """Process one review item. Returns result dict or None."""
    word_lu    = item['word_lu']
    lemma_l    = word_lu.lower()
    deepl_lu   = item.get('deepl_lu', '')
    text_en    = item['text_en']
    diff       = item.get('difficulty', 'simple')

    strat = STRATEGIES.get(word_lu)
    is_multiword = ' ' in lemma_l or (strat and strat.get('multiword'))

    if strat and 'sub' in strat and deepl_lu:
        # Strategy A: word substitution in DeepL output
        fixed = deepl_lu
        for find_list, repl in strat['sub']:
            new_fixed = substitute(fixed, find_list, repl)
            # Check if the target word (or first word of multiword) is now in the text
            if is_multiword:
                idx = find_multiword_idx(lemma_l, new_fixed)
            else:
                idx = find_lemma_idx(lemma_l, new_fixed)
            if idx is not None:
                fixed = new_fixed
                break
            fixed = new_fixed  # keep accumulated substitutions even if target not found yet
        result = make_result(lemma_l, fixed, text_en, diff)
        if result:
            return result

    if strat and 'variant' in strat and deepl_lu:
        # Strategy B: accept DeepL but point cloze_index at the variant form
        result = make_variant_result(strat['variant'], deepl_lu, text_en, diff)
        if result:
            return result

    # Last resort: if target word happens to already be in deepl_lu
    if deepl_lu:
        result = make_result(lemma_l, deepl_lu, text_en, diff)
        if result:
            return result

    return None   # truly unfixable


def main():
    dry_run = '--dry-run' in sys.argv

    with open(UNFIXED_PATH, encoding='utf-8') as f:
        items = json.load(f)

    print(f'Processing {len(items)} unfixed items…')

    fixed      = {}   # sentence_id → result
    still_bad  = []

    for item in items:
        result = process_item(item)
        if result:
            fixed[item['sentence_id']] = result
        else:
            still_bad.append(item)

    print(f'Fixed by rules:    {len(fixed)}')
    print(f'Still unfixed:     {len(still_bad)}')

    if dry_run:
        print('\n[DRY RUN — no changes written]')
        for sid, r in list(fixed.items())[:10]:
            print(f'  {sid}: {r["text_lu"]!r}')
        return

    # Apply to seed
    with open(SEED_PATH, encoding='utf-8') as f:
        data = json.load(f)

    updated = 0
    for sent in data['sentences']:
        r = fixed.get(sent['sentence_id'])
        if r:
            sent['text_lu']          = r['text_lu']
            sent['text_en']          = r['text_en']
            sent['cloze_index']      = r['cloze_index']
            sent['exact_form']       = r['exact_form']
            sent['cloze_confidence'] = r['cloze_confidence']
            sent.pop('n_rule_form', None)
            sent.pop('n_rule_word_index', None)
            updated += 1

    data['version'] = round(data.get('version', 7.0) + 0.1, 1)
    with open(SEED_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f'\nSeed updated: {updated} sentences. Version → {data["version"]}')

    # Save remaining for next pass
    if still_bad:
        with open(UNFIXED_PATH, 'w', encoding='utf-8') as f:
            json.dump(still_bad, f, ensure_ascii=False, indent=2)
        print(f'{len(still_bad)} items saved to {UNFIXED_PATH} for further review.')
    else:
        print('All items fixed! No remaining items.')

if __name__ == '__main__':
    main()
