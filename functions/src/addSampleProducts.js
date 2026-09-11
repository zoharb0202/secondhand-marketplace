const functions = require('firebase-functions');
const admin = require('firebase-admin');

const conditions = ['brandNew', 'likeNew', 'veryGood', 'good', 'fair'];
const locations = ['תל אביב', 'ירושלים', 'חיפה', 'באר שבע', 'המרכז', 'הצפון', 'הדרום'];

const cityCoordinates = {
  'תל אביב': { lat: 32.0853, lng: 34.7818 },
  'ירושלים': { lat: 31.7683, lng: 35.2137 },
  'חיפה': { lat: 32.7940, lng: 34.9896 },
  'באר שבע': { lat: 31.2518, lng: 34.7913 },
  'המרכז': { lat: 32.0853, lng: 34.7818 },
  'הצפון': { lat: 32.7940, lng: 35.2035 },
  'הדרום': { lat: 31.2518, lng: 34.7913 },
};

const mobilePhones = [
  { title: 'iPhone 15 Pro Max 256GB טיטניום', brand: 'apple', price: 4800, description: 'אייפון 15 פרו מקס חדש באריזה, 256GB, טיטניום כחול' },
  { title: 'iPhone 15 Pro 128GB', brand: 'apple', price: 4200, description: 'iPhone 15 Pro טיטניום טבעי, 128GB, מצב מצוין' },
  { title: 'iPhone 15 Plus 256GB ורוד', brand: 'apple', price: 3500, description: 'אייפון 15 פלוס ורוד, 256GB במצב כמו חדש' },
  { title: 'iPhone 14 Pro Max 256GB', brand: 'apple', price: 3800, description: 'אייפון 14 פרו מקס סגול עמוק, 256GB' },
  { title: 'iPhone 14 Pro 128GB זהב', brand: 'apple', price: 3200, description: 'iPhone 14 Pro זהב, 128GB, מצב טוב מאוד' },
  { title: 'iPhone 13 Pro Max 512GB', brand: 'apple', price: 3200, description: 'אייפון 13 פרו מקס ירוק אלפיין, 512GB' },
  { title: 'iPhone 13 256GB אדום', brand: 'apple', price: 2400, description: 'אייפון 13 אדום Product Red, 256GB' },
  { title: 'iPhone 12 Pro 256GB', brand: 'apple', price: 2600, description: 'אייפון 12 פרו כחול פסיפי, 256GB' },
  { title: 'iPhone SE 2022 128GB', brand: 'apple', price: 1400, description: 'אייפון SE דור שלישי, 128GB, מעולה למתחילים' },
  { title: 'iPhone 11 128GB', brand: 'apple', price: 1500, description: 'iPhone 11 לבן, 128GB במצב טוב מאוד' },

  { title: 'Samsung Galaxy S24 Ultra 512GB', brand: 'samsung', price: 4500, description: 'גלקסי S24 אולטרה טיטניום שחור, 512GB, עם עט S-Pen' },
  { title: 'Galaxy S23 Ultra 256GB', brand: 'samsung', price: 3800, description: 'סמסונג גלקסי S23 אולטרה ירוק, 256GB במצב מצוין' },
  { title: 'Samsung S23 128GB', brand: 'samsung', price: 2800, description: 'Samsung Galaxy S23 קרם, 128GB כמו חדש' },
  { title: 'Galaxy A54 5G 256GB', brand: 'samsung', price: 1400, description: 'גלקסי A54 סגול, 256GB, מצלמה מעולה' },
  { title: 'Galaxy A34 128GB', brand: 'samsung', price: 1100, description: 'סמסונג A34 כסף, 128GB' },

  { title: 'Google Pixel 8 Pro 256GB', brand: 'google', price: 3500, description: 'גוגל פיקסל 8 פרו חזל, 256GB, מצלמה מעולה' },
  { title: 'Pixel 7 Pro 128GB', brand: 'google', price: 2600, description: 'גוגל פיקסל 7 פרו שחור, 128GB' },
  { title: 'Google Pixel 7a 128GB', brand: 'google', price: 1600, description: 'פיקסל 7a לבן, 128GB במחיר מעולה' },

  { title: 'Xiaomi 13 Pro 256GB', brand: 'xiaomi', price: 2400, description: 'שיאומי 13 פרו שחור, 256GB, מצלמה Leica' },
  { title: 'Xiaomi Redmi Note 12 Pro', brand: 'xiaomi', price: 1000, description: 'רדמי נוט 12 פרו כחול, 256GB' },

  { title: 'OnePlus 11 5G 256GB', brand: 'oneplus', price: 2200, description: 'וואן פלוס 11 ירוק, 256GB, טעינה מהירה' },
];

