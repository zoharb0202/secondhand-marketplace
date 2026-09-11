import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final List<SubCategory> subCategories;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.subCategories,
  });
}

class SubCategory {
  final String id;
  final String name;
  final List<CategoryField> specificFields;

  const SubCategory({
    required this.id,
    required this.name,
    this.specificFields = const [],
  });
}

enum FieldType { text, number, dropdown, multiSelect, boolean, year }

class CategoryField {
  final String id;
  final String label;
  final FieldType type;
  final bool required;
  final List<String>? options;
  final String? unit;

  const CategoryField({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.options,
    this.unit,
  });
}

class Categories {
  static const fashion = Category(
    id: 'fashion',
    name: 'אופנה ואביזרים',
    icon: Icons.checkroom,
    subCategories: [
      SubCategory(
        id: 'men_clothing',
        name: 'ביגוד גברים',
        specificFields: [
          CategoryField(
            id: 'size',
            label: 'מידה',
            type: FieldType.dropdown,
            required: true,
            options: ['S', 'M', 'L', 'XL', 'XXL', '3XL'],
          ),
          CategoryField(id: 'brand', label: 'מותג', type: FieldType.text),
          CategoryField(id: 'color', label: 'צבע', type: FieldType.text),
        ],
      ),
      SubCategory(
        id: 'women_clothing',
        name: 'ביגוד נשים',
        specificFields: [
          CategoryField(
            id: 'size',
            label: 'מידה',
            type: FieldType.dropdown,
            required: true,
            options: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
          ),
          CategoryField(id: 'brand', label: 'מותג', type: FieldType.text),
          CategoryField(id: 'color', label: 'צבע', type: FieldType.text),
        ],
      ),
      SubCategory(
        id: 'shoes',
        name: 'נעליים',
        specificFields: [
          CategoryField(
            id: 'shoe_size',
            label: 'מידת נעליים',
            type: FieldType.dropdown,
            required: true,
            options: [
              '30',
              '31',
              '32',
              '33',
              '34',
              '35',
              '36',
              '37',
              '38',
              '39',
              '40',
              '41',
              '42',
              '43',
              '44',
              '45',
              '46',
              '47',
              '48',
              '49',
              '50',
            ],
          ),
          CategoryField(id: 'brand', label: 'מותג', type: FieldType.text),
        ],
      ),
      SubCategory(id: 'bags', name: 'תיקים'),
      SubCategory(id: 'accessories', name: 'אביזרים'),
      SubCategory(id: 'jewelry', name: 'תכשיטים'),
    ],
  );

  static const electronics = Category(
    id: 'electronics',
    name: 'אלקטרוניקה',
    icon: Icons.devices,
    subCategories: [
      SubCategory(
        id: 'smartphones',
        name: 'סמארטפונים',
        specificFields: [
          CategoryField(
            id: 'brand',
            label: 'יצרן',
            type: FieldType.dropdown,
            required: true,
            options: ['Apple', 'Samsung', 'Xiaomi', 'OnePlus', 'Google', 'אחר'],
          ),
          CategoryField(
            id: 'model',
            label: 'דגם',
            type: FieldType.text,
            required: true,
          ),
          CategoryField(
            id: 'storage',
            label: 'נפח אחסון',
            type: FieldType.dropdown,
            options: ['64GB', '128GB', '256GB', '512GB', '1TB'],
          ),
          CategoryField(id: 'color', label: 'צבע', type: FieldType.text),
          CategoryField(
            id: 'warranty',
            label: 'אחריות',
            type: FieldType.boolean,
          ),
        ],
      ),
      SubCategory(
        id: 'laptops',
        name: 'מחשבים ניידים',
        specificFields: [
          CategoryField(
            id: 'brand',
            label: 'יצרן',
            type: FieldType.dropdown,
            required: true,
            options: ['Apple', 'Dell', 'HP', 'Lenovo', 'Asus', 'MSI', 'אחר'],
          ),
          CategoryField(id: 'processor', label: 'מעבד', type: FieldType.text),
          CategoryField(
            id: 'ram',
            label: 'זיכרון RAM',
            type: FieldType.dropdown,
            options: ['4GB', '8GB', '16GB', '32GB', '64GB'],
          ),
          CategoryField(
            id: 'storage',
            label: 'אחסון',
            type: FieldType.dropdown,
            options: ['256GB', '512GB', '1TB', '2TB'],
          ),
          CategoryField(
            id: 'screen_size',
            label: 'גודל מסך',
            type: FieldType.dropdown,
            options: ['13"', '14"', '15"', '16"', '17"'],
          ),
        ],
      ),
      SubCategory(
        id: 'tablets',
        name: 'טאבלטים',
        specificFields: [
          CategoryField(
            id: 'brand',
            label: 'יצרן',
            type: FieldType.dropdown,
            options: ['Apple', 'Samsung', 'Lenovo', 'אחר'],
          ),
          CategoryField(
            id: 'storage',
            label: 'נפח אחסון',
            type: FieldType.dropdown,
            options: ['32GB', '64GB', '128GB', '256GB', '512GB'],
          ),
        ],
      ),
      SubCategory(id: 'headphones', name: 'אוזניות'),
      SubCategory(id: 'cameras', name: 'מצלמות'),
      SubCategory(id: 'gaming', name: 'גיימינג'),
      SubCategory(id: 'tv_audio', name: 'טלויזיות ואודיו'),
      SubCategory(id: 'accessories', name: 'אביזרים'),
    ],
  );

