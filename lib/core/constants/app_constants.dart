class AppConstants {
  static const String appName = 'Secondhand Marketplace';
  static const String webBaseUrl = 'https://your-project-id.web.app';
  static const String termsUrl = '$webBaseUrl/terms-of-service.html';
  static const String privacyUrl = '$webBaseUrl/privacy-policy.html';
  static const String supportEmail = 'support@example.com';
  static const String storageBucket = 'your-project-id.firebasestorage.app';
  static const String appVersion = '1.0.0';

  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String ordersCollection = 'orders';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String notificationsCollection = 'notifications';

  static const String productImagesPath = 'product_images';
  static const String userProfileImagesPath = 'user_profiles';
  static const String chatImagesPath = 'chat_images';
  static const String storefrontAssetsPath = 'storefront_assets';

  static const int maxProductImages = 10;
  static const int maxImageSizeMB = 5;
  static const int productsPerPage = 20;
  static const int messagesPerPage = 50;

  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  static const int minPasswordLength = 6;
  static const int maxProductTitleLength = 100;
  static const int maxProductDescriptionLength = 1000;
  static const int minProductPrice = 1;
  static const int maxProductPrice = 999999;

  static const double defaultLatitude = 32.0853;
  static const double defaultLongitude = 34.7818;
  static const double defaultZoom = 12.0;

  static const int maxMessageLength = 500;
  static const Duration typingIndicatorTimeout = Duration(seconds: 3);

  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  static const String errorGeneric = 'אירעה שגיאה, אנא נסה שוב';
  static const String errorNetwork = 'אין חיבור לאינטרנט';
  static const String errorAuth = 'שגיאת אימות, אנא התחבר מחדש';
  static const String errorPermission = 'אין הרשאה לביצוע פעולה זו';
  static const String errorNotFound = 'הפריט לא נמצא';
  static const String errorImageUpload = 'שגיאה בהעלאת תמונה';
  static const String errorLocationPermission = 'נדרשת הרשאת מיקום';

  static const String successProductCreated = 'המוצר פורסם בהצלחה';
  static const String successOrderCreated = 'ההזמנה נוצרה בהצלחה';
  static const String successProfileUpdated = 'הפרופיל עודכן בהצלחה';
  static const String successMessageSent = 'ההודעה נשלחה';
}
