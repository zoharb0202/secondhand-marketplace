enum ProductCondition {
  brandNew,
  likeNew,
  veryGood,
  good,
  fair;

  String get displayName {
    switch (this) {
      case ProductCondition.brandNew:
        return 'חדש באריזה';
      case ProductCondition.likeNew:
        return 'כמו חדש';
      case ProductCondition.veryGood:
        return 'מצב טוב מאוד';
      case ProductCondition.good:
        return 'מצב טוב';
      case ProductCondition.fair:
        return 'מצב סביר';
    }
  }
}

enum ProductCategory {
  vehicles,
  realEstate,
  electronics,
  fashion,
  homeGarden,
  sports,
  babyKids,
  animalsSupplies,
  officeSupplies,
  services,
  jobs,
  other;

  String get displayName {
    switch (this) {
      case ProductCategory.vehicles:
        return 'רכב';
      case ProductCategory.realEstate:
        return 'נדל"ן';
      case ProductCategory.electronics:
        return 'מוצרי חשמל ואלקטרוניקה';
      case ProductCategory.fashion:
        return 'אופנה ואקססוריז';
      case ProductCategory.homeGarden:
        return 'בית וגן';
      case ProductCategory.sports:
        return 'ספורט ותחביבים';
      case ProductCategory.babyKids:
        return 'תינוקות וילדים';
      case ProductCategory.animalsSupplies:
        return 'חיות מחמד וציוד';
      case ProductCategory.officeSupplies:
        return 'ציוד למשרד';
      case ProductCategory.services:
        return 'שירותים';
      case ProductCategory.jobs:
        return 'דרושים';
      case ProductCategory.other:
        return 'אחר';
    }
  }
}

enum ElectronicsSubcategory {
  mobilePhones,
  tablets,
  smartWatches,

  laptops,
  desktops,
  monitors,

  headphones,
  speakers,
  cameras,
  tvs,

  consoles,
  gamingAccessories,

  refrigerators,
  washingMachines,
  dishwashers,
  airConditioners,
  vacuums,

  other;

  String get displayName {
    switch (this) {
      case ElectronicsSubcategory.mobilePhones:
        return 'טלפונים ניידים';
      case ElectronicsSubcategory.tablets:
        return 'טאבלטים';
      case ElectronicsSubcategory.smartWatches:
        return 'שעונים חכמים';
      case ElectronicsSubcategory.laptops:
        return 'מחשבים ניידים';
      case ElectronicsSubcategory.desktops:
        return 'מחשבים שולחניים';
      case ElectronicsSubcategory.monitors:
        return 'מסכים למחשב';
      case ElectronicsSubcategory.headphones:
        return 'אוזניות';
      case ElectronicsSubcategory.speakers:
        return 'רמקולים';
      case ElectronicsSubcategory.cameras:
        return 'מצלמות';
      case ElectronicsSubcategory.tvs:
        return 'טלוויזיות';
      case ElectronicsSubcategory.consoles:
        return 'קונסולות משחק';
      case ElectronicsSubcategory.gamingAccessories:
        return 'אביזרי גיימינג';
      case ElectronicsSubcategory.refrigerators:
        return 'מקררים';
      case ElectronicsSubcategory.washingMachines:
        return 'מכונות כביסה';
      case ElectronicsSubcategory.dishwashers:
        return 'מדיחי כלים';
      case ElectronicsSubcategory.airConditioners:
        return 'מזגנים';
      case ElectronicsSubcategory.vacuums:
        return 'שואבי אבק';
      case ElectronicsSubcategory.other:
        return 'אחר';
    }
  }
}

enum FashionSubcategory {
  menClothing,
  womenClothing,
  kidsClothing,

  menShoes,
  womenShoes,
  kidsShoes,
  sneakers,

  bags,
  jewelry,
  watches,
  sunglasses,

  other;