  static const vehicles = Category(
    id: 'vehicles',
    name: 'רכב',
    icon: Icons.directions_car,
    subCategories: [
      SubCategory(
        id: 'cars',
        name: 'מכוניות',
        specificFields: [
          CategoryField(
            id: 'make',
            label: 'יצרן',
            type: FieldType.dropdown,
            required: true,
            options: [
              'טויוטה',
              'מאזדה',
              'יונדאי',
              'קיה',
              'פולקסווגן',
              'סקודה',
              'ניסאן',
              'הונדה',
              'מרצדס',
              'BMW',
              'אאודי',
              'אחר',
            ],
          ),
          CategoryField(
            id: 'model',
            label: 'דגם',
            type: FieldType.text,
            required: true,
          ),
          CategoryField(
            id: 'year',
            label: 'שנת ייצור',
            type: FieldType.year,
            required: true,
          ),
          CategoryField(
            id: 'km',
            label: 'קילומטראז׳',
            type: FieldType.number,
            required: true,
            unit: 'ק״מ',
          ),
          CategoryField(
            id: 'hand',
            label: 'יד',
            type: FieldType.dropdown,
            required: true,
            options: ['יד ראשונה', 'יד שנייה', 'יד שלישית', 'יד רביעית+'],
          ),
          CategoryField(
            id: 'engine_size',
            label: 'נפח מנוע',
            type: FieldType.number,
            unit: 'סמ״ק',
          ),
          CategoryField(
            id: 'transmission',
            label: 'תיבת הילוכים',
            type: FieldType.dropdown,
            options: ['אוטומט', 'ידני', 'רובוטי'],
          ),
        ],
      ),
      SubCategory(
        id: 'motorcycles',
        name: 'אופנועים',
        specificFields: [
          CategoryField(
            id: 'make',
            label: 'יצרן',
            type: FieldType.text,
            required: true,
          ),
          CategoryField(
            id: 'model',
            label: 'דגם',
            type: FieldType.text,
            required: true,
          ),
          CategoryField(
            id: 'year',
            label: 'שנת ייצור',
            type: FieldType.year,
            required: true,
          ),
          CategoryField(
            id: 'km',
            label: 'קילומטראז׳',
            type: FieldType.number,
            unit: 'ק״מ',
          ),
          CategoryField(
            id: 'cc',
            label: 'נפח מנוע',
            type: FieldType.number,
            unit: 'סמ״ק',
          ),
        ],
      ),
      SubCategory(id: 'bicycles', name: 'אופניים'),
      SubCategory(id: 'scooters', name: 'קורקינטים'),
      SubCategory(id: 'parts', name: 'חלקי חילוף'),
      SubCategory(id: 'accessories', name: 'אביזרים לרכב'),
    ],
  );