const laptops = [
  { title: 'MacBook Pro 16 M3 Max 1TB', brand: 'apple', price: 12000, description: 'מקבוק פרו 16 אינץ עם M3 Max, 1TB, 36GB RAM, Space Black' },
  { title: 'MacBook Pro 14 M3 Pro 512GB', brand: 'apple', price: 8500, description: 'מקבוק פרו 14 אינץ M3 Pro, 512GB, 18GB RAM' },
  { title: 'MacBook Air 15 M2 512GB', brand: 'apple', price: 5800, description: 'מקבוק אייר 15 אינץ M2, 512GB, כסוף' },
  { title: 'MacBook Air 13 M2 256GB', brand: 'apple', price: 4500, description: 'מקבוק אייר 13 אינץ M2, 256GB, מידנייט' },
  { title: 'MacBook Air M1 256GB', brand: 'apple', price: 3500, description: 'מקבוק אייר M1, 256GB, זהב, במצב מצוין' },

  { title: 'Dell XPS 15 9530 i7 32GB', brand: 'dell', price: 7500, description: 'דל XPS 15, Intel i7-13700H, 32GB RAM, RTX 4050, 1TB SSD' },
  { title: 'Dell XPS 13 Plus i5 16GB', brand: 'dell', price: 5200, description: 'דל XPS 13 פלוס, i5, 16GB RAM, 512GB SSD' },
  { title: 'Dell Latitude 5540 i7', brand: 'dell', price: 4200, description: 'דל לטיטיוד 5540 למשרד, i7, 16GB, 512GB' },
  { title: 'Dell Inspiron 15 i5', brand: 'dell', price: 2800, description: 'דל אינספיירון 15, i5, 16GB, 512GB' },

  { title: 'HP Spectre x360 16 i7', brand: 'hp', price: 6500, description: 'HP ספקטר x360 16 אינץ, i7, 16GB, 1TB, מסך מגע' },
  { title: 'HP Envy 14 i7 16GB', brand: 'hp', price: 4800, description: 'HP אנווי 14, i7, 16GB RAM, 512GB SSD' },
  { title: 'HP Pavilion Gaming i5 RTX3050', brand: 'hp', price: 3500, description: 'HP פביליון גיימינג, i5, RTX 3050, 16GB, 512GB' },

  { title: 'Lenovo ThinkPad X1 Carbon i7', brand: 'lenovo', price: 5800, description: 'לנובו ThinkPad X1 Carbon, i7, 16GB, 512GB, קל משקל' },
  { title: 'Lenovo Legion 5 Pro RTX4060', brand: 'lenovo', price: 5500, description: 'לנובו ליג\'יון 5 פרו לגיימינג, Ryzen 7, RTX 4060, 16GB' },
  { title: 'Lenovo IdeaPad 3 i5', brand: 'lenovo', price: 2400, description: 'לנובו IdeaPad 3, i5, 8GB, 512GB' },

  { title: 'ASUS ROG Zephyrus G14 RTX4060', brand: 'asus', price: 6500, description: 'אסוס ROG Zephyrus G14 לגיימינג, Ryzen 9, RTX 4060, 16GB' },
  { title: 'ASUS ZenBook 14 OLED i7', brand: 'asus', price: 4800, description: 'אסוס ZenBook 14, i7, 16GB, מסך OLED מדהים' },

  { title: 'MSI Raider GE78 i9 RTX4080', brand: 'msi', price: 12000, description: 'MSI Raider GE78 לגיימינג הארדקור, i9, RTX 4080, 32GB' },
  { title: 'MSI Katana 15 i7 RTX4050', brand: 'msi', price: 4500, description: 'MSI Katana 15 לגיימינג, i7, RTX 4050, 16GB' },
];

const consoles = [
  { title: 'PlayStation 5 עם דיסק', brand: 'sony', price: 2200, description: 'PS5 חדש באריזה עם כונן דיסקים, כולל שלט DualSense' },
  { title: 'PlayStation 5 Digital Edition', brand: 'sony', price: 1900, description: 'PS5 דיגיטלי ללא כונן דיסקים, מצב מצוין' },
  { title: 'Xbox Series X 1TB', brand: 'microsoft', price: 2100, description: 'Xbox Series X חדש באריזה, 1TB, תמיכה ב-4K' },
  { title: 'Xbox Series S 512GB', brand: 'microsoft', price: 1200, description: 'Xbox Series S לבן קומפקטי, 512GB' },
  { title: 'Nintendo Switch OLED', brand: 'nintendo', price: 1500, description: 'Nintendo Switch OLED עם מסך משופר, כולל Dock' },
  { title: 'Nintendo Switch Lite', brand: 'nintendo', price: 900, description: 'Nintendo Switch Lite טורקיז, קומפקטי ונייד' },
];