  String get displayName {
    switch (this) {
      case FashionSubcategory.menClothing:
        return 'בגדי גברים';
      case FashionSubcategory.womenClothing:
        return 'בגדי נשים';
      case FashionSubcategory.kidsClothing:
        return 'בגדי ילדים';
      case FashionSubcategory.menShoes:
        return 'נעלי גברים';
      case FashionSubcategory.womenShoes:
        return 'נעלי נשים';
      case FashionSubcategory.kidsShoes:
        return 'נעלי ילדים';
      case FashionSubcategory.sneakers:
        return 'נעלי ספורט';
      case FashionSubcategory.bags:
        return 'תיקים';
      case FashionSubcategory.jewelry:
        return 'תכשיטים';
      case FashionSubcategory.watches:
        return 'שעונים';
      case FashionSubcategory.sunglasses:
        return 'משקפי שמש';
      case FashionSubcategory.other:
        return 'אחר';
    }
  }
}

enum ProductBrand {
  apple,
  samsung,
  google,
  xiaomi,
  oneplus,

  dell,
  hp,
  lenovo,
  asus,
  acer,
  msi,

  nike,
  adidas,
  puma,
  newBalance,
  vans,
  converse,
  zara,
  hm,
  mango,
  castro,

  lg,
  bosch,
  electrolux,

  sony,
  microsoft,
  nintendo,

  other;

  String get displayName {
    switch (this) {
      case ProductBrand.apple:
        return 'Apple';
      case ProductBrand.samsung:
        return 'Samsung';
      case ProductBrand.google:
        return 'Google';
      case ProductBrand.xiaomi:
        return 'Xiaomi';
      case ProductBrand.oneplus:
        return 'OnePlus';
      case ProductBrand.dell:
        return 'Dell';
      case ProductBrand.hp:
        return 'HP';
      case ProductBrand.lenovo:
        return 'Lenovo';
      case ProductBrand.asus:
        return 'ASUS';
      case ProductBrand.acer:
        return 'Acer';
      case ProductBrand.msi:
        return 'MSI';
      case ProductBrand.nike:
        return 'Nike';
      case ProductBrand.adidas:
        return 'Adidas';
      case ProductBrand.puma:
        return 'Puma';
      case ProductBrand.newBalance:
        return 'New Balance';
      case ProductBrand.vans:
        return 'Vans';
      case ProductBrand.converse:
        return 'Converse';
      case ProductBrand.zara:
        return 'Zara';
      case ProductBrand.hm:
        return 'H&M';
      case ProductBrand.mango:
        return 'Mango';
      case ProductBrand.castro:
        return 'Castro';
      case ProductBrand.lg:
        return 'LG';
      case ProductBrand.bosch:
        return 'Bosch';
      case ProductBrand.electrolux:
        return 'Electrolux';
      case ProductBrand.sony:
        return 'Sony';
      case ProductBrand.microsoft:
        return 'Microsoft';
      case ProductBrand.nintendo:
        return 'Nintendo';
      case ProductBrand.other:
        return 'אחר';
    }
  }
}

enum OrderStatus {
  pending,
  paid,
  readyForPickup,
  completed,
  cancelled,
  disputed;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'ממתין לאישור';
      case OrderStatus.paid:
        return 'שולם';
      case OrderStatus.readyForPickup:
        return 'מוכן לאיסוף';
      case OrderStatus.completed:
        return 'נאסף';
      case OrderStatus.cancelled:
        return 'בוטל';
      case OrderStatus.disputed:
        return 'במחלוקת';
    }
  }

  static OrderStatus fromName(String? name) {
    for (final s in OrderStatus.values) {
      if (s.name == name) return s;
    }
    return OrderStatus.pending;
  }
}

enum SellerAvailability {
  online,
  offline,
  away;

  String get displayName {
    switch (this) {
      case SellerAvailability.online:
        return 'זמין עכשיו';
      case SellerAvailability.offline:
        return 'לא זמין';
      case SellerAvailability.away:
        return 'לא בבית';
    }
  }
}

enum MessageType { text, image, systemNotification }