  static const realEstate = Category(
    id: 'real_estate',
    name: 'נדל״ן',
    icon: Icons.home,
    subCategories: [
      SubCategory(
        id: 'apartments_for_sale',
        name: 'דירות למכירה',
        specificFields: [
          CategoryField(
            id: 'rooms',
            label: 'מספר חדרים',
            type: FieldType.dropdown,
            required: true,
            options: [
              '1',
              '1.5',
              '2',
              '2.5',
              '3',
              '3.5',
              '4',
              '4.5',
              '5',
              '5.5',
              '6+',
            ],
          ),
          CategoryField(
            id: 'floor',
            label: 'קומה',
            type: FieldType.number,
            required: true,
          ),
          CategoryField(
            id: 'size',
            label: 'גודל',
            type: FieldType.number,
            required: true,
            unit: 'מ״ר',
          ),
          CategoryField(
            id: 'elevator',
            label: 'מעלית',
            type: FieldType.boolean,
          ),
          CategoryField(id: 'parking', label: 'חניה', type: FieldType.boolean),
          CategoryField(id: 'balcony', label: 'מרפסת', type: FieldType.boolean),
        ],
      ),
      SubCategory(
        id: 'apartments_for_rent',
        name: 'דירות להשכרה',
        specificFields: [
          CategoryField(
            id: 'rooms',
            label: 'מספר חדרים',
            type: FieldType.dropdown,
            required: true,
            options: [
              '1',
              '1.5',
              '2',
              '2.5',
              '3',
              '3.5',
              '4',
              '4.5',
              '5',
              '5.5',
              '6+',
            ],
          ),
          CategoryField(id: 'floor', label: 'קומה', type: FieldType.number),
          CategoryField(
            id: 'size',
            label: 'גודל',
            type: FieldType.number,
            unit: 'מ״ר',
          ),
          CategoryField(
            id: 'entry_date',
            label: 'תאריך כניסה',
            type: FieldType.text,
          ),
        ],
      ),
      SubCategory(id: 'commercial', name: 'נכסים מסחריים'),
      SubCategory(id: 'roommates', name: 'שותפים'),
    ],
  );

  static const furniture = Category(
    id: 'furniture',
    name: 'ריהוט',
    icon: Icons.weekend,
    subCategories: [
      SubCategory(
        id: 'living_room',
        name: 'סלון',
        specificFields: [
          CategoryField(
            id: 'item_type',
            label: 'סוג פריט',
            type: FieldType.dropdown,
            options: ['ספה', 'כורסה', 'שולחן', 'מזנון', 'ספריה', 'אחר'],
          ),
          CategoryField(id: 'material', label: 'חומר', type: FieldType.text),
          CategoryField(id: 'color', label: 'צבע', type: FieldType.text),
        ],
      ),
      SubCategory(id: 'bedroom', name: 'חדר שינה'),
      SubCategory(id: 'dining', name: 'פינת אוכל'),
      SubCategory(id: 'office', name: 'משרד'),
      SubCategory(id: 'kids_room', name: 'חדר ילדים'),
      SubCategory(id: 'outdoor', name: 'ריהוט חוץ'),
    ],
  );

  static const homeGarden = Category(
    id: 'home_garden',
    name: 'בית וגינה',
    icon: Icons.home_outlined,
    subCategories: [
      SubCategory(id: 'decor', name: 'עיצוב ותאורה'),
      SubCategory(id: 'kitchen', name: 'כלי מטבח'),
      SubCategory(id: 'appliances', name: 'מוצרי חשמל'),
      SubCategory(id: 'tools', name: 'כלי עבודה'),
      SubCategory(id: 'garden', name: 'גינה וצמחים'),
      SubCategory(id: 'storage', name: 'אחסון וארגון'),
    ],
  );

  static const fashionBeauty = Category(
    id: 'fashion_beauty',
    name: 'יופי ובריאות',
    icon: Icons.spa,
    subCategories: [
      SubCategory(id: 'makeup', name: 'איפור'),
      SubCategory(id: 'skincare', name: 'טיפוח עור'),
      SubCategory(id: 'haircare', name: 'טיפוח שיער'),
      SubCategory(id: 'perfumes', name: 'בשמים'),
      SubCategory(id: 'health', name: 'בריאות ותוספי תזונה'),
    ],
  );

  static const sports = Category(
    id: 'sports',
    name: 'ספורט וכושר',
    icon: Icons.fitness_center,
    subCategories: [
      SubCategory(
        id: 'gym_equipment',
        name: 'ציוד כושר',
        specificFields: [
          CategoryField(
            id: 'equipment_type',
            label: 'סוג ציוד',
            type: FieldType.dropdown,
            options: [
              'משקולות',
              'הליכון',
              'אופני כושר',
              'מכונה רב תכליתית',
              'אחר',
            ],
          ),
        ],
      ),
      SubCategory(id: 'bikes', name: 'אופניים'),
      SubCategory(id: 'outdoor', name: 'ציוד חוץ'),
      SubCategory(id: 'water_sports', name: 'ספורט ימי'),
      SubCategory(id: 'winter_sports', name: 'ספורט חורף'),
      SubCategory(id: 'sportswear', name: 'ביגוד ספורט'),
    ],
  );

