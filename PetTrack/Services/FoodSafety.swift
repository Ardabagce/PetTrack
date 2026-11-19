import Foundation

/// Offline "Can my pet eat this?" reference for dogs and cats.
///
/// Compiled from ASPCA Animal Poison Control, Pet Poison Helpline and veterinary toxicology references.
/// It is a first-aid guide, not a diagnosis: anything marked toxic means "call your vet now".
enum FoodSafety {
    enum Level: Int, Comparable {
        case safe = 0, caution, toxic, emergency

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .safe: "Safe in moderation"
            case .caution: "Caution"
            case .toxic: "Toxic"
            case .emergency: "Emergency – call a vet now"
            }
        }
    }

    enum Category: String {
        case food, drink, plant, household, medicine
    }

    struct Item: Identifiable {
        let id: String
        let category: Category
        /// Display name per language code; English is the fallback.
        let names: [String: String]
        let dog: Level
        let cat: Level
        let note: String

        var name: String {
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            return names[code] ?? names["en"] ?? id
        }

        func level(for species: Species) -> Level {
            switch species {
            case .cat: cat
            case .dog: dog
            default: max(dog, cat)
            }
        }

        func matches(_ query: String) -> Bool {
            let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            return names.values.contains { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(needle) }
        }
    }

    struct Hotline: Identifiable {
        let id: String
        let name: String
        let phone: String
        let note: LocalizedStringResource
    }

    /// Animal poison hotlines by region. Elsewhere: call your vet or the nearest emergency clinic.
    static func hotlines(region: String? = Locale.current.region?.identifier) -> [Hotline] {
        switch region {
        case "US", "CA":
            return [
                Hotline(id: "aspca", name: "ASPCA Animal Poison Control", phone: "+1 888 426 4435", note: "24/7 · a consultation fee may apply"),
                Hotline(id: "pph", name: "Pet Poison Helpline", phone: "+1 855 764 7661", note: "24/7 · a consultation fee may apply"),
            ]
        case "GB", "IE":
            return [Hotline(id: "apl", name: "Animal PoisonLine", phone: "+44 1202 509000", note: "24/7 · a consultation fee may apply")]
        default:
            return []
        }
    }

    static let items: [Item] = [
        // Emergencies
        Item(id: "chocolate", category: .food, names: ["en": "Chocolate & cocoa", "es": "Chocolate y cacao", "de": "Schokolade & Kakao", "fr": "Chocolat & cacao", "nl": "Chocolade & cacao"],
             dog: .emergency, cat: .emergency, note: "Theobromine and caffeine. Dark and baking chocolate are the most dangerous. Vomiting, restlessness, fast heartbeat, seizures."),
        Item(id: "grapes", category: .food, names: ["en": "Grapes & raisins", "es": "Uvas y pasas", "de": "Weintrauben & Rosinen", "fr": "Raisins & raisins secs", "nl": "Druiven & rozijnen"],
             dog: .emergency, cat: .toxic, note: "Can cause sudden kidney failure, even in small amounts. Includes currants and sultanas."),
        Item(id: "xylitol", category: .food, names: ["en": "Xylitol (sugar-free gum, sweets)", "es": "Xilitol (chicles sin azúcar)", "de": "Xylit (zuckerfreier Kaugummi)", "fr": "Xylitol (chewing-gum sans sucre)", "nl": "Xylitol (suikervrije kauwgom)"],
             dog: .emergency, cat: .toxic, note: "Causes a dangerous drop in blood sugar within minutes and liver damage. Check peanut butter labels."),
        Item(id: "lily", category: .plant, names: ["en": "Lilies", "es": "Lirios", "de": "Lilien", "fr": "Lys", "nl": "Lelies"],
             dog: .caution, cat: .emergency, note: "For cats every part is deadly, even pollen or vase water: acute kidney failure."),
        Item(id: "antifreeze", category: .household, names: ["en": "Antifreeze", "es": "Anticongelante", "de": "Frostschutzmittel", "fr": "Antigel", "nl": "Antivries"],
             dog: .emergency, cat: .emergency, note: "Ethylene glycol tastes sweet. A few licks can be fatal. Treatment must start within hours."),
        Item(id: "ratpoison", category: .household, names: ["en": "Rat & mouse poison", "es": "Raticida", "de": "Rattengift", "fr": "Mort-aux-rats", "nl": "Rattengif"],
             dog: .emergency, cat: .emergency, note: "Bring the packaging to the vet: the treatment depends on the active ingredient."),
        Item(id: "paracetamol", category: .medicine, names: ["en": "Paracetamol / acetaminophen", "es": "Paracetamol", "de": "Paracetamol", "fr": "Paracétamol", "nl": "Paracetamol"],
             dog: .toxic, cat: .emergency, note: "A single tablet can kill a cat. Never give human painkillers without a vet."),
        Item(id: "ibuprofen", category: .medicine, names: ["en": "Ibuprofen & naproxen", "es": "Ibuprofeno", "de": "Ibuprofen", "fr": "Ibuprofène", "nl": "Ibuprofen"],
             dog: .emergency, cat: .emergency, note: "Stomach ulcers and kidney failure."),
        Item(id: "permethrin", category: .medicine, names: ["en": "Dog flea treatment (permethrin) on cats", "es": "Antipulgas de perro (permetrina) en gatos", "de": "Hunde-Flohmittel (Permethrin) bei Katzen", "fr": "Antipuces pour chien (perméthrine) sur un chat", "nl": "Vlooienmiddel voor honden (permethrine) bij katten"],
             dog: .safe, cat: .emergency, note: "Causes tremors and seizures in cats. Wash off with mild dish soap and call a vet."),
        Item(id: "macadamia", category: .food, names: ["en": "Macadamia nuts", "es": "Nueces de macadamia", "de": "Macadamianüsse", "fr": "Noix de macadamia", "nl": "Macadamianoten"],
             dog: .toxic, cat: .toxic, note: "Weakness in the back legs, tremors and fever within 12 hours."),
        Item(id: "onion", category: .food, names: ["en": "Onion, garlic, leek, chives", "es": "Cebolla, ajo, puerro", "de": "Zwiebel, Knoblauch, Lauch", "fr": "Oignon, ail, poireau", "nl": "Ui, knoflook, prei"],
             dog: .toxic, cat: .toxic, note: "Damages red blood cells, raw, cooked or powdered. Cats are more sensitive. Signs can appear days later."),
        Item(id: "alcohol", category: .drink, names: ["en": "Alcohol", "es": "Alcohol", "de": "Alkohol", "fr": "Alcool", "nl": "Alcohol"],
             dog: .emergency, cat: .emergency, note: "Even small amounts cause low blood sugar, low body temperature and breathing problems."),
        Item(id: "dough", category: .food, names: ["en": "Raw yeast dough", "es": "Masa cruda con levadura", "de": "Roher Hefeteig", "fr": "Pâte crue à la levure", "nl": "Rauw gistdeeg"],
             dog: .emergency, cat: .emergency, note: "Expands in the stomach and produces alcohol."),
        Item(id: "caffeine", category: .drink, names: ["en": "Coffee, tea & energy drinks", "es": "Café, té y bebidas energéticas", "de": "Kaffee, Tee & Energydrinks", "fr": "Café, thé & boissons énergisantes", "nl": "Koffie, thee & energiedrank"],
             dog: .toxic, cat: .toxic, note: "Caffeine: restlessness, fast heartbeat, tremors. Coffee grounds and pills are the most concentrated."),
        Item(id: "nicotine", category: .household, names: ["en": "Cigarettes & e-liquid", "es": "Cigarrillos y líquido de vapeo", "de": "Zigaretten & E-Liquid", "fr": "Cigarettes & e-liquide", "nl": "Sigaretten & e-liquid"],
             dog: .emergency, cat: .emergency, note: "Nicotine acts within an hour: vomiting, drooling, tremors."),
        Item(id: "cannabis", category: .household, names: ["en": "Cannabis & edibles", "es": "Cannabis", "de": "Cannabis", "fr": "Cannabis", "nl": "Cannabis"],
             dog: .toxic, cat: .toxic, note: "Wobbliness, dribbling urine, low heart rate. Edibles may also contain chocolate or xylitol."),
        Item(id: "vitaminD", category: .medicine, names: ["en": "Vitamin D & iron supplements", "es": "Suplementos de vitamina D y hierro", "de": "Vitamin-D- & Eisenpräparate", "fr": "Vitamine D & fer", "nl": "Vitamine D & ijzer"],
             dog: .toxic, cat: .toxic, note: "Overdoses damage the kidneys and liver."),
        Item(id: "sago", category: .plant, names: ["en": "Sago palm", "es": "Palma sagú", "de": "Palmfarn", "fr": "Sagoutier", "nl": "Palmvaren"],
             dog: .emergency, cat: .emergency, note: "Seeds are the most toxic part; liver failure."),
        Item(id: "bulbs", category: .plant, names: ["en": "Tulip & daffodil bulbs", "es": "Bulbos de tulipán y narciso", "de": "Tulpen- & Narzissenzwiebeln", "fr": "Bulbes de tulipe & jonquille", "nl": "Tulpen- & narcisbollen"],
             dog: .toxic, cat: .toxic, note: "Vomiting, diarrhoea, drooling; heart problems in large amounts."),
        Item(id: "essentialOils", category: .household, names: ["en": "Essential oils (tea tree etc.)", "es": "Aceites esenciales", "de": "Ätherische Öle", "fr": "Huiles essentielles", "nl": "Etherische oliën"],
             dog: .toxic, cat: .emergency, note: "Cats can't break them down. Tea tree, eucalyptus, peppermint and citrus oils are common culprits."),
        Item(id: "cherryPits", category: .food, names: ["en": "Cherry, peach & plum pits", "es": "Huesos de cereza, melocotón y ciruela", "de": "Kirsch-, Pfirsich- & Pflaumenkerne", "fr": "Noyaux de cerise, pêche & prune", "nl": "Pitten van kers, perzik & pruim"],
             dog: .toxic, cat: .toxic, note: "Cyanide in the pits and a choking or blockage risk. The flesh alone is fine."),
        Item(id: "nutmeg", category: .food, names: ["en": "Nutmeg", "es": "Nuez moscada", "de": "Muskatnuss", "fr": "Noix de muscade", "nl": "Nootmuskaat"],
             dog: .toxic, cat: .toxic, note: "Disorientation and fast heartbeat in larger amounts."),
        Item(id: "hops", category: .plant, names: ["en": "Hops", "es": "Lúpulo", "de": "Hopfen", "fr": "Houblon", "nl": "Hop"],
             dog: .emergency, cat: .toxic, note: "Can cause a life-threatening fever in dogs."),
        Item(id: "mushrooms", category: .plant, names: ["en": "Wild mushrooms", "es": "Setas silvestres", "de": "Wilde Pilze", "fr": "Champignons sauvages", "nl": "Wilde paddenstoelen"],
             dog: .emergency, cat: .emergency, note: "Assume any wild mushroom is toxic. Take a photo or sample to the vet."),
        Item(id: "batteries", category: .household, names: ["en": "Batteries", "es": "Pilas", "de": "Batterien", "fr": "Piles", "nl": "Batterijen"],
             dog: .emergency, cat: .emergency, note: "Button batteries burn the oesophagus within hours. Do not make your pet vomit."),

        // Caution
        Item(id: "bones", category: .food, names: ["en": "Cooked bones", "es": "Huesos cocidos", "de": "Gekochte Knochen", "fr": "Os cuits", "nl": "Gekookte botten"],
             dog: .caution, cat: .caution, note: "Splinter and can cause choking or tears in the gut."),
        Item(id: "dairy", category: .food, names: ["en": "Milk & dairy", "es": "Leche y lácteos", "de": "Milch & Milchprodukte", "fr": "Lait & produits laitiers", "nl": "Melk & zuivel"],
             dog: .caution, cat: .caution, note: "Most adult cats and many dogs are lactose intolerant: diarrhoea."),
        Item(id: "cheese", category: .food, names: ["en": "Cheese", "es": "Queso", "de": "Käse", "fr": "Fromage", "nl": "Kaas"],
             dog: .caution, cat: .caution, note: "A small cube is fine as a treat. High in fat and salt."),
        Item(id: "fattyMeat", category: .food, names: ["en": "Fatty meat, bacon & ham", "es": "Carne grasa, beicon y jamón", "de": "Fettes Fleisch, Speck & Schinken", "fr": "Viande grasse, lard & jambon", "nl": "Vet vlees, spek & ham"],
             dog: .caution, cat: .caution, note: "Can trigger pancreatitis. Very salty."),
        Item(id: "salt", category: .food, names: ["en": "Salty snacks", "es": "Snacks salados", "de": "Salzige Snacks", "fr": "Snacks salés", "nl": "Zoute snacks"],
             dog: .caution, cat: .caution, note: "Large amounts (salt dough, rock salt) are an emergency."),
        Item(id: "avocado", category: .food, names: ["en": "Avocado", "es": "Aguacate", "de": "Avocado", "fr": "Avocat", "nl": "Avocado"],
             dog: .caution, cat: .caution, note: "Mild stomach upset for dogs and cats; the pit is a blockage risk. Very toxic to birds and rabbits."),
        Item(id: "rawFish", category: .food, names: ["en": "Raw fish", "es": "Pescado crudo", "de": "Roher Fisch", "fr": "Poisson cru", "nl": "Rauwe vis"],
             dog: .caution, cat: .caution, note: "Parasites; some raw fish destroys vitamin B1 in cats if fed often."),
        Item(id: "tuna", category: .food, names: ["en": "Canned tuna", "es": "Atún en lata", "de": "Thunfisch aus der Dose", "fr": "Thon en boîte", "nl": "Tonijn uit blik"],
             dog: .caution, cat: .caution, note: "Fine occasionally (in water, not oil). Not as a regular meal."),
        Item(id: "corncob", category: .food, names: ["en": "Corn on the cob", "es": "Mazorca de maíz", "de": "Maiskolben", "fr": "Épi de maïs", "nl": "Maiskolf"],
             dog: .caution, cat: .caution, note: "Kernels are fine; the cob is a common cause of intestinal blockage."),
        Item(id: "tomato", category: .food, names: ["en": "Tomato", "es": "Tomate", "de": "Tomate", "fr": "Tomate", "nl": "Tomaat"],
             dog: .caution, cat: .caution, note: "Ripe flesh is fine; leaves, stems and green tomatoes are irritating."),
        Item(id: "catFood", category: .food, names: ["en": "Dog food for cats", "es": "Pienso de perro para gatos", "de": "Hundefutter für Katzen", "fr": "Croquettes pour chien pour un chat", "nl": "Hondenvoer voor katten"],
             dog: .safe, cat: .caution, note: "Lacks taurine. Fine once, harmful as a diet."),
        Item(id: "poinsettia", category: .plant, names: ["en": "Poinsettia", "es": "Flor de Pascua", "de": "Weihnachtsstern", "fr": "Poinsettia", "nl": "Kerstster"],
             dog: .caution, cat: .caution, note: "Mild mouth and stomach irritation. Less dangerous than its reputation."),

        // Safe in moderation
        Item(id: "carrot", category: .food, names: ["en": "Carrots", "es": "Zanahorias", "de": "Karotten", "fr": "Carottes", "nl": "Wortels"],
             dog: .safe, cat: .safe, note: "Raw or cooked, cut small."),
        Item(id: "apple", category: .food, names: ["en": "Apple (no core or seeds)", "es": "Manzana (sin semillas)", "de": "Apfel (ohne Kerngehäuse)", "fr": "Pomme (sans trognon)", "nl": "Appel (zonder klokhuis)"],
             dog: .safe, cat: .safe, note: "Remove the core and seeds."),
        Item(id: "blueberries", category: .food, names: ["en": "Blueberries", "es": "Arándanos", "de": "Heidelbeeren", "fr": "Myrtilles", "nl": "Blauwe bessen"],
             dog: .safe, cat: .safe, note: "A good low-calorie treat."),
        Item(id: "banana", category: .food, names: ["en": "Banana", "es": "Plátano", "de": "Banane", "fr": "Banane", "nl": "Banaan"],
             dog: .safe, cat: .safe, note: "Sugary, so small pieces only."),
        Item(id: "watermelon", category: .food, names: ["en": "Watermelon", "es": "Sandía", "de": "Wassermelone", "fr": "Pastèque", "nl": "Watermeloen"],
             dog: .safe, cat: .safe, note: "Without seeds and rind."),
        Item(id: "strawberries", category: .food, names: ["en": "Strawberries", "es": "Fresas", "de": "Erdbeeren", "fr": "Fraises", "nl": "Aardbeien"],
             dog: .safe, cat: .safe, note: "In small amounts."),
        Item(id: "cucumber", category: .food, names: ["en": "Cucumber", "es": "Pepino", "de": "Gurke", "fr": "Concombre", "nl": "Komkommer"],
             dog: .safe, cat: .safe, note: "Hydrating and low in calories."),
        Item(id: "pumpkin", category: .food, names: ["en": "Plain pumpkin", "es": "Calabaza natural", "de": "Kürbis (ungewürzt)", "fr": "Potiron nature", "nl": "Pompoen (naturel)"],
             dog: .safe, cat: .safe, note: "Plain, not pie filling. Can help with mild digestive upset."),
        Item(id: "chicken", category: .food, names: ["en": "Plain cooked chicken", "es": "Pollo cocido sin condimentos", "de": "Gekochtes Hähnchen (ungewürzt)", "fr": "Poulet cuit nature", "nl": "Gekookte kip (naturel)"],
             dog: .safe, cat: .safe, note: "Boneless and unseasoned."),
        Item(id: "rice", category: .food, names: ["en": "Plain rice", "es": "Arroz blanco", "de": "Reis", "fr": "Riz nature", "nl": "Rijst"],
             dog: .safe, cat: .safe, note: "Cooked and plain."),
        Item(id: "egg", category: .food, names: ["en": "Cooked egg", "es": "Huevo cocido", "de": "Gekochtes Ei", "fr": "Œuf cuit", "nl": "Gekookt ei"],
             dog: .safe, cat: .safe, note: "Fully cooked, without salt or butter."),
        Item(id: "peanutButter", category: .food, names: ["en": "Peanut butter (xylitol-free)", "es": "Crema de cacahuete (sin xilitol)", "de": "Erdnussbutter (ohne Xylit)", "fr": "Beurre de cacahuète (sans xylitol)", "nl": "Pindakaas (zonder xylitol)"],
             dog: .safe, cat: .caution, note: "Check the label for xylitol / birch sugar first."),
        Item(id: "oats", category: .food, names: ["en": "Plain oatmeal", "es": "Avena", "de": "Haferflocken", "fr": "Flocons d'avoine", "nl": "Havermout"],
             dog: .safe, cat: .safe, note: "Cooked with water, no sugar."),
        Item(id: "popcorn", category: .food, names: ["en": "Plain popcorn", "es": "Palomitas sin sal", "de": "Popcorn (ungesalzen)", "fr": "Pop-corn nature", "nl": "Popcorn (naturel)"],
             dog: .safe, cat: .safe, note: "Air-popped, no butter or salt; remove unpopped kernels."),
    ]

    static func search(_ query: String) -> [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.matches(trimmed) }
    }
}