const tablets = [
  { title: 'iPad Pro 12.9 M2 256GB', brand: 'apple', price: 4800, description: 'אייפד פרו 12.9 אינץ עם M2, 256GB, Space Gray' },
  { title: 'iPad Air M2 128GB', brand: 'apple', price: 2800, description: 'אייפד אייר עם M2, 128GB, כחול' },
  { title: 'iPad 10th Gen 256GB', brand: 'apple', price: 2000, description: 'אייפד דור 10, 256GB, צהוב' },
  { title: 'Samsung Galaxy Tab S9 Ultra', brand: 'samsung', price: 4200, description: 'גלקסי טאב S9 אולטרה 14.6 אינץ, 256GB, עם עט S-Pen' },
  { title: 'Galaxy Tab S8 256GB', brand: 'samsung', price: 2600, description: 'גלקסי טאב S8 11 אינץ, 256GB' },
];

const sneakers = [
  { title: 'Nike Air Jordan 1 Retro High Chicago', brand: 'nike', price: 800, description: 'אייר ג\'ורדן 1 צבעי שיקגו קלאסיים, מידה 42' },
  { title: 'Nike Air Jordan 4 White Cement', brand: 'nike', price: 1200, description: 'אייר ג\'ורדן 4 ווייט סמנט, מידה 43, מצב מצוין' },
  { title: 'Nike Dunk Low Panda', brand: 'nike', price: 600, description: 'נייקי דאנק לואו שחור לבן פנדה, מידה 41' },
  { title: 'Nike Air Max 90 OG', brand: 'nike', price: 550, description: 'אייר מקס 90 אוריג\'ינל, לבן אדום, מידה 44' },
  { title: 'Nike Air Force 1 White', brand: 'nike', price: 450, description: 'אייר פורס 1 לבן קלאסי, מידה 42.5' },

  { title: 'Adidas Yeezy Boost 350 V2', brand: 'adidas', price: 1400, description: 'אדידס יזי בוסט 350 V2 זברה, מידה 43' },
  { title: 'Adidas Samba OG Black', brand: 'adidas', price: 450, description: 'אדידס סמבה אוריג\'ינל שחור, מידה 42' },
  { title: 'Adidas Ultraboost 22', brand: 'adidas', price: 600, description: 'אדידס אולטרה בוסט 22 לריצה, מידה 44' },

  { title: 'New Balance 550 White Green', brand: 'newBalance', price: 550, description: 'ניו באלאנס 550 לבן ירוק, מידה 43' },
  { title: 'New Balance 2002R Grey', brand: 'newBalance', price: 650, description: 'ניו באלאנס 2002R אפור, מידה 42' },

  { title: 'Converse Chuck Taylor All Star High', brand: 'converse', price: 280, description: 'קונברס צ\'אק טיילור הייי שחור קלאסי, מידה 41' },
  { title: 'Converse CDG Play Low', brand: 'converse', price: 500, description: 'קונברס שיתוף פעולה עם CDG, מידה 42' },

  { title: 'Vans Old Skool Black White', brand: 'vans', price: 320, description: 'ואנס אולד סקול שחור לבן קלאסי, מידה 43' },
  { title: 'Vans Sk8-Hi Platform', brand: 'vans', price: 380, description: 'ואנס Sk8-Hi פלטפורמה, מידה 40' },
];

const clothing = [
  { title: 'Nike Tech Fleece Hoodie שחור', brand: 'nike', price: 380, description: 'נייקי טק פליס הודי שחור, מידה L, חם ונוח' },
  { title: 'Adidas Adicolor Tracksuit', brand: 'adidas', price: 450, description: 'אדידס אדיקולור טרנינג כחול, מידה M' },
  { title: 'Supreme Box Logo Hoodie', brand: 'other', price: 2200, description: 'סופרים בוקס לוגו הודי אדום, מידה L, אוריג\'ינל' },
  { title: 'Zara Man Blazer', brand: 'zara', price: 280, description: 'זארה בלייזר שחור לגברים, מידה 50' },
  { title: 'H&M Oversized T-Shirt Pack', brand: 'hm', price: 120, description: 'חבילת 3 חולצות H&M oversized, מידה L' },
  { title: 'Mango Women Dress', brand: 'mango', price: 180, description: 'מנגו שמלת קיץ לנשים, מידה M, צבע ירוק' },
];