  static const toys = Category(
    id: 'toys',
    name: 'משחקים וצעצועים',
    icon: Icons.toys,
    subCategories: [
      SubCategory(
        id: 'baby_toys',
        name: 'צעצועי תינוקות',
        specificFields: [
          CategoryField(
            id: 'age_range',
            label: 'גיל מומלץ',
            type: FieldType.dropdown,
            options: ['0-6 חודשים', '6-12 חודשים', '1-2 שנים', '2-3 שנים'],
          ),
        ],
      ),
      SubCategory(id: 'kids_toys', name: 'צעצועי ילדים'),
      SubCategory(id: 'games', name: 'משחקים וחידות'),
      SubCategory(id: 'video_games', name: 'משחקי וידאו'),
      SubCategory(id: 'outdoor_toys', name: 'צעצועי חוץ'),
    ],
  );

  static const kids = Category(
    id: 'kids',
    name: 'תינוקות וילדים',
    icon: Icons.child_care,
    subCategories: [
      SubCategory(id: 'baby_gear', name: 'ציוד תינוקות'),
      SubCategory(id: 'strollers', name: 'עגלות'),
      SubCategory(id: 'car_seats', name: 'מושבי בטיחות'),
      SubCategory(id: 'kids_furniture', name: 'ריהוט ילדים'),
      SubCategory(id: 'kids_clothing', name: 'ביגוד ילדים'),
      SubCategory(id: 'feeding', name: 'האכלה'),
    ],
  );

  static const books = Category(
    id: 'books',
    name: 'ספרים ומדיה',
    icon: Icons.menu_book,
    subCategories: [
      SubCategory(
        id: 'books',
        name: 'ספרים',
        specificFields: [
          CategoryField(
            id: 'genre',
            label: 'ז׳אנר',
            type: FieldType.dropdown,
            options: [
              'רומנים',
              'מתח',
              'מדע בדיוני',
              'פנטזיה',
              'ביוגרפיה',
              'ספרי עזר',
              'ילדים',
              'אחר',
            ],
          ),
          CategoryField(id: 'author', label: 'מחבר', type: FieldType.text),
          CategoryField(
            id: 'language',
            label: 'שפה',
            type: FieldType.dropdown,
            options: ['עברית', 'אנגלית', 'אחר'],
          ),
        ],
      ),
      SubCategory(id: 'textbooks', name: 'ספרי לימוד'),
      SubCategory(id: 'comics', name: 'קומיקס'),
      SubCategory(id: 'music', name: 'מוזיקה'),
      SubCategory(id: 'movies', name: 'סרטים'),
    ],
  );

  static const pets = Category(
    id: 'pets',
    name: 'חיות מחמד',
    icon: Icons.pets,
    subCategories: [
      SubCategory(id: 'dogs', name: 'כלבים'),
      SubCategory(id: 'cats', name: 'חתולים'),
      SubCategory(id: 'accessories', name: 'אביזרים'),
      SubCategory(id: 'food', name: 'מזון'),
      SubCategory(id: 'other_pets', name: 'חיות אחרות'),
    ],
  );

  static const services = Category(
    id: 'services',
    name: 'שירותים',
    icon: Icons.miscellaneous_services,
    subCategories: [
      SubCategory(id: 'repairs', name: 'תיקונים'),
      SubCategory(id: 'cleaning', name: 'ניקיון'),
      SubCategory(id: 'moving', name: 'הובלות'),
      SubCategory(id: 'events', name: 'אירועים'),
      SubCategory(id: 'tutoring', name: 'שיעורים פרטיים'),
      SubCategory(id: 'other', name: 'שירותים אחרים'),
    ],
  );

  static const jobs = Category(
    id: 'jobs',
    name: 'דרושים',
    icon: Icons.work,
    subCategories: [
      SubCategory(id: 'full_time', name: 'משרה מלאה'),
      SubCategory(id: 'part_time', name: 'משרה חלקית'),
      SubCategory(id: 'freelance', name: 'פרילנס'),
      SubCategory(id: 'internship', name: 'התמחות'),
    ],
  );

  static const other = Category(
    id: 'other',
    name: 'אחר',
    icon: Icons.category,
    subCategories: [
      SubCategory(id: 'free_stuff', name: 'חינם'),
      SubCategory(id: 'lost_found', name: 'אבידות ומציאות'),
      SubCategory(id: 'miscellaneous', name: 'שונות'),
    ],
  );

  static List<Category> get all => [
    fashion,
    electronics,
    vehicles,
    realEstate,
    furniture,
    homeGarden,
    fashionBeauty,
    sports,
    toys,
    kids,
    books,
    pets,
    services,
    jobs,
    other,
  ];

  static Category? findById(String id) {
    try {
      return all.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  static SubCategory? findSubCategory(String categoryId, String subCategoryId) {
    final category = findById(categoryId);
    if (category == null) return null;

    try {
      return category.subCategories.firstWhere(
        (sub) => sub.id == subCategoryId,
      );
    } catch (e) {
      return null;
    }
  }
}
