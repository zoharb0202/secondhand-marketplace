enum UserRole {
  customer,
  supportAgent,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'לקוח';
      case UserRole.supportAgent:
        return 'נציג שירות';
      case UserRole.admin:
        return 'מנהל';
    }
  }

  bool hasPermission(Permission permission) {
    switch (this) {
      case UserRole.admin:
        return true;
      case UserRole.supportAgent:
        return _supportAgentPermissions.contains(permission);
      case UserRole.customer:
        return _customerPermissions.contains(permission);
    }
  }

  static const _customerPermissions = [
    Permission.viewProducts,
    Permission.createProducts,
    Permission.editOwnProducts,
    Permission.deleteOwnProducts,
    Permission.chat,
    Permission.createSupportTicket,
    Permission.viewOwnTickets,
  ];

  static const _supportAgentPermissions = [
    Permission.viewProducts,
    Permission.chat,
    Permission.viewAllTickets,
    Permission.respondToTickets,
    Permission.closeTickets,
    Permission.viewCustomers,
  ];
}

enum Permission {
  viewProducts,
  createProducts,
  editOwnProducts,
  editAnyProducts,
  deleteOwnProducts,
  deleteAnyProducts,

  chat,
  viewAllChats,

  createSupportTicket,
  viewOwnTickets,
  viewAllTickets,
  respondToTickets,
  closeTickets,

  viewCustomers,
  createUsers,
  editUsers,
  deleteUsers,
  assignRoles,

  viewOwnAnalytics,
  viewAllAnalytics,
  viewSalesReports,

  systemSettings,
}

class UserRoleHelper {
  static UserRole fromString(String? roleString) {
    if (roleString == null) return UserRole.customer;

    try {
      return UserRole.values.firstWhere(
        (e) => e.name == roleString,
        orElse: () => UserRole.customer,
      );
    } catch (e) {
      return UserRole.customer;
    }
  }

  static String getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '👑';
      case UserRole.supportAgent:
        return '🎧';
      case UserRole.customer:
        return '👤';
    }
  }
}