const appliances = [
  { title: 'מקרר LG דלת ליד דלת 700 ליטר', brand: 'lg', price: 6500, description: 'מקרר LG InstaView דלת ליד דלת, 700 ליטר, נירוסטה' },
  { title: 'מכונת כביסה בוש 9 ק"ג', brand: 'bosch', price: 2800, description: 'מכונת כביסה בוש פתח חזית 9 ק"ג, 1400 סל"ד' },
  { title: 'מדיח כלים סמסונג', brand: 'samsung', price: 2200, description: 'מדיח כלים סמסונג WaterWall, מובנה, 14 מערכות' },
  { title: 'מזגן אלקטרה 1.5 כוח סוס', brand: 'other', price: 2400, description: 'מזגן אלקטרה אינברטר 1.5 כוח סוס, A+++ חיסכון באנרגיה' },
  { title: 'שואב אבק רובוטי רומבה', brand: 'other', price: 1800, description: 'iRobot Roomba J7+ שואב רובוטי חכם, עם ריקון אוטומטי' },
  { title: 'טלוויזיה סמסונג QLED 65"', brand: 'samsung', price: 4500, description: 'טלוויזיה סמסונג QLED 65 אינץ, 4K, Quantum Dot' },
];

const addProduct = async (productData, category, subcategory) => {
  const user = {
    id: 'sample-user-' + Math.floor(Math.random() * 5),
    name: 'מוכר לדוגמא ' + (Math.floor(Math.random() * 5) + 1)
  };

  const cityName = locations[Math.floor(Math.random() * locations.length)];
  const coords = cityCoordinates[cityName] || { lat: 32.0853, lng: 34.7818 };

  let model = productData.model || null;

  await admin.firestore().collection('products').add({
    title: productData.title,
    brand: productData.brand,
    model: model,
    price: productData.price,
    description: productData.description,
    category: category,
    subcategory: subcategory,
    condition: conditions[Math.floor(Math.random() * conditions.length)],
    city: cityName,
    location: new admin.firestore.GeoPoint(coords.lat, coords.lng),
    sellerId: user.id,
    sellerName: user.name,
    imageUrls: [
      'https://via.placeholder.com/800x600/4A90E2/FFFFFF?text=' + encodeURIComponent(productData.title)
    ],
    videoUrls: [],
    isAvailableNow: Math.random() > 0.2,
    viewCount: Math.floor(Math.random() * 100),
    likeCount: Math.floor(Math.random() * 20),
    likedByUserIds: [],
    isActive: true,
    isSold: false,
    isSample: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
};

exports.addSampleProducts = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
        'permission-denied', 'Only an admin may seed sample products.');
  }

  if (!process.env.FUNCTIONS_EMULATOR) {
    throw new functions.https.HttpsError(
        'failed-precondition', 'Sample product seeding is only available in the emulator.');
  }

  try {
    const existing = await admin.firestore().collection('products')
        .where('isSample', '==', true).limit(1).get();
    if (!existing.empty) {
      return {
        success: true,
        message: 'מוצרי לדוגמא כבר קיימים, לא נוספו מוצרים חדשים.',
        count: 0,
      };
    }

    console.log('🚀 Starting to add sample products...');
    let uploadCount = 0;

    console.log('📱 Adding Mobile Phones...');
    for (const phone of mobilePhones) {
      await addProduct(phone, 'electronics', 'mobilePhones');
      uploadCount++;
    }

    console.log('💻 Adding Laptops...');
    for (const laptop of laptops) {
      await addProduct(laptop, 'electronics', 'laptops');
      uploadCount++;
    }

    console.log('🎮 Adding Gaming Consoles...');
    for (const console of consoles) {
      await addProduct(console, 'electronics', 'consoles');
      uploadCount++;
    }

    console.log('📲 Adding Tablets...');
    for (const tablet of tablets) {
      await addProduct(tablet, 'electronics', 'tablets');
      uploadCount++;
    }

    console.log('👟 Adding Sneakers...');
    for (const shoe of sneakers) {
      await addProduct(shoe, 'fashion', 'sneakers');
      uploadCount++;
    }

    console.log('👕 Adding Clothing...');
    for (const item of clothing) {
      await addProduct(item, 'fashion', 'menClothing');
      uploadCount++;
    }

    console.log('🏠 Adding Appliances...');
    for (const appliance of appliances) {
      await addProduct(appliance, 'electronics', 'refrigerators');
      uploadCount++;
    }

    console.log(`\n✅ Successfully uploaded ${uploadCount} products!`);

    return {
      success: true,
      message: `נוספו ${uploadCount} מוצרים לדוגמא בהצלחה!`,
      count: uploadCount
    };
  } catch (error) {
    console.error('❌ Error adding sample products:', error);
    throw new functions.https.HttpsError('internal', 'Failed to add sample products: ' + error.message);
  }
});
