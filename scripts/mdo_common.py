"""Shared helpers for the Niger MDO pipeline: file list, name normalisation, disease and district mapping."""
import os
import re
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw")
SHP = os.path.join(ROOT, "data", "shp")
OUT = os.path.join(ROOT, "data", "processed")

# one weekly workbook per year (2024: the S43 workbook; the DHIS2 extract is parsed separately)
FILES = {
    2015: "MDO_Niger Semaine_2015-53.xls",
    2016: "MDO_Niger Semaine_52 2016.xls",
    2017: "MDO_Niger Semaine_2017-52.xls",
    2018: "MDO_Niger Semaines 1 à 52 2018.xls",
    2019: "MDO_Niger Semaine 52 2019.xlsx",
    2020: "MDO_Niger Semaine 53 2020.xls",
    2021: "MDO_Niger Semaine 52 2021.xlsx",
    2022: "MDO_NIGER 2022 S52.xlsx",
    2023: "MDO 2023 S52.xls",
    2024: "MDO 2024 S43.xls",
}
DHIS2_FILE = "MDO_S1-S37_2024_Extrait_DHIS2-18-09-24.xls"


def raw_path(name):
    return os.path.join(RAW, name)


def out_path(name):
    os.makedirs(OUT, exist_ok=True)
    return os.path.join(OUT, name)


def norm(s):
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


# ordered: first matching rule wins
DISEASE_RULES = [
    (r"palu.*(fe|fem|enc)", "Paludisme (femmes enceintes)"),
    (r"palu.*conf|confirm palu", "Paludisme confirmé"),
    (r"palu", "Paludisme suspect"),
    (r"maln.*mod|mal mod|malnut moder", "Malnutrition modérée"),
    (r"maln.*sev|mal sev|malnut sev", "Malnutrition sévère"),
    (r"rougeole|^rou$", "Rougeole"),
    (r"mening|^men$", "Méningite"),
    (r"chol|^cho$", "Choléra"),
    (r"coq", "Coqueluche"),
    (r"tnn|tetanos nn|tetanos neonat", "Tétanos néonatal"),
    (r"autres? tet", "Autre tétanos"),
    (r"jaune|susp fj", "Fièvre jaune (suspect)"),
    (r"pfa", "PFA"),
    (r"diarr?h", "Diarrhée sanglante"),
    (r"dipht|^diph$", "Diphtérie"),
    (r"rage", "Rage"),
    (r"ver (de )?guin", "Ver de Guinée"),
    (r"grippe", "Grippe"),
    (r"ebola", "Ebola"),
    (r"rift", "Fièvre de la vallée du Rift"),
    (r"fievre vr", "Fièvres hémorragiques virales"),
    (r"hepatite", "Hépatite virale E"),
    (r"covid", "COVID-19"),
    (r"dengue", "Dengue"),
    (r"sras", "SRAS"),
    (r"mers", "MERS-CoV"),
]


def disease_of(label):
    n = norm(label)
    for pat, name in DISEASE_RULES:
        if re.search(pat, n):
            return name
    return None


DISTRICTS = [
    "Abala", "Abalak", "Aderbissinat", "Agadez", "Aguié", "Arlit", "Ayorou", "Bagaroua", "Balleyara",
    "Banibangou", "Bankilaré", "Belbédji", "Bermo", "Bilma", "Birni N'Konni", "Boboye", "Bosso", "Bouza",
    "Dakoro", "Damagaram Takaya", "Diffa", "Dioundiou", "Dogon-Doutchi", "Dosso", "Dungass", "Falmey",
    "Filingué", "Gaya", "Gazaoua", "Gothèye", "Goudoumaria", "Gouré", "Guidan-Roumdji", "Iférouane",
    "Illéla", "Ingall", "Keita", "Kollo", "Loga", "Madaoua", "Madarounfa", "Magaria", "Malbaza", "Maradi",
    "Matamèye", "Mayahi", "Maïné Soroa", "Mirriah", "N'Gourti", "N'Guigmi", "Niamey 1", "Niamey 2",
    "Niamey 3", "Niamey 4", "Niamey 5", "Ouallam", "Say", "Tahoua", "Tahoua Commune", "Tahoua Département",
    "Takeita", "Tanout", "Tassara", "Tchintabaraden", "Tchirozérine", "Tesker", "Tessaoua", "Tibiri",
    "Tillabéri", "Tillia", "Torodi", "Téra", "Zinder",
]
_CANON = {norm(d): d for d in DISTRICTS}

# spellings and abbreviations found in the workbooks and the DHIS2 extract (normalised keys)
_ALIASES = {
    "ayerou": "ayorou", "blebedji": "belbedji", "d takaya": "damagaram takaya", "damagaram t": "damagaram takaya",
    "damagam takaya": "damagaram takaya", "doungas": "dungass", "doutchi ds": "dogon doutchi",
    "doutchi": "dogon doutchi", "gaya ds": "gaya", "falmeye": "falmey", "maradi ville": "maradi",
    "maradi commune": "maradi", "tahoua com": "tahoua commune", "tahoua ville": "tahoua commune",
    "tahoua dep": "tahoua departement", "tahoua dept": "tahoua departement", "aderbissanat": "aderbissinat",
    "tchiro": "tchirozerine", "maine": "maine soroa", "g roumdji": "guidan roumdji", "konni": "birni n konni",
    "birni nkonni": "birni n konni", "tchinta": "tchintabaraden", "ifferouane": "iferouane",
    "taketa": "takeita", "ngourti": "n gourti", "nguigmi": "n guigmi", "zinder ville": "zinder",
    "niamey i": "niamey 1", "niamey ii": "niamey 2", "niamey iii": "niamey 3", "niamey iv": "niamey 4",
    "niamey v": "niamey 5", "agadez commune": "agadez", "tillaberi commune": "tillaberi",
    "birni konni": "birni n konni", "damgaram takaya": "damagaram takaya", "dioundou": "dioundiou",
    "doungass": "dungass", "fillingue": "filingue", "tillabery": "tillaberi",
}


def canon_district(s):
    k = norm(re.sub(r"^\s*DS\s+", "", str(s)))
    k = _ALIASES.get(k, k)
    return _CANON.get(k)


REGIONS = ["Agadez", "Diffa", "Dosso", "Maradi", "Niamey", "Tahoua", "Tillabéri", "Zinder"]
_REG = {norm(r): r for r in REGIONS}


def canon_region(s):
    return _REG.get(norm(s))


TOTAL_RE = re.compile(r"total|^niger$|^pays|^national|^ensemble")


def num(v):
    try:
        x = float(v)
    except (TypeError, ValueError):
        return None
    return None if x != x else x
