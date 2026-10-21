import Foundation

/// Everyday things people buy, each with its aisle and icon. It suggests items
/// as you type, and recognises them inside longer names: "Semi-skimmed milk"
/// is milk, and "Milk chocolate" is chocolate.
enum GroceryCatalogue {
    struct Entry: Sendable {
        let name: String
        let category: ProductCategory
        /// Nil for things no icon shows yet; they show their aisle's icon.
        let icon: GroceryIcon?
        fileprivate let terms: [[String]]
        fileprivate let normalizedName: String

        fileprivate init(_ name: String, _ category: ProductCategory, _ icon: GroceryIcon?, also aliases: [String] = []) {
            self.name = name
            self.category = category
            self.icon = icon
            terms = ([name] + aliases).map(GroceryCatalogue.words)
            normalizedName = ProductName.normalized(name)
        }
    }

    /// The entry a product name refers to. English puts the thing itself last
    /// ("chocolate milk" is milk), so the match ending nearest the end wins,
    /// then the longest ("peanut butter" over "butter").
    static func entry(for name: String) -> Entry? {
        let words = words(name)
        var best: (entry: Entry, end: Int, length: Int)?
        for entry in entries {
            for term in entry.terms where !term.isEmpty && term.count <= words.count {
                for start in 0...(words.count - term.count) where Array(words[start..<(start + term.count)]) == term {
                    let end = start + term.count
                    if best.map({ end > $0.end || (end == $0.end && term.count > $0.length) }) ?? true {
                        best = (entry, end, term.count)
                    }
                }
            }
        }
        return best?.entry
    }

    /// Entries whose names contain `query`, best matches first, for suggestions.
    static func entries(matching query: String, limit: Int) -> [Entry] {
        let key = ProductName.normalized(query)
        guard !key.isEmpty else { return [] }
        let matches = entries.filter { $0.normalizedName.contains(key) }
        let prefixed = matches.filter { $0.normalizedName.hasPrefix(key) }
        let others = matches.filter { !$0.normalizedName.hasPrefix(key) }
        return Array((prefixed + others).prefix(limit))
    }

    static let iconNames: Set<String> = Set(entries.compactMap { $0.icon?.rawValue })

    /// Lowercased words, singular where that's easy to tell, so "Tomatoes"
    /// and "tomato" match.
    fileprivate static func words(_ text: String) -> [String] {
        ProductName.normalized(text)
            .split { !$0.isLetter && !$0.isNumber }
            .map { word in
                let word = String(word)
                guard word.count > 3 else { return word }
                if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
                if word.hasSuffix("oes") || ["ches", "shes", "sses", "xes"].contains(where: word.hasSuffix) {
                    return String(word.dropLast(2))
                }
                if word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us") { return String(word.dropLast()) }
                return word
            }
    }

    private typealias E = Entry

    static let entries: [Entry] = [
        // Fruit & Veg
        E("Apples", .fruitAndVeg, "apple"),
        E("Bananas", .fruitAndVeg, "banana"),
        E("Oranges", .fruitAndVeg, "orange"),
        E("Satsumas", .fruitAndVeg, "orange", also: ["Clementines", "Tangerines", "Easy peelers"]),
        E("Lemons", .fruitAndVeg, "lemon"),
        E("Limes", .fruitAndVeg, "lime"),
        E("Grapefruit", .fruitAndVeg, "lime"),
        E("Grapes", .fruitAndVeg, "grape"),
        E("Strawberries", .fruitAndVeg, "strawberry"),
        E("Raspberries", .fruitAndVeg, "strawberry", also: ["Blackberries"]),
        E("Blueberries", .fruitAndVeg, "grape"),
        E("Cherries", .fruitAndVeg, "cherry"),
        E("Pears", .fruitAndVeg, "pear"),
        E("Peaches", .fruitAndVeg, "peach", also: ["Nectarines", "Plums", "Apricots"]),
        E("Pineapple", .fruitAndVeg, "pineapple"),
        E("Watermelon", .fruitAndVeg, "watermelon"),
        E("Melon", .fruitAndVeg, "melon"),
        E("Mango", .fruitAndVeg, nil),
        E("Kiwi", .fruitAndVeg, nil),
        E("Avocados", .fruitAndVeg, "avocado"),
        E("Tomatoes", .fruitAndVeg, "tomato"),
        E("Cherry tomatoes", .fruitAndVeg, "tomato"),
        E("Potatoes", .fruitAndVeg, nil, also: ["Baking potatoes", "New potatoes"]),
        E("Sweet potatoes", .fruitAndVeg, nil),
        E("Carrots", .fruitAndVeg, "carrot"),
        E("Parsnips", .fruitAndVeg, "carrot"),
        E("Onions", .fruitAndVeg, nil, also: ["Red onions", "Shallots"]),
        E("Spring onions", .fruitAndVeg, "spring-onion"),
        E("Leeks", .fruitAndVeg, "spring-onion"),
        E("Garlic", .fruitAndVeg, "garlic"),
        E("Ginger", .fruitAndVeg, nil),
        E("Broccoli", .fruitAndVeg, "broccoli", also: ["Tenderstem"]),
        E("Cauliflower", .fruitAndVeg, "broccoli"),
        E("Cabbage", .fruitAndVeg, "cabbage"),
        E("Brussels sprouts", .fruitAndVeg, "cabbage", also: ["Sprouts"]),
        E("Lettuce", .fruitAndVeg, "lettuce", also: ["Iceberg", "Little gem", "Romaine"]),
        E("Spinach", .fruitAndVeg, "lettuce", also: ["Kale", "Rocket", "Watercress"]),
        E("Salad", .fruitAndVeg, "salad", also: ["Salad leaves", "Salad bag"]),
        E("Cucumber", .fruitAndVeg, "cucumber"),
        E("Courgettes", .fruitAndVeg, "cucumber"),
        E("Peppers", .fruitAndVeg, "pepper", also: ["Bell peppers"]),
        E("Chillies", .fruitAndVeg, "chilli", also: ["Chilli"]),
        E("Mushrooms", .fruitAndVeg, "mushroom"),
        E("Sweetcorn", .fruitAndVeg, "corn", also: ["Corn on the cob", "Corn"]),
        E("Green beans", .fruitAndVeg, "peas", also: ["Mangetout", "Sugar snap peas", "Runner beans"]),
        E("Aubergine", .fruitAndVeg, "aubergine"),
        E("Radishes", .fruitAndVeg, "radish"),
        E("Beetroot", .fruitAndVeg, "radish"),
        E("Celery", .fruitAndVeg, nil),
        E("Pumpkin", .fruitAndVeg, "pumpkin"),
        E("Butternut squash", .fruitAndVeg, "pumpkin"),
        E("Herbs", .fruitAndVeg, "herbs", also: ["Basil", "Coriander", "Parsley", "Mint", "Thyme", "Rosemary", "Chives"]),
        E("Stir-fry vegetables", .fruitAndVeg, "vegetables", also: ["Vegetables", "Veg", "Veg box", "Stir fry"]),

        // Meat & Fish
        E("Chicken", .meatAndFish, "drumstick", also: ["Chicken breasts", "Chicken thighs", "Chicken wings", "Whole chicken", "Drumsticks"]),
        E("Turkey", .meatAndFish, "turkey"),
        E("Beef", .meatAndFish, "beef", also: ["Brisket", "Roasting joint", "Joint"]),
        E("Steak", .meatAndFish, "steak", also: ["Sirloin", "Ribeye"]),
        E("Mince", .meatAndFish, "meat", also: ["Beef mince", "Pork mince", "Lamb mince", "Turkey mince"]),
        E("Pork", .meatAndFish, "meat", also: ["Pork chops", "Pork belly", "Gammon"]),
        E("Lamb", .meatAndFish, "meat", also: ["Lamb chops", "Leg of lamb"]),
        E("Meatballs", .meatAndFish, "meat"),
        E("Bacon", .meatAndFish, "bacon", also: ["Streaky bacon", "Back bacon", "Pancetta", "Lardons"]),
        E("Sausages", .meatAndFish, "sausage", also: ["Chipolatas", "Hot dogs", "Chorizo"]),
        E("Ham", .meatAndFish, "ham", also: ["Salami", "Prosciutto"]),
        E("Burgers", .meatAndFish, "burger", also: ["Beef burgers"]),
        E("Fish", .meatAndFish, "fish", also: ["Fish fillets", "Cod", "Haddock", "Salmon", "Smoked salmon", "Tuna steaks", "Mackerel", "Sea bass"]),
        E("Prawns", .meatAndFish, "prawn", also: ["King prawns", "Shrimp"]),
        E("Crab", .meatAndFish, "crab"),
        E("Squid", .meatAndFish, "squid", also: ["Calamari", "Octopus"]),
        E("Mussels", .meatAndFish, nil),

        // Dairy, Eggs & Chilled
        E("Milk", .dairyAndEggs, "milk", also: ["Semi-skimmed milk", "Whole milk", "Skimmed milk"]),
        E("Oat milk", .dairyAndEggs, "oat-milk"),
        E("Almond milk", .dairyAndEggs, "milk-carton", also: ["Soya milk"]),
        E("Cream", .dairyAndEggs, "milk-carton", also: ["Double cream", "Single cream", "Whipping cream"]),
        E("Custard", .dairyAndEggs, "milk-carton"),
        E("Eggs", .dairyAndEggs, "eggs", also: ["Free-range eggs"]),
        E("Cheese", .dairyAndEggs, "cheese", also: ["Cheddar", "Mozzarella", "Parmesan", "Halloumi", "Feta", "Brie", "Cream cheese", "Grated cheese"]),
        E("Yoghurt", .dairyAndEggs, "yoghurt", also: ["Yogurt", "Greek yoghurt", "Fromage frais"]),
        E("Crème fraîche", .dairyAndEggs, "yoghurt", also: ["Soured cream", "Sour cream"]),
        E("Butter", .dairyAndEggs, nil, also: ["Margarine", "Spread"]),
        E("Hummus", .dairyAndEggs, nil, also: ["Dips"]),
        E("Tofu", .dairyAndEggs, nil),

        // Bakery
        E("Bread", .bakery, "bread", also: ["Sliced bread", "Wholemeal bread", "Sourdough", "Loaf", "Rolls", "Pitta bread", "Naan bread", "Brioche"]),
        E("Baguette", .bakery, "baguette", also: ["French stick"]),
        E("Croissants", .bakery, "croissant", also: ["Pain au chocolat", "Pastries"]),
        E("Doughnuts", .bakery, "doughnut", also: ["Donuts"]),
        E("Cake", .bakery, "cake", also: ["Sponge cake", "Victoria sponge"]),
        E("Birthday cake", .bakery, "birthday-cake"),
        E("Cupcakes", .bakery, "cupcake", also: ["Muffins", "Fairy cakes"]),
        E("Pies", .bakery, "pie", also: ["Pork pie", "Mince pies", "Quiche", "Tart", "Lemon tart", "Bakewell tart"]),
        E("Apple pie", .bakery, "apple-pie"),
        E("Cheesecake", .bakery, "cheesecake"),
        E("Sandwiches", .bakery, "sandwich"),
        E("Wraps", .bakery, "wrap", also: ["Tortillas", "Taco shells"]),
        E("Bagels", .bakery, nil),
        E("Crumpets", .bakery, nil, also: ["Scones", "English muffins"]),

        // Frozen
        E("Frozen vegetables", .frozen, "frozen", also: ["Frozen veg", "Frozen berries", "Frozen fruit"]),
        E("Frozen peas", .frozen, "peas"),
        E("Oven chips", .frozen, "chips", also: ["Chips", "Fries"]),
        E("Ice cream", .frozen, "ice-cream"),
        E("Ice lollies", .frozen, "ice-lolly", also: ["Lollies"]),
        E("Ice", .frozen, "ice", also: ["Ice cubes"]),
        E("Ready meals", .frozen, "ready-meal", also: ["Ready meal", "Microwave meals"]),
        E("Pizza", .frozen, "pizza", also: ["Frozen pizza"]),
        E("Fish fingers", .frozen, "fish"),

        // Food Cupboard
        E("Pasta", .foodCupboard, "pasta", also: ["Spaghetti", "Penne", "Fusilli", "Lasagne sheets", "Macaroni", "Tagliatelle"]),
        E("Noodles", .foodCupboard, "noodles", also: ["Egg noodles", "Rice noodles", "Instant noodles"]),
        E("Rice", .foodCupboard, "rice", also: ["Basmati rice", "Risotto rice", "Microwave rice"]),
        E("Flour", .foodCupboard, "wheat", also: ["Plain flour", "Self-raising flour", "Bread flour", "Couscous"]),
        E("Oats", .foodCupboard, "wheat", also: ["Porridge oats", "Porridge"]),
        E("Sugar", .foodCupboard, "sugar", also: ["Caster sugar", "Icing sugar", "Brown sugar"]),
        E("Salt", .foodCupboard, "salt", also: ["Sea salt"]),
        E("Black pepper", .foodCupboard, "salt", also: ["Spices", "Paprika", "Cumin", "Cinnamon", "Curry powder", "Chilli flakes", "Mixed herbs"]),
        E("Olive oil", .foodCupboard, "bottle", also: ["Oil", "Vegetable oil", "Sunflower oil", "Cooking oil"]),
        E("Vinegar", .foodCupboard, "bottle", also: ["Balsamic vinegar"]),
        E("Soy sauce", .foodCupboard, "bottle", also: ["Worcestershire sauce", "Hot sauce", "Sweet chilli sauce"]),
        E("Ketchup", .foodCupboard, nil, also: ["Tomato ketchup", "Brown sauce", "Barbecue sauce", "Sauces"]),
        E("Mayonnaise", .foodCupboard, "jar", also: ["Mayo", "Mustard", "Salad cream", "Pesto", "Chutney", "Pickles"]),
        E("Pasta sauce", .foodCupboard, "jar", also: ["Curry sauce", "Curry paste", "Passata"]),
        E("Tinned tomatoes", .foodCupboard, "tin", also: ["Chopped tomatoes", "Tins", "Tinned food"]),
        E("Baked beans", .foodCupboard, "tin"),
        E("Chickpeas", .foodCupboard, "tin", also: ["Tinned tuna", "Tuna", "Sweetcorn tin", "Coconut cream"]),
        E("Coconut milk", .foodCupboard, "coconut-milk"),
        E("Kidney beans", .foodCupboard, "bean", also: ["Beans", "Lentils", "Butter beans", "Black beans"]),
        E("Tinned fruit", .foodCupboard, "tinned-fruit", also: ["Peaches in juice", "Fruit cocktail"]),
        E("Soup", .foodCupboard, "soup"),
        E("Stock cubes", .foodCupboard, nil, also: ["Stock", "Gravy", "Gravy granules", "Stock pots"]),
        E("Cereal", .foodCupboard, "cereal", also: ["Cornflakes", "Granola", "Muesli", "Weetabix", "Breakfast cereal"]),
        E("Honey", .foodCupboard, "honey", also: ["Golden syrup", "Maple syrup"]),
        E("Jam", .foodCupboard, "jar", also: ["Marmalade", "Lemon curd"]),
        E("Peanut butter", .foodCupboard, "jar", also: ["Chocolate spread", "Nutella", "Marmite"]),
        E("Nuts", .foodCupboard, "nut", also: ["Peanuts", "Almonds", "Cashews", "Walnuts", "Mixed nuts"]),
        E("Dried fruit", .foodCupboard, "grape", also: ["Raisins", "Sultanas"]),
        E("Olives", .foodCupboard, nil),
        E("Baking powder", .foodCupboard, "whisk", also: ["Bicarbonate of soda", "Yeast", "Vanilla extract", "Baking"]),
        E("Tea", .foodCupboard, "tea", also: ["Tea bags", "Green tea", "Herbal tea"]),
        E("Coffee", .foodCupboard, "coffee", also: ["Instant coffee", "Ground coffee", "Coffee pods"]),
        E("Coffee beans", .foodCupboard, "coffee-beans"),
        E("Hot chocolate", .foodCupboard, "coffee"),
        E("Popcorn", .foodCupboard, "popcorn"),

        // Treats & Snacks
        E("Crisps", .snacks, nil, also: ["Tortilla chips", "Multipack crisps"]),
        E("Chocolate", .snacks, "chocolate", also: ["Chocolate bar", "Dark chocolate", "Milk chocolate"]),
        E("Sweets", .snacks, "sweets", also: ["Jelly sweets", "Chewing gum"]),
        E("Lollipops", .snacks, "lollipop"),
        E("Candy canes", .snacks, "candy-cane"),
        E("Biscuits", .snacks, "biscuit", also: ["Digestives", "Crackers", "Rich tea", "Oatcakes", "Rice cakes"]),
        E("Cookies", .snacks, "cookie"),
        E("Cereal bars", .snacks, nil, also: ["Flapjacks", "Protein bars"]),

        // Drinks
        E("Water", .drinks, "water", also: ["Bottled water", "Sparkling water", "Still water"]),
        E("Orange juice", .drinks, "juice", also: ["Juice", "Apple juice", "Squash", "Cordial", "Smoothies"]),
        E("Fizzy drinks", .drinks, "fizzy-drink", also: ["Cola", "Coke", "Lemonade", "Tonic water", "Soft drinks", "Energy drinks"]),
        E("Milkshake", .drinks, "milkshake"),
        E("Bubble tea", .drinks, "bubble-tea", also: ["Iced coffee"]),
        E("Beer", .drinks, "beer", also: ["Lager", "Ale", "Cider", "Stout"]),
        E("Wine", .drinks, "wine", also: ["Red wine", "White wine", "Rosé"]),
        E("Champagne", .drinks, "champagne", also: ["Prosecco", "Cava", "Sparkling wine"]),
        E("Spirits", .drinks, "cocktail", also: ["Gin", "Vodka", "Whisky", "Rum", "Tequila", "Cocktails", "Mixers"]),

        // Baby & Toddler
        E("Nappies", .baby, "nappy", also: ["Pull-ups"]),
        E("Baby wipes", .baby, nil, also: ["Wipes"]),
        E("Baby bottles", .baby, "baby-bottle", also: ["Baby formula", "Formula", "Baby milk"]),
        E("Dummies", .baby, "dummy"),
        E("Baby food", .baby, "baby-food", also: ["Baby pouches", "Baby snacks"]),
        E("Bibs", .baby, "bib"),
        E("Baby clothes", .baby, "baby-clothes", also: ["Babygrows", "Vests"]),
        E("Nappy cream", .baby, "lotion", also: ["Baby lotion"]),
        E("Pushchair", .baby, "pram", also: ["Pram", "Buggy"]),
        E("Cot sheets", .baby, "cot", also: ["Cot"]),

        // Health & Beauty
        E("Toothbrush", .healthAndBeauty, "toothbrush", also: ["Toothbrush heads"]),
        E("Toothpaste", .healthAndBeauty, "toothbrush"),
        E("Mouthwash", .healthAndBeauty, "tooth", also: ["Dental floss", "Floss"]),
        E("Shampoo", .healthAndBeauty, "shampoo", also: ["Conditioner", "Shower gel", "Body wash", "Bubble bath"]),
        E("Soap", .healthAndBeauty, "soap", also: ["Bar soap"]),
        E("Hand wash", .healthAndBeauty, "hand-wash", also: ["Hand soap", "Hand sanitiser"]),
        E("Deodorant", .healthAndBeauty, nil, also: ["Antiperspirant"]),
        E("Razors", .healthAndBeauty, "razor", also: ["Razor blades", "Shaving foam", "Shaving gel"]),
        E("Plasters", .healthAndBeauty, "plaster", also: ["Bandages", "First aid"]),
        E("Paracetamol", .healthAndBeauty, "tablets", also: ["Ibuprofen", "Painkillers", "Aspirin", "Antihistamines", "Hay fever tablets"]),
        E("Medicine", .healthAndBeauty, "medicine", also: ["Cough medicine", "Cough syrup", "Calpol"]),
        E("Vitamins", .healthAndBeauty, "pill", also: ["Vitamin D", "Multivitamins", "Supplements"]),
        E("Moisturiser", .healthAndBeauty, "lotion", also: ["Hand cream", "Body lotion", "Sun cream", "Suncream", "Sunscreen", "After sun"]),
        E("Lipstick", .healthAndBeauty, "lipstick", also: ["Make-up", "Makeup", "Lip balm", "Mascara", "Foundation"]),
        E("Perfume", .healthAndBeauty, "perfume", also: ["Aftershave"]),
        E("Hairbrush", .healthAndBeauty, "comb", also: ["Comb", "Hair ties", "Hair gel", "Hairspray"]),
        E("Tissues", .healthAndBeauty, "tissues"),
        E("Thermometer", .healthAndBeauty, "thermometer"),
        E("Glasses", .healthAndBeauty, "glasses", also: ["Reading glasses", "Contact lens solution"]),
        E("Face masks", .healthAndBeauty, "face-mask"),
        E("Cotton wool", .healthAndBeauty, nil, also: ["Cotton buds", "Cotton pads"]),
        E("Sanitary towels", .healthAndBeauty, nil, also: ["Sanitary pads", "Tampons", "Panty liners"]),

        // Household
        E("Toilet roll", .household, "toilet-roll", also: ["Toilet paper", "Loo roll"]),
        E("Kitchen roll", .household, "toilet-roll", also: ["Paper towels"]),
        E("Washing-up liquid", .household, "detergent", also: ["Washing up liquid", "Fabric conditioner", "Fabric softener"]),
        E("Dishwasher tablets", .household, "detergent", also: ["Rinse aid", "Dishwasher salt"]),
        E("Laundry detergent", .household, "washing-machine", also: ["Washing powder", "Washing liquid", "Laundry pods", "Washing tablets", "Stain remover"]),
        E("Bin bags", .household, "bin", also: ["Bin liners", "Food waste bags"]),
        E("Cleaning spray", .household, "spray", also: ["Multi-surface cleaner", "Bathroom cleaner", "Kitchen cleaner", "Bleach", "Toilet cleaner", "Glass cleaner", "Air freshener", "Polish"]),
        E("Cleaning cloths", .household, "cleaning", also: ["Cloths", "Microfibre cloths", "Scourers"]),
        E("Sponges", .household, nil),
        E("Broom", .household, "broom", also: ["Dustpan and brush"]),
        E("Mop", .household, "mop"),
        E("Bucket", .household, "bucket"),
        E("Light bulbs", .household, "light-bulb", also: ["Bulbs"]),
        E("Batteries", .household, "battery", also: ["AA batteries", "AAA batteries"]),
        E("Candles", .household, "candle", also: ["Tealights", "Birthday candles"]),
        E("Matches", .household, "matches", also: ["Lighter"]),
        E("Rubber gloves", .household, "gloves", also: ["Washing-up gloves"]),
        E("Paper bags", .household, "paper-bag", also: ["Freezer bags", "Sandwich bags", "Bags for life"]),
        E("Foil", .household, nil, also: ["Tin foil", "Kitchen foil", "Cling film", "Baking paper", "Greaseproof paper"]),

        // Pets
        E("Dog food", .pets, "dog-bowl", also: ["Puppy food"]),
        E("Dog treats", .pets, "bone", also: ["Dog chews", "Pet treats"]),
        E("Cat food", .pets, "cat", also: ["Cat treats", "Kitten food"]),
        E("Cat litter", .pets, nil),
        E("Bird seed", .pets, "bird", also: ["Bird food", "Fat balls"]),
        E("Fish food", .pets, "fish-food", also: ["Fish flakes"]),
        E("Rabbit food", .pets, "rabbit", also: ["Hamster food", "Guinea pig food", "Hay", "Sawdust"]),
        E("Pet toys", .pets, "tennis-ball", also: ["Dog toys", "Cat toys"]),
        E("Poo bags", .pets, "paw", also: ["Dog poo bags", "Flea treatment", "Worming tablets", "Pet supplies"]),

        // Home & Garden
        E("Plants", .homeAndGarden, "plant", also: ["Houseplant", "Herb plant"]),
        E("Plant pots", .homeAndGarden, "plant-pot", also: ["Planter"]),
        E("Flowers", .homeAndGarden, "flower", also: ["Bouquet", "Tulips", "Roses"]),
        E("Seeds", .homeAndGarden, "seedling", also: ["Bulbs for planting", "Seedlings"]),
        E("Compost", .homeAndGarden, "shovel", also: ["Garden tools", "Trowel", "Spade", "Soil", "Plant food"]),
        E("Watering can", .homeAndGarden, "watering-can", also: ["Hose"]),
        E("Paint", .homeAndGarden, "paint-roller", also: ["Paint roller", "Emulsion"]),
        E("Paintbrushes", .homeAndGarden, "paintbrush", also: ["Paintbrush"]),
        E("Tools", .homeAndGarden, "tools", also: ["Screwdriver", "Screws", "Toolbox"]),
        E("Hammer", .homeAndGarden, "hammer", also: ["Nails", "Picture hooks"]),
        E("Spanner", .homeAndGarden, "spanner", also: ["Wrench"]),
        E("Frying pan", .homeAndGarden, "frying-pan", also: ["Wok"]),
        E("Saucepan", .homeAndGarden, "saucepan", also: ["Pans", "Pots"]),
        E("Casserole dish", .homeAndGarden, "cooking-pot", also: ["Slow cooker"]),
        E("Cutlery", .homeAndGarden, "cutlery", also: ["Forks", "Spoons", "Teaspoons"]),
        E("Knives", .homeAndGarden, "knife", also: ["Knife", "Kitchen knife"]),
        E("Plates", .homeAndGarden, "plate", also: ["Paper plates"]),
        E("Bowls", .homeAndGarden, "cereal"),
        E("Mugs", .homeAndGarden, "mug", also: ["Mug", "Cups"]),
        E("Wine glasses", .homeAndGarden, "champagne", also: ["Glassware", "Tumblers"]),
        E("Kettle", .homeAndGarden, "kettle"),
        E("Rolling pin", .homeAndGarden, "rolling-pin"),
        E("Whisk", .homeAndGarden, "whisk", also: ["Baking tray", "Cake tin"]),
        E("Towels", .homeAndGarden, "towel", also: ["Tea towels", "Bath towels", "Hand towels"]),
        E("Bedding", .homeAndGarden, "bed", also: ["Duvet", "Duvet cover", "Bed sheets", "Sheets"]),
        E("Pillows", .homeAndGarden, "pillow", also: ["Pillowcases", "Cushions"]),
        E("Storage boxes", .homeAndGarden, "storage", also: ["Storage", "Boxes"]),
        E("Barbecue", .homeAndGarden, "bbq", also: ["BBQ", "Charcoal", "Disposable barbecue"]),

        // Toys & Games
        E("Toys", .toysAndGames, "toy", also: ["Toy", "Toy car", "Train set"]),
        E("Teddy bear", .toysAndGames, "teddy-bear", also: ["Soft toy", "Cuddly toy"]),
        E("Building bricks", .toysAndGames, "bricks", also: ["Lego", "Duplo"]),
        E("Board games", .toysAndGames, "dice", also: ["Board game", "Dice"]),
        E("Jigsaw", .toysAndGames, "jigsaw", also: ["Jigsaw puzzle", "Puzzle"]),
        E("Puzzle cube", .toysAndGames, "puzzle-cube", also: ["Rubik's cube"]),
        E("Balloons", .toysAndGames, "balloons"),
        E("Presents", .toysAndGames, "gift", also: ["Present", "Gift", "Gifts", "Wrapping paper", "Gift bags"]),
        E("Playing cards", .toysAndGames, "playing-cards", also: ["Card game", "Cards"]),
        E("Party supplies", .toysAndGames, "party", also: ["Party poppers", "Decorations", "Party bags"]),
        E("Kite", .toysAndGames, "kite"),
        E("Video games", .toysAndGames, "gamepad", also: ["Video game", "Controller"]),
        E("Football", .toysAndGames, "football"),
        E("Basketball", .toysAndGames, "basketball"),
        E("Tennis balls", .toysAndGames, "tennis-ball"),
        E("Books", .toysAndGames, "book", also: ["Book", "Magazine", "Comic"]),
        E("Art supplies", .toysAndGames, "art", also: ["Crayons", "Colouring pencils", "Felt tips", "Colouring book", "Paints"]),

        // Electronics
        E("Phone charger", .electronics, "charger", also: ["Charger", "Plug adapter", "Travel adapter"]),
        E("Cables", .electronics, "cable", also: ["USB cable", "Charging cable", "HDMI cable"]),
        E("Headphones", .electronics, "headphones", also: ["Earphones", "Earbuds"]),
        E("Phone", .electronics, "phone", also: ["Phone case", "Screen protector", "SIM card"]),
        E("Speaker", .electronics, "speaker", also: ["Bluetooth speaker"]),
        E("Memory card", .electronics, "memory-card", also: ["SD card", "USB stick"]),
        E("Printer ink", .electronics, "printer", also: ["Ink cartridges", "Printer paper"]),
        E("TV", .electronics, "tv", also: ["Television"]),
        E("Laptop", .electronics, "laptop"),
        E("Camera", .electronics, "camera"),
        E("Smartwatch", .electronics, "smartwatch", also: ["Watch strap"]),
        E("Extension lead", .electronics, "socket", also: ["Extension cable"]),

        // Clothing
        E("T-shirts", .clothing, "tshirt", also: ["T-shirt", "Top", "Tops", "Vest top"]),
        E("Shirts", .clothing, "shirt", also: ["Shirt", "Blouse"]),
        E("Jumpers", .clothing, "jumper", also: ["Jumper", "Sweatshirt", "Hoodie"]),
        E("Cardigan", .clothing, "cardigan"),
        E("Socks", .clothing, "socks", also: ["Tights"]),
        E("Underwear", .clothing, nil, also: ["Pants", "Boxers", "Bras", "Knickers"]),
        E("Pyjamas", .clothing, nil, also: ["Dressing gown", "Slippers"]),
        E("Trousers", .clothing, "trousers", also: ["Jeans", "Joggers", "Leggings"]),
        E("Shorts", .clothing, "shorts"),
        E("Dress", .clothing, "dress", also: ["Skirt"]),
        E("Trainers", .clothing, "trainers", also: ["Shoes", "School shoes", "Plimsolls"]),
        E("Boots", .clothing, "boots", also: ["Wellies", "Wellington boots"]),
        E("Coat", .clothing, "coat", also: ["Jacket", "Raincoat"]),
        E("Hat", .clothing, "hat", also: ["Sun hat", "Cap"]),
        E("Woolly hat", .clothing, "beanie", also: ["Beanie"]),
        E("Gloves", .clothing, "gloves", also: ["Mittens"]),
        E("Scarf", .clothing, "scarf"),
        E("Handbag", .clothing, "handbag", also: ["Purse"]),
        E("Backpack", .clothing, "backpack", also: ["Rucksack", "School bag"]),
        E("Umbrella", .clothing, "umbrella"),
        E("Coat hangers", .clothing, "hanger", also: ["Hangers"]),
    ]
}
